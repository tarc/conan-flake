# Assertions over the built documentation site, one derivation per ACID.
#
# `dev/flake.nix` wires them into `nix flake check ./dev`, which is what makes
# the site's build and its sub-path behaviour a CI failure when they regress.
#
# site.BUILD.3
{
  runCommand,
  site,
}:
let
  # The site's own configuration and table of contents, so a check never
  # restates a value those files own (the deployment sub-path in particular).
  bookToml = builtins.path {
    path = ../../../docs/book.toml;
    name = "conan-flake-docs-book.toml";
  };

  summary = builtins.path {
    path = ../../../docs/src/SUMMARY.md;
    name = "conan-flake-docs-summary.md";
  };

  check =
    acid: script:
    runCommand "docs-${acid}" {
      inherit
        bookToml
        site
        summary
        ;
    } script;
in
{
  # site.BUILD.1
  "site.BUILD.1" = check "site.BUILD.1" ''
    set -euo pipefail

    if [ ! -s "$site/index.html" ]; then
      echo "the site has no entry page at the root of its output: $site/index.html" >&2
      exit 1
    fi

    # Every source the table of contents names has to have been rendered, so
    # that the derivation's output is this repository's sources and not a
    # left-over or a partial render.
    chapters="$(grep -oE '\]\([^)]+\.md\)' "$summary" | sed -E 's|^\]\((\./)?||; s|\)$||' | sort -u)"
    if [ -z "$chapters" ]; then
      echo "the table of contents names no chapter at all: $summary" >&2
      exit 1
    fi

    status=0
    while IFS= read -r chapter; do
      page="''${chapter%.md}.html"
      if [ ! -s "$site/$page" ]; then
        echo "the table of contents names $chapter, which the site did not render to $page" >&2
        status=1
      fi
    done <<< "$chapters"

    if [ "$status" -ne 0 ]; then
      exit 1
    fi

    touch "$out"
  '';

  # site.NAVIGATION.2
  "site.NAVIGATION.2" = check "site.NAVIGATION.2" ''
    set -euo pipefail

    # mdBook fingerprints the asset file names, so match the family rather than
    # one literal name.
    index="$(find "$site" -maxdepth 1 -name 'searchindex*.js' -size +0)"
    if [ -z "$index" ]; then
      echo 'the site carries no search index; is output.html.search enabled?' >&2
      ls -la "$site" >&2
      exit 1
    fi

    # An index that indexes nothing would satisfy the file check alone.
    if ! grep -qF 'conan-flake' "$index"; then
      echo "the search index does not mention the site's own content: $index" >&2
      exit 1
    fi

    searcher="$(find "$site" -maxdepth 1 -name 'searcher*.js' -size +0)"
    if [ -z "$searcher" ]; then
      echo "the site carries a search index but no searcher script" >&2
      exit 1
    fi

    touch "$out"
  '';

  # site.NAVIGATION.3
  "site.NAVIGATION.3" = check "site.NAVIGATION.3" ''
    set -euo pipefail

    siteUrl="$(sed -n 's/^site-url[[:blank:]]*=[[:blank:]]*"\(.*\)"[[:blank:]]*$/\1/p' "$bookToml")"
    if [ -z "$siteUrl" ]; then
      echo "book.toml sets no site-url, so the generated 404 page links at the host root" >&2
      exit 1
    fi

    # Every URL a page emits: its links and assets, plus the search index,
    # which mdBook loads from a fingerprinted file name recorded in a
    # page-local variable rather than from a `<script src>`.
    refs() {
      grep -oE '(href|src)="[^"]*"' "$1" | sed -E 's/^(href|src)="//; s/"$//'
      sed -nE 's/.*path_to_searchindex_js[[:blank:]]*=[[:blank:]]*"([^"]*)".*/\1/p' "$1"
    }

    status=0

    # Every root-absolute URL the site emits has to stay inside the deployment
    # sub-path. Ordinary pages emit none at all (they are relative); the
    # generated 404 page, which is reached under an arbitrary depth, is the one
    # that needs `site-url`.
    while IFS= read -r page; do
      while IFS= read -r ref; do
        case "$ref" in
          //*) continue ;;
          /*)
            case "$ref" in
              "$siteUrl"*) continue ;;
            esac
            echo "root-absolute URL escaping $siteUrl in ''${page#"$site"/}: $ref" >&2
            status=1
            ;;
        esac
      done < <(refs "$page")
    done < <(find "$site" -name '*.html')

    # ... and the 404 page has to point back into it, whether by a <base> or by
    # prefixing every URL it emits.
    if ! grep -qF "$siteUrl" "$site/404.html"; then
      echo "the generated 404 page never mentions $siteUrl, so it escapes the site" >&2
      status=1
    fi

    # Every relative link and asset reference has to resolve inside the output.
    while IFS= read -r page; do
      dir="$(dirname "$page")"
      while IFS= read -r ref; do
        case "$ref" in
          "" | '#'* | /* | *://* | mailto:*) continue ;;
        esac
        target="''${ref%%#*}"
        target="''${target%%\?*}"
        if [ -n "$target" ] && [ ! -e "$dir/$target" ]; then
          echo "dangling reference in ''${page#"$site"/}: $ref" >&2
          status=1
        fi
      done < <(refs "$page")
    done < <(find "$site" -name '*.html')

    if [ "$status" -ne 0 ]; then
      exit 1
    fi

    touch "$out"
  '';
}
