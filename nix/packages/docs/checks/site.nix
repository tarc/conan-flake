# Assertions over the built documentation site, one derivation per ACID of the
# `site` feature: what it renders, what its chapters say, and what its samples
# are generated from. `../checks.nix` merges these with the publishing ones.
#
# site.BUILD.3
{
  lib,
  check,
  chapterCheck,
  embedmd,
  site,
  siteOnly,
  bookToml,
  ...
}:
let
  # The site's table of contents, so a check never restates the list of chapters
  # that file owns.
  summary = builtins.path {
    path = ../../../../docs/src/SUMMARY.md;
    name = "conan-flake-docs-summary.md";
  };

  # The revision history, so the changelog chapter can be compared against the
  # file it presents instead of against a transcription of it.
  changelog = builtins.path {
    path = ../../../../CHANGELOG.md;
    name = "conan-flake-CHANGELOG.md";
  };

  # The flake declaring the templates, so the templates chapter can be checked
  # against the templates that actually exist rather than against a list.
  rootFlake = builtins.path {
    path = ../../../../flake.nix;
    name = "conan-flake-flake.nix";
  };

  repositoryRoot = toString ../../../..;

  # The Markdown sources of the site next to the example projects they embed
  # from, laid out exactly as in the checkout so that the `docs/src/.examples`
  # symbolic link the markers go through still resolves. Generated and
  # git-ignored trees are left out: they are not embedded from, and they would
  # make this derivation change on every local Conan run.
  #
  # authoring.EMBEDDING.2
  authoringSources = builtins.path {
    path = ../../../..;
    name = "conan-flake-docs-authoring-source";
    filter =
      path: _type:
      let
        relative = lib.removePrefix "${repositoryRoot}/" path;
        wanted =
          relative == "docs"
          || lib.hasPrefix "docs/" relative
          || relative == "examples"
          || lib.hasPrefix "examples/" relative
          # `docs/src/changelog.md` is a symbolic link to it, and a dangling
          # link is not something either the embedding step or this check can
          # read past.
          || relative == "CHANGELOG.md";
        generated = builtins.elem (baseNameOf path) [
          ".conan2"
          ".direnv"
          "book"
          "config"
          "flake.lock"
          "result"
        ];
      in
      wanted && !generated;
  };

  # The URL of the published, generated option reference. Not restated by any
  # check below: they all read it from here.
  optionsReference = "https://flake.parts/options/conan-flake.html";

  repository = "https://codeberg.org/tarcisio/conan-flake";
in
{
  # site.BUILD.1
  "site.BUILD.1" = check "site.BUILD.1" { inherit site summary; } ''
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
  "site.NAVIGATION.2" = check "site.NAVIGATION.2" siteOnly ''
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
  "site.NAVIGATION.3" = check "site.NAVIGATION.3" { inherit bookToml site; } ''
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

  # site.ENTRY.1
  "site.ENTRY.1" = chapterCheck "site.ENTRY.1" [
    {
      page = "index.html";
      phrases = [
        "plain Nix (no flakes)"
        "Nix flakes"
        "flake-parts"
        "devenv"
      ];
    }
  ];

  # site.ENTRY.2
  "site.ENTRY.2" = chapterCheck "site.ENTRY.2" [
    {
      page = "index.html";
      # The rendered Conan profile on one side, the options producing it on the
      # other: both come from the same example project.
      phrases = [
        "[settings]"
        "build_type=Debug"
        "[platform_tool_requires]"
        "profiles.default"
        "platformToolRequires"
      ];
    }
  ];

  # site.ENTRY.3
  "site.ENTRY.3" = chapterCheck "site.ENTRY.3" [
    {
      page = "index.html";
      phrases = [
        repository
        optionsReference
      ];
    }
  ];

  # site.NAVIGATION.1
  "site.NAVIGATION.1" = check "site.NAVIGATION.1" { inherit site summary; } ''
    set -euo pipefail

    status=0

    # mdBook renders the chapter list once, into `toc.html`, which every page
    # pulls in (through `toc.js` with scripting on, as an iframe without it).
    # That file is therefore the site's persistent navigation.
    if [ ! -s "$site/toc.html" ]; then
      echo "the site renders no table of contents, so no page carries a navigation" >&2
      exit 1
    fi

    # Every rendered page has to be reachable from it. `print.html`, `404.html`
    # and `toc.html` itself are generated by mdBook rather than authored, and
    # are deliberately not listed.
    while IFS= read -r page; do
      name="''${page#"$site"/}"
      case "$name" in
        404.html | print.html | toc.html) continue ;;
      esac

      if ! grep -qF "href=\"$name\"" "$site/toc.html"; then
        echo "$name is rendered but not reachable from the navigation" >&2
        status=1
      fi

      # ... and every page has to carry that navigation.
      if ! grep -qE '(toc-[0-9a-f]*\.js|toc\.js|toc\.html)' "$page"; then
        echo "$name does not pull in the site navigation" >&2
        status=1
      fi
      # Not depth-limited: a chapter rendered into a subdirectory of `src` has
      # to be reachable too, and would otherwise escape this check silently.
    done < <(find "$site" -name '*.html')

    # No orphan in the other direction either: what the navigation lists is
    # what the table of contents source names.
    while IFS= read -r chapter; do
      page="''${chapter%.md}.html"
      if ! grep -qF "href=\"$page\"" "$site/toc.html"; then
        echo "$chapter is named by the table of contents but absent from the navigation" >&2
        status=1
      fi
    done < <(grep -oE '\]\([^)]+\.md\)' "$summary" | sed -E 's|^\]\((\./)?||; s|\)$||' | sort -u)

    if [ "$status" -ne 0 ]; then
      exit 1
    fi

    touch "$out"
  '';

  # site.GUIDES.1
  "site.GUIDES.1" = chapterCheck "site.GUIDES.1" [
    {
      page = "getting-started.html";
      phrases = [
        "nix flake init -t"
        "direnv allow ."
        "conan create . --build=missing"
      ];
    }
  ];

  # site.GUIDES.2
  "site.GUIDES.2" = chapterCheck "site.GUIDES.2" [
    {
      page = "flake-parts.html";
      phrases = [
        "inputs.conan-flake.flakeModule"
        "conan.outputs.devShell"
        optionsReference
      ];
    }
  ];

  # site.GUIDES.3
  "site.GUIDES.3" = chapterCheck "site.GUIDES.3" [
    {
      page = "devenv.html";
      phrases = [
        # Both routes: devenv's own option, and conan-flake's devShell taken
        # into a devenv shell directly.
        "languages.cplusplus"
        "conan.outputs.devShell"
        optionsReference
      ];
    }
  ];

  # site.GUIDES.4
  "site.GUIDES.4" = chapterCheck "site.GUIDES.4" [
    {
      page = "standalone.html";
      phrases = [
        "evalConanConfig"
        "submoduleWith"
        optionsReference
      ];
    }
    {
      page = "standalone-eval-conan-config.html";
      phrases = [ "conan-flake.lib.evalConanConfig" ];
    }
    {
      page = "standalone-submodule-with.html";
      phrases = [ "conan-flake.lib.submoduleWith" ];
    }
  ];

  # site.GUIDES.5
  "site.GUIDES.5" = chapterCheck "site.GUIDES.5" [
    {
      page = "toolchains.html";
      phrases = [
        "stdenv"
        optionsReference
      ];
    }
    {
      page = "toolchains-llvm.html";
      phrases = [
        "llvmPackages"
        "libc++"
      ];
    }
    {
      page = "toolchains-cuda.html";
      phrases = [
        "cudaPackages"
        "backendStdenv"
      ];
    }
  ];

  # Every template the repository-root flake declares has to be listed by the
  # templates chapter, with the command that instantiates it: the prose list
  # and the flake have drifted apart before.
  #
  # site.GUIDES.6
  "site.GUIDES.6" = check "site.GUIDES.6" { inherit rootFlake site; } ''
    set -euo pipefail

    if [ ! -s "$site/templates.html" ]; then
      echo "the site is missing the templates chapter" >&2
      exit 1
    fi

    templates="$(sed -nE 's/^[[:blank:]]*templates\.([A-Za-z0-9_-]+)[[:blank:]]*=.*/\1/p' "$rootFlake" | sort -u)"
    if [ -z "$templates" ]; then
      echo "no template found in $rootFlake; has the flake been restructured?" >&2
      exit 1
    fi

    status=0
    while IFS= read -r template; do
      case "$template" in
        # `templates.default` is instantiated by the bare `nix flake init -t`,
        # with no attribute path.
        default) needle="nix flake init -t" ;;
        *) needle="#templates.$template" ;;
      esac

      if ! grep -qF -- "$needle" "$site/templates.html"; then
        echo "the templates chapter never shows how to instantiate templates.$template" >&2
        status=1
      fi
    done <<< "$templates"

    if [ "$status" -ne 0 ]; then
      exit 1
    fi

    touch "$out"
  '';

  # site.GUIDES.7
  "site.GUIDES.7" = chapterCheck "site.GUIDES.7" [
    {
      page = "contributing.html";
      phrases = [
        # Setting the environment up, running the checks, and refreshing the
        # generated blocks.
        "devenv inputs add conan-flake"
        "just check"
        "embedmd"
        "mdsh"
      ];
    }
  ];

  # site.GUIDES.8
  "site.GUIDES.8" = chapterCheck "site.GUIDES.8" [
    {
      page = "references.html";
      phrases = [
        "haskell-flake"
        "treefmt-nix"
        "nix.dev"
      ];
    }
  ];

  # The changelog chapter presents `CHANGELOG.md` itself: its heading and its
  # most recent release have to be the ones that file carries.
  #
  # site.GUIDES.9
  "site.GUIDES.9" = check "site.GUIDES.9" { inherit changelog site; } ''
    set -euo pipefail

    if [ ! -s "$site/changelog.html" ]; then
      echo "the site is missing the changelog chapter" >&2
      exit 1
    fi

    status=0
    while IFS= read -r heading; do
      if ! grep -qF -- "$heading" "$site/changelog.html"; then
        echo "the changelog chapter does not carry the revision history entry: $heading" >&2
        status=1
      fi
    done < <(grep -E '^#{1,2} ' "$changelog" | sed -E 's/^#+ //' | head -n 3)

    if [ "$status" -ne 0 ]; then
      exit 1
    fi

    touch "$out"
  '';

  # site.OPTIONS_REFERENCE.1
  "site.OPTIONS_REFERENCE.1" = chapterCheck "site.OPTIONS_REFERENCE.1" (
    map
      (page: {
        inherit page;
        phrases = [ optionsReference ];
      })
      [
        "index.html"
        "getting-started.html"
        "flake-parts.html"
        "devenv.html"
        "standalone.html"
        "toolchains.html"
        "toolchains-llvm.html"
        "toolchains-cuda.html"
        "contributing.html"
        "references.html"
      ]
  );

  # Every configuration sample of the site comes out of an example project:
  # a `nix` or `ini` block written by hand, rather than declared by the
  # `embedmd` marker above it, is what this forbids.
  #
  # site.SAMPLES.1
  # authoring.EMBEDDING.1
  "authoring.EMBEDDING.1" = check "authoring.EMBEDDING.1" { inherit authoringSources; } ''
    set -euo pipefail

    status=0
    for source in "$authoringSources"/docs/src/*.md; do
      awk -v source="''${source##*/}" '
        # Fenced blocks are tracked by the length of their fence, so that a
        # marker *shown* to the reader inside a longer fence is not mistaken
        # for one the embedding step acts on.
        match($0, /^`+/) {
          if (!inside) {
            inside = 1
            opening = RLENGTH
            if (($0 ~ /^```nix/ || $0 ~ /^```ini/) && previous !~ /^\[embedmd\]:#/) {
              printf "%s:%d: %s block is written by hand instead of embedded from an example project\n", source, NR, $0 > "/dev/stderr"
              failed = 1
            }
          } else if (RLENGTH >= opening && substr($0, RLENGTH + 1) ~ /^[[:space:]]*$/) {
            inside = 0
          }
          previous = $0
          next
        }
        !inside { previous = $0 }
        END { exit failed }
      ' "$source" || status=1
    done

    if [ "$status" -ne 0 ]; then
      exit 1
    fi

    touch "$out"
  '';

  # Running the embedding step over the sources has to be a no-op: a sample
  # that drifted from the example project it names fails here rather than
  # rotting in place.
  #
  # site.SAMPLES.2
  # authoring.EMBEDDING.2
  "authoring.EMBEDDING.2" =
    check "authoring.EMBEDDING.2"
      {
        inherit authoringSources;
        nativeBuildInputs = [ embedmd ];
      }
      ''
        set -euo pipefail

        cp -R --no-preserve=mode,ownership "$authoringSources" tree
        cd tree

        embedmd docs/src/*.md

        status=0
        for source in docs/src/*.md; do
          if ! diff -u "$authoringSources/$source" "$source"; then
            echo "$source is not what embedmd generates from the example projects it names" >&2
            status=1
          fi
        done

        if [ "$status" -ne 0 ]; then
          exit 1
        fi

        touch "$out"
      '';

}
