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
stdenvNoCC.mkDerivation {
  name = "conan-flake-docs";

  # The Markdown sources, `book.toml` and nothing else: `docs/` at the
  # repository root, tracked in git.
  #
  # site.SOURCES.1
  src = builtins.path {
    path = ../../../docs;
    name = "conan-flake-docs-source";
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
