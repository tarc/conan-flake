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
  # - `node_modules` is the dependency tree, which the build installs from the
  #   fixed-output fetch below (in a checkout it is a symbolic link into the
  #   Nix store, placed by the development shell).
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
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "conan-flake-docs";
  version = "0.0.0";

  inherit src;

  # The npm dependency tree, vendored the standard Nix way: a fixed-output
  # derivation resolves `docs/pnpm-lock.yaml` once, and the build itself then
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
    inherit (finalAttrs) pname version;
    src = depsSrc;
    fetcherVersion = 4;
    hash = "sha256-ssPGETPEik6pwOEXAayDwlc0FRnRqaK6rdlV/njsfSY=";
  };

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
    pnpm
    pnpmConfigHook
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

    export HOME="$TMPDIR"
    export ASTRO_TELEMETRY_DISABLED=1
    export PATH="$PWD/node_modules/.bin:$PATH"

    # `astro` directly rather than `pnpm build`: `pnpm run` re-checks the
    # dependency tree against the lockfile and would try to reach the registry.
    astro build

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out"
    cp -R dist/. "$out"/

    runHook postInstall
  '';

  passthru = {
    # The installed dependency tree on its own, so the development shells can
    # link it at `docs/node_modules` and a contributor never runs an install
    # step of their own.
    #
    # authoring.PREVIEW.3
    nodeModules = stdenvNoCC.mkDerivation {
      name = "conan-flake-docs-node-modules";

      src = depsSrc;

      inherit (finalAttrs) pnpmDeps;

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
  };

  meta = {
    description = "Documentation site for conan-flake";
    homepage = "https://codeberg.org/tarcisio/conan-flake";
    license = lib.licenses.mit;
  };
})
