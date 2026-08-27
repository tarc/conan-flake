# The conan-flake documentation site.
#
# The site is wired into the flake through `dev/flake.nix`
# (`conan-flake.lib.packages.docs`) rather than through the repository-root
# `flake.nix`, which stays free of inputs — building it needs a nixpkgs, and the
# root flake has none. The npm tooling the site is generated with is described
# by `docs/package.json` and `docs/pnpm-lock.yaml`, both tracked in this
# repository, so no flake input is added for it either.
#
# site.BUILD.4
# site.BUILD.1
# site.BUILD.2
{
  lib,
  stdenvNoCC,
  nodejs,
  pnpm,
  fetchPnpmDeps,
  pnpmConfigHook,
}:
let
  pname = "conan-flake-docs";
  version = "0.0.0";

  # The source location of `docs/`, as a plain string, so the entries below can
  # be named without copying anything to the store first.
  docsRoot = toString ../../../docs;

  # The Astro project: the Markdown sources, the configuration and nothing
  # else — `docs/` at the repository root, tracked in git.
  #
  # What is dropped here is generated or fetched, never authored:
  #
  # - `src/content/docs/.examples` (`../../../../examples`) exists for
  #   `embedmd`, which resolves a marker's path relative to the Markdown file
  #   and refuses to leave that directory; the site's markers reach the example
  #   projects through it. The markers are already expanded in the committed
  #   sources, so the build needs neither the link nor the `examples/` tree it
  #   would drag into the build closure.
  # - `node_modules` is the dependency tree, which the build takes from the
  #   `nodeModules` derivation below (in a checkout it is a copy of that same
  #   store path, placed by the development shell).
  # - `dist` and `.astro` are `astro build`/`astro dev` output.
  #
  # site.SOURCES.1
  src = builtins.path {
    path = ../../../docs;
    name = "conan-flake-docs-source";
    filter =
      path: _type:
      path != "${docsRoot}/src/content/docs/.examples"
      && path != "${docsRoot}/node_modules"
      && path != "${docsRoot}/dist"
      && path != "${docsRoot}/.astro";
  };

  # The three files `pnpm install` reads, and only those: the dependency fetch
  # is a fixed-output derivation, so keeping the Markdown sources out of its
  # inputs means editing a chapter does not re-run it.
  depsSrc = lib.fileset.toSource {
    root = ../../../docs;
    fileset = lib.fileset.unions [
      ../../../docs/package.json
      ../../../docs/pnpm-lock.yaml
      ../../../docs/pnpm-workspace.yaml
    ];
  };

  # The npm dependency tree, vendored the standard Nix way: a fixed-output
  # derivation resolves `docs/pnpm-lock.yaml` once, and `nodeModules` below then
  # installs from that store path with `pnpm install --offline`. Every platform
  # binary the site needs (Pagefind's indexer, esbuild, sharp) is an ordinary
  # package named by the lockfile, so nothing reaches the network past this
  # point — `astro build` runs in the sandbox with no network access at all.
  #
  # Refresh the hash by setting it to `lib.fakeHash`, building, and copying the
  # `got:` value back here.
  #
  # site.BUILD.1
  pnpmDeps = fetchPnpmDeps {
    inherit pname version;
    src = depsSrc;
    fetcherVersion = 4;
    hash = "sha256-ssPGETPEik6pwOEXAayDwlc0FRnRqaK6rdlV/njsfSY=";
  };

  # The installed dependency tree, on its own and installed exactly once: the
  # site's build below copies it in instead of running a second `pnpm install`
  # over the same fetch, and the development shells copy this same store path
  # into the checkout so a contributor never runs an install step either.
  #
  # authoring.PREVIEW.3
  nodeModules = stdenvNoCC.mkDerivation {
    name = "conan-flake-docs-node-modules";

    src = depsSrc;

    inherit pnpmDeps;

    nativeBuildInputs = [
      nodejs
      pnpm
      pnpmConfigHook
    ];

    dontBuild = true;
    dontFixup = true;

    installPhase = ''
      runHook preInstall

      cp -a node_modules "$out"

      runHook postInstall
    '';
  };
in
stdenvNoCC.mkDerivation {
  inherit pname version src;

  # The revision history is maintained in `CHANGELOG.md` at the repository root;
  # the changelog chapter presents that file rather than a second copy of it.
  # `src/content/docs/changelog.mdx` renders it through a relative import that
  # leaves the Astro project (`../../../../CHANGELOG.md`), which resolves to the
  # repository root in a checkout and to the file copied beside the project root
  # below in the sandbox.
  #
  # site.GUIDES.9
  changelog = builtins.path {
    path = ../../../CHANGELOG.md;
    name = "conan-flake-CHANGELOG.md";
  };

  nativeBuildInputs = [
    nodejs
  ];

  dontFixup = true;

  # site.BUILD.2
  buildPhase = ''
    runHook preBuild

    # The Astro project root is the unpacked `docs/`, so `..` here is what
    # `../../../../CHANGELOG.md` resolves to from the changelog chapter.
    #
    # site.GUIDES.9
    cp "$changelog" ../CHANGELOG.md

    # The dependency tree is taken from `nodeModules` rather than installed
    # again here: `pnpmConfigHook` run twice over one fetch is the same install
    # done twice, and both derivations are realised by every contributor and by
    # CI (the development shells depend on `nodeModules` as well).
    #
    # It is copied, not symbolically linked, for the same reason the
    # development shells copy it: Astro rewrites a module identifier that
    # shares no ancestor with the project root — every `/nix/store` one does —
    # into a path *under* that root, which then does not exist ("No cached
    # compile metadata found for ..."). The write permission is what lets
    # `astro build` be handed a tree it may touch; nothing here writes into it.
    cp -a --reflink=auto ${nodeModules} node_modules
    chmod -R u+w node_modules

    export HOME="$TMPDIR"
    export ASTRO_TELEMETRY_DISABLED=1
    export PATH="$PWD/node_modules/.bin:$PATH"

    # `astro` directly rather than `pnpm build`: the script in
    # `docs/package.json` is a bare `astro build`, so going through `pnpm run`
    # would only add a package manager to a build that has nothing left to
    # install.
    astro build

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out"
    cp -R dist/. "$out"/

    runHook postInstall
  '';

  # The dependency tree the build above copied in, exposed so that the
  # development shells can place it at `docs/node_modules` too.
  #
  # authoring.PREVIEW.3
  passthru = {
    inherit pnpmDeps nodeModules;
  };

  meta = {
    description = "Documentation site for conan-flake";
    homepage = "https://codeberg.org/tarcisio/conan-flake";
    license = lib.licenses.mit;
  };
}
