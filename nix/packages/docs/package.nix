# The conan-flake documentation site.
#
# The site is wired into the flake through `dev/flake.nix`
# (`conan-flake.lib.packages.docs`) rather than through the repository-root
# `flake.nix`, which stays free of inputs — building it needs a nixpkgs, and the
# root flake has none.
#
# site.BUILD.4
# site.BUILD.1
# site.BUILD.2
{
  lib,
  stdenvNoCC,
  mdbook,
}:
let
  # The source location of `docs/`, as a plain string, so the two entries below
  # can be named without copying anything to the store first.
  docsRoot = toString ../../../docs;
in
stdenvNoCC.mkDerivation {
  name = "conan-flake-docs";

  # The Markdown sources, `book.toml` and nothing else: `docs/` at the
  # repository root, tracked in git.
  #
  # Two entries of `docs/src` are symbolic links pointing outside `docs/`, and
  # both are dropped here and reinstated by the build:
  #
  # - `.examples` (`../../examples`) exists for `embedmd`, which resolves a
  #   marker's path relative to the Markdown file and refuses to leave that
  #   directory; the site's markers reach the example projects through it.
  #   mdBook copies everything that is not Markdown from `src` into the rendered
  #   site, so following that link would publish the whole `examples/` tree.
  # - `changelog.md` (`../../CHANGELOG.md`) is the revision history, which the
  #   build copies in for real below rather than forking (site.GUIDES.9).
  #
  # site.SOURCES.1
  src = builtins.path {
    path = ../../../docs;
    name = "conan-flake-docs-source";
    filter =
      path: _type:
      path != "${docsRoot}/src/.examples" && path != "${docsRoot}/src/changelog.md";
  };

  # The revision history is maintained in `CHANGELOG.md` at the repository root;
  # the changelog chapter presents that file rather than a second copy of it.
  # mdBook cannot include a file from outside its `src` directory, so the copy
  # happens here.
  #
  # site.GUIDES.9
  changelog = builtins.path {
    path = ../../../CHANGELOG.md;
    name = "conan-flake-CHANGELOG.md";
  };

  nativeBuildInputs = [ mdbook ];

  dontConfigure = true;
  dontFixup = true;

  # `mdbook build` reads the sources and its own bundled theme only, so the
  # build needs no network access; nothing here fetches a remote asset.
  #
  # site.BUILD.1
  # site.BUILD.2
  buildPhase = ''
    runHook preBuild

    # site.GUIDES.9
    cp "$changelog" src/changelog.md

    export HOME="$TMPDIR"
    mdbook build --dest-dir book

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out"
    cp -R book/. "$out"/

    runHook postInstall
  '';

  meta = {
    description = "Documentation site for conan-flake";
    homepage = "https://codeberg.org/tarcisio/conan-flake";
    license = lib.licenses.mit;
  };
}
