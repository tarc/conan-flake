# What the per-feature check files share: the way a check is built, the
# rendered site every one of them reads, and the shape of a chapter assertion.
#
# `../checks.nix` merges the files that use this one; nothing outside them
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

  # Whether a rendered page mentions a phrase, asked of two readings of that
  # page, because neither reading carries every phrase a check needs to look
  # for. A phrase that *is* markup — an address in an `href`, above all — is
  # only in the page as generated. A phrase of the site's own text is subject
  # to what the generator does to text: Starlight highlights code at build time
  # (Expressive Code, driving Shiki), which cuts a sample into `<span>`s, and
  # Astro escapes `<`, `&` and the quotes it writes as character references, so
  # such a phrase may well not occur contiguously in the markup. Stripping the
  # markup and undoing the escapes puts it back together. Found in either
  # reading counts.
  #
  # A shell prelude rather than a Nix function: the checks that read a page for
  # a phrase they cannot name at evaluation time (a chapter's own headings, a
  # template's instantiation command) need the same two readings.
  pageReading = ''
    # The page as a reader sees it. The escapes are undone in both the named
    # and the numeric spelling, since which one is emitted is the generator's
    # decision (Astro writes `&#x3C;` for `<`); `&`, the one that introduces
    # them all, is undone last, so that an escaped reference (`&amp;lt;`) does
    # not turn into the character it names.
    page_text() {
      sed 's/<[^>]*>//g' "$1" \
        | sed -E \
            -e 's/&(lt|#60|#x3[Cc]);/</g' \
            -e 's/&(gt|#62|#x3[Ee]);/>/g' \
            -e 's/&(quot|#34|#x22);/"/g' \
            -e "s/&(apos|#39|#x27);/'/g" \
            -e 's/&(#96|#x60);/`/g' \
            -e 's/&(amp|#38|#x26);/\&/g'
    }

    page_mentions() {
      grep -qF -- "$2" "$1" || page_text "$1" | grep -qF -- "$2"
    }
  '';

  # A chapter check: every page listed has to have been rendered and to carry
  # every phrase given for it, which is what tells the migrated chapter apart
  # from a stub that merely exists.
  chapterCheck =
    acid: requirements:
    check acid siteOnly (
      ''
        set -euo pipefail

        ${pageReading}

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
            if ! page_mentions "$page" "$phrase"; then
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
  # `node_modules`, `dist` and `.astro` exist under `docs/` alone: the site's
  # dependency tree, placed there from the store by the development shell, and
  # the output of `astro build` and `astro dev`.
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
            ".astro"
            ".conan2"
            ".direnv"
            "config"
            "dist"
            "flake.lock"
            "node_modules"
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
    pageReading
    site
    siteOnly
    under
    sourceTree
    ;

  # The two values `docs/astro.config.mjs` owns that a check needs to read: the
  # sub-path the site is deployed under, and the sidebar, which is the list of
  # the site's chapters. A shell prelude, so that a check states neither of them
  # itself — a chapter list transcribed into a check is a chapter list that goes
  # stale silently.
  #
  # Both readings accept either quoting style, since which one the file carries
  # is the formatter's decision and not this check's business.
  #
  # site.NAVIGATION.1
  # site.NAVIGATION.3
  astroConfigReading = ''
    # The `base` the site is built for, as `/conan-flake`, without a trailing
    # slash.
    site_base() {
      sed -nE "s/^const base *= *[\"']([^\"']*)[\"'].*/\1/p" "$astroConfig"
    }

    # One sidebar slug per line. The sidebar's other kind of entry, `link: "/"`,
    # is the landing page, which is rendered to the root of the output and has
    # no slug; every check below treats it separately.
    sidebar_slugs() {
      sed -nE "s/.*slug: *[\"']([^\"']+)[\"'].*/\1/p" "$astroConfig" | sort -u
    }
  '';

  # The site's own configuration, the file the prelude above reads: it has to be
  # in the environment of every check that uses that prelude, under this name.
  astroConfig = builtins.path {
    path = ../../../../docs/astro.config.mjs;
    name = "conan-flake-docs-astro.config.mjs";
  };

  # The address the site is served from, and the two other destinations the
  # documentation points at. Named here once: every check below reads them from
  # this file rather than restating them.
  publishedUrl = "https://tarcisio.codeberg.page/conan-flake/";

  optionsReference = "https://flake.parts/options/conan-flake.html";

  repository = "https://codeberg.org/tarcisio/conan-flake";
}
