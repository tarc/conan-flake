# What the per-feature check files share: the way a check is built, the
# rendered site every one of them reads, and the shape of a chapter assertion.
#
# `../checks.nix` merges the two files that use this one; nothing outside them
# imports it.
#
# site.BUILD.3
{
  lib,
  runCommand,
  site,
}:
let
  repositoryRoot = toString ../../../..;

  # Each check declares the inputs it actually reads, so that an edit under
  # `examples/` invalidates the two checks that read the example projects rather
  # than all of them, and `embedmd` stays out of the closure of the checks that
  # only grep the rendered site.
  check =
    acid: env: script:
    runCommand "docs-${acid}" env script;

  # The rendered site alone: what most checks read.
  siteOnly = {
    inherit site;
  };

  # A chapter check: every page listed has to have been rendered and to carry
  # every phrase given for it, which is what tells the migrated chapter apart
  # from a stub that merely exists.
  chapterCheck =
    acid: requirements:
    check acid siteOnly (
      ''
        set -euo pipefail

        status=0

        assert_page() {
          local page="$site/$1"
          shift

          if [ ! -s "$page" ]; then
            echo "the site is missing the chapter page ''${page#"$site"/}" >&2
            status=1
            return
          fi

          local phrase
          for phrase in "$@"; do
            if ! grep -qF -- "$phrase" "$page"; then
              echo "''${page#"$site"/} does not mention: $phrase" >&2
              status=1
            fi
          done
        }

      ''
      + lib.concatMapStrings (requirement: ''
        assert_page ${lib.escapeShellArgs ([ requirement.page ] ++ requirement.phrases)}
      '') requirements
      + ''

        if [ "$status" -ne 0 ]; then
          exit 1
        fi

        touch "$out"
      ''
    );

  # A repository-relative path that is the given directory or something under
  # it, which is how every source tree below is selected.
  under = directory: relative: relative == directory || lib.hasPrefix "${directory}/" relative;

  # The part of the checkout a check reads, copied into the store with the
  # layout it has here — the symbolic links and the relative paths the embedding
  # step follows only resolve in that layout. `wanted` chooses by
  # repository-relative path and by `builtins.path` file type; generated and
  # git-ignored trees are dropped for every caller, since nothing is read from
  # them and they would make the derivation change on every local Conan run.
  sourceTree =
    { name, wanted }:
    builtins.path {
      inherit name;
      path = ../../../..;
      filter =
        path: type:
        let
          relative = lib.removePrefix "${repositoryRoot}/" path;
          generated = builtins.elem (baseNameOf path) [
            ".conan2"
            ".direnv"
            "book"
            "config"
            "flake.lock"
            "result"
          ];
        in
        wanted relative type && !generated;
    };
in
{
  inherit
    check
    chapterCheck
    site
    siteOnly
    under
    sourceTree
    ;

  # The site's own configuration, so that no check restates the value it owns
  # (the deployment sub-path in particular). Read by the chapter that is built
  # for that sub-path and by the check on the address the site is published at.
  bookToml = builtins.path {
    path = ../../../../docs/book.toml;
    name = "conan-flake-docs-book.toml";
  };

  # The site's table of contents, so a check never restates the list of chapters
  # that file owns. Read by the checks over the site's navigation and by the one
  # asserting that `README.md` points at every chapter of it.
  summary = builtins.path {
    path = ../../../../docs/src/SUMMARY.md;
    name = "conan-flake-docs-summary.md";
  };

  # The address the site is served from, and the two other destinations the
  # documentation points at. Named here once: every check below reads them from
  # this file rather than restating them.
  publishedUrl = "https://tarcisio.codeberg.page/conan-flake/";

  optionsReference = "https://flake.parts/options/conan-flake.html";

  repository = "https://codeberg.org/tarcisio/conan-flake";
}
