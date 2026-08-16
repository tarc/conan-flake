# Assertions over the built documentation site, one derivation per ACID.
#
# `dev/flake.nix` wires them into `nix flake check ./dev`, which is what makes
# the site's build and its sub-path behaviour a CI failure when they regress.
#
# site.BUILD.3
{
  lib,
  runCommand,
  embedmd,
  git,
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

  # The revision history, so the changelog chapter can be compared against the
  # file it presents instead of against a transcription of it.
  changelog = builtins.path {
    path = ../../../CHANGELOG.md;
    name = "conan-flake-CHANGELOG.md";
  };

  # The flake declaring the templates, so the templates chapter can be checked
  # against the templates that actually exist rather than against a list.
  rootFlake = builtins.path {
    path = ../../../flake.nix;
    name = "conan-flake-flake.nix";
  };

  # The publishing side: the one script `just docs-publish` and
  # `.woodpecker/pages.yml` both run, the wrapper the pipeline runs it through,
  # and the two files that call them. The checks below read these rather than
  # restating what they say.
  publishScript = builtins.path {
    path = ../../../scripts/publish-pages.sh;
    name = "conan-flake-publish-pages.sh";
  };

  publishCiScript = builtins.path {
    path = ../../../scripts/publish-pages-ci.sh;
    name = "conan-flake-publish-pages-ci.sh";
  };

  justfile = builtins.path {
    path = ../../../justfile;
    name = "conan-flake-justfile";
  };

  pagesPipeline = builtins.path {
    path = ../../../.woodpecker/pages.yml;
    name = "conan-flake-woodpecker-pages.yml";
  };

  repositoryRoot = toString ../../..;

  # The Markdown sources of the site next to the example projects they embed
  # from, laid out exactly as in the checkout so that the `docs/src/.examples`
  # symbolic link the markers go through still resolves. Generated and
  # git-ignored trees are left out: they are not embedded from, and they would
  # make this derivation change on every local Conan run.
  #
  # authoring.EMBEDDING.2
  authoringSources = builtins.path {
    path = ../../..;
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

  # Each check declares the inputs it actually reads, so that an edit under
  # `examples/` invalidates the two checks that read the example projects rather
  # than all of them, and `embedmd` stays out of the closure of the checks that
  # only grep the rendered site.
  check =
    acid: env: script:
    runCommand "docs-${acid}" env script;

  # The rendered site alone: what most checks read.
  siteOnly = { inherit site; };

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

  # The URL of the published, generated option reference. Not restated by any
  # check below: they all read it from here.
  optionsReference = "https://flake.parts/options/conan-flake.html";

  repository = "https://codeberg.org/tarcisio/conan-flake";

  # The address the site is served from once the webhook of the activation
  # checklist is registered. Read from here by the publishing checks, and
  # compared against `book.toml` rather than trusted.
  publishedUrl = "https://tarcisio.codeberg.page/conan-flake/";

  # What the publishing checks need: the built site, the script under test, and
  # a git to run it against.
  publishEnv = {
    inherit site publishScript;
    nativeBuildInputs = [ git ];
  };

  # A scratch repository standing in for a contributor's checkout, with the
  # publish script pointed at the site this derivation already depends on and
  # told not to push. Everything the branch-shaped requirements describe is
  # observable there, with no forge, no credential and no network — which is
  # also why the site is handed over through `PAGES_SITE` instead of being
  # built again inside the sandbox.
  publishPrelude = ''
    set -euo pipefail

    export HOME="$TMPDIR"

    # A fresh repository carries no user configuration, and the commit the
    # publish script makes needs an identity.
    export GIT_AUTHOR_NAME="conan-flake checks"
    export GIT_AUTHOR_EMAIL="checks@conan-flake.invalid"
    export GIT_COMMITTER_NAME="$GIT_AUTHOR_NAME"
    export GIT_COMMITTER_EMAIL="$GIT_AUTHOR_EMAIL"

    git init --quiet --initial-branch main "$TMPDIR/checkout"
    cd "$TMPDIR/checkout"

    # Something recognisable as this repository's source, to look for on the
    # published branch afterwards.
    mkdir -p docs/src
    echo 'the source of the repository' > README.md
    echo 'a source chapter' > docs/src/index.md
    git add --all
    git commit --quiet --message 'the source history'

    publish() {
      PAGES_PUSH=0 PAGES_SITE="$1" bash "$publishScript"
    }
  '';

  publishCheck = acid: script: check acid publishEnv (publishPrelude + script);
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

  # publishing.BRANCH.1
  "publishing.BRANCH.1" = publishCheck "publishing.BRANCH.1" ''
    publish "$site" > /dev/null

    if ! git rev-parse --verify --quiet refs/heads/pages > /dev/null; then
      echo "publishing left no branch named pages behind" >&2
      git branch --all >&2
      exit 1
    fi

    # The entry page at the root of the branch, which is the entry page
    # git-pages serves for the site's own URL.
    if [ -z "$(git ls-tree --name-only pages -- index.html)" ]; then
      echo "the pages branch carries no entry page at its root" >&2
      git ls-tree --name-only pages >&2
      exit 1
    fi

    touch "$out"
  '';

  # publishing.BRANCH.2
  "publishing.BRANCH.2" = publishCheck "publishing.BRANCH.2" ''
    # A site carrying one page more than the next build does: republishing has
    # to drop it, or a page removed from the site would go on being served.
    cp -RL --no-preserve=mode,ownership "$site" "$TMPDIR/stale-site"
    echo 'a page that goes away' > "$TMPDIR/stale-site/gone.html"

    publish "$TMPDIR/stale-site" > /dev/null
    if [ -z "$(git ls-tree --name-only pages -- gone.html)" ]; then
      echo "the first publication did not carry the page this check drops" >&2
      exit 1
    fi

    publish "$site" > /dev/null
    if [ -n "$(git ls-tree --name-only pages -- gone.html)" ]; then
      echo "a page dropped from the site survived on the pages branch" >&2
      exit 1
    fi

    touch "$out"
  '';

  # publishing.BRANCH.3
  "publishing.BRANCH.3" = publishCheck "publishing.BRANCH.3" ''
    publish "$site" > /dev/null
    publish "$site" > /dev/null

    status=0

    # The branch starts at a root commit of its own, and keeps exactly one: its
    # history never joins the history of the source branches.
    roots="$(git rev-list --max-parents=0 pages | wc -l)"
    if [ "$roots" != 1 ]; then
      echo "the pages branch has $roots root commits; expected exactly one" >&2
      status=1
    fi

    if git merge-base --is-ancestor main pages; then
      echo "the pages branch descends from the source branch" >&2
      status=1
    fi

    # ... and it carries no source of the repository.
    for path in README.md docs/src/index.md; do
      if [ -n "$(git ls-tree -r --name-only pages -- "$path")" ]; then
        echo "the pages branch carries the repository source file $path" >&2
        status=1
      fi
    done

    if [ "$status" -ne 0 ]; then
      exit 1
    fi

    touch "$out"
  '';

  # One script, two callers: the recipe a contributor runs and the wrapper the
  # pipeline runs, so that publishing locally and publishing from CI cannot
  # drift apart.
  #
  # publishing.PUBLISH.1
  "publishing.PUBLISH.1" =
    check "publishing.PUBLISH.1"
      {
        inherit
          justfile
          publishCiScript
          publishScript
          site
          ;
      }
      ''
        set -euo pipefail

        status=0

        if ! grep -qE '^docs-publish:' "$justfile"; then
          echo "no docs-publish recipe in the justfile" >&2
          status=1
        fi

        for caller in "$justfile" "$publishCiScript"; do
          if ! grep -qF 'publish-pages.sh' "$caller"; then
            echo "''${caller##*-} does not run the publish script" >&2
            status=1
          fi
        done

        # The script builds the site itself, so that the one command does both.
        if ! grep -qF 'nix build ./dev#docs' "$publishScript"; then
          echo "the publish script does not build the site" >&2
          status=1
        fi

        # ... and the command is documented where a contributor looks for it.
        if ! grep -qF 'just docs-publish' "$site/contributing.html"; then
          echo "the contributing chapter does not document the publish command" >&2
          status=1
        fi

        if [ "$status" -ne 0 ]; then
          exit 1
        fi

        touch "$out"
      '';

  # publishing.PUBLISH.2
  "publishing.PUBLISH.2" = publishCheck "publishing.PUBLISH.2" ''
    # The scratch repository has no remote, the sandbox has no network and
    # nothing hands the script a token: publishing still works, so the local
    # path needs no credential of its own.
    publish "$site" > /dev/null

    status=0

    # Nor does it carry the machinery for one: the push goes through a remote of
    # the checkout, whose credentials are the contributor's own.
    if grep -nE 'TOKEN|PASSWORD|GIT_ASKPASS|http\.extraHeader|://[^ ]*:[^ ]*@' "$publishScript"; then
      echo "the publish script handles a credential of its own (matches above)" >&2
      status=1
    fi

    if [ "$status" -ne 0 ]; then
      exit 1
    fi

    touch "$out"
  '';

  # publishing.PUBLISH.3
  "publishing.PUBLISH.3" = publishCheck "publishing.PUBLISH.3" ''
    publish "$site" > /dev/null

    published="$(git rev-parse pages)"
    branch="$(git rev-parse --abbrev-ref HEAD)"
    tree="$(git status --porcelain)"

    status=0

    # Two ways for the build to fail the script: the build command itself
    # failing, and a build that produced no site.
    mkdir -p "$TMPDIR/no-site"
    for attempt in build-fails site-empty; do
      case "$attempt" in
        build-fails) failing=(env PAGES_BUILD_COMMAND=false) ;;
        site-empty) failing=(env PAGES_SITE="$TMPDIR/no-site") ;;
      esac

      if PAGES_PUSH=0 "''${failing[@]}" bash "$publishScript"; then
        echo "the publish script succeeded although the build produced no site ($attempt)" >&2
        status=1
      fi

      if [ "$(git rev-parse pages)" != "$published" ]; then
        echo "a failed build moved the pages branch ($attempt)" >&2
        status=1
      fi

      if [ "$(git status --porcelain)" != "$tree" ]; then
        echo "a failed build modified the working tree ($attempt)" >&2
        git status --porcelain >&2
        status=1
      fi

      if [ "$(git rev-parse --abbrev-ref HEAD)" != "$branch" ]; then
        echo "a failed build changed the checked out branch ($attempt)" >&2
        status=1
      fi

      # ... and it left no worktree of its own behind either.
      if [ "$(git worktree list | wc -l)" != 1 ]; then
        echo "a failed build left a worktree behind ($attempt)" >&2
        git worktree list >&2
        status=1
      fi
    done

    if [ "$status" -ne 0 ]; then
      exit 1
    fi

    touch "$out"
  '';

  # publishing.PUBLISH.4
  "publishing.PUBLISH.4" = publishCheck "publishing.PUBLISH.4" ''
    branch="$(git rev-parse --abbrev-ref HEAD)"
    head="$(git rev-parse HEAD)"
    tree="$(git status --porcelain)"

    publish "$site" > /dev/null

    status=0

    if [ "$(git rev-parse --abbrev-ref HEAD)" != "$branch" ]; then
      echo "publishing left $(git rev-parse --abbrev-ref HEAD) checked out instead of $branch" >&2
      status=1
    fi

    if [ "$(git rev-parse HEAD)" != "$head" ]; then
      echo "publishing moved the branch it was invoked from" >&2
      status=1
    fi

    if [ "$(git status --porcelain)" != "$tree" ]; then
      echo "publishing modified the working tree" >&2
      git status --porcelain >&2
      status=1
    fi

    # The worktree the site was committed through is the checkout's own only
    # for as long as the script runs.
    if [ "$(git worktree list | wc -l)" != 1 ]; then
      echo "publishing left a worktree behind" >&2
      git worktree list >&2
      status=1
    fi

    if [ "$status" -ne 0 ]; then
      exit 1
    fi

    touch "$out"
  '';

  # publishing.CI.1
  "publishing.CI.1" =
    check "publishing.CI.1"
      {
        inherit pagesPipeline publishCiScript;
      }
      ''
        set -euo pipefail

        status=0

        # The pipeline runs on the default branch, for the sources the site is
        # built from, and publishes by running the same script a contributor
        # runs. The publishing step is gated on `manual` until the push
        # credential exists — see the `publishing.CI.2` check.
        for pattern in 'event: \[push, manual\]' 'branch: main' '"docs/\*\*"' 'publish-pages-ci\.sh'; do
          if ! grep -qE -- "$pattern" "$pagesPipeline"; then
            echo "the pages pipeline does not carry: $pattern" >&2
            status=1
          fi
        done

        if ! grep -qF './scripts/publish-pages.sh' "$publishCiScript"; then
          echo "the pipeline wrapper does not run the publish script" >&2
          status=1
        fi

        if [ "$status" -ne 0 ]; then
          exit 1
        fi

        touch "$out"
      '';

  # The pipeline reports success and publishes nothing while no push credential
  # is registered. Two things have to hold for that: the wrapper the pipeline
  # runs exits 0 without touching anything when the variable is empty or unset,
  # and the step naming the secret is skipped while the secret does not exist —
  # Woodpecker resolves secrets at compile time and fails the whole workflow
  # with `secret "codeberg_token" not found` otherwise, which is why the
  # publishing step is gated on `manual` and a step carrying no secret runs the
  # wrapper on a push.
  #
  # publishing.CI.2
  "publishing.CI.2" =
    check "publishing.CI.2"
      {
        inherit pagesPipeline publishCiScript;
        nativeBuildInputs = [ git ];
      }
      ''
        set -euo pipefail

        export HOME="$TMPDIR"
        export GIT_AUTHOR_NAME="conan-flake checks"
        export GIT_AUTHOR_EMAIL="checks@conan-flake.invalid"
        export GIT_COMMITTER_NAME="$GIT_AUTHOR_NAME"
        export GIT_COMMITTER_EMAIL="$GIT_AUTHOR_EMAIL"

        git init --quiet --initial-branch main "$TMPDIR/checkout"
        cd "$TMPDIR/checkout"
        git commit --quiet --allow-empty --message 'the source history'

        status=0

        for attempt in unset empty; do
          case "$attempt" in
            unset) credential=(env -u CODEBERG_TOKEN) ;;
            empty) credential=(env CODEBERG_TOKEN=) ;;
          esac

          if ! "''${credential[@]}" bash "$publishCiScript" > "$TMPDIR/$attempt.log" 2>&1; then
            echo "the pipeline wrapper failed while the credential is $attempt" >&2
            cat "$TMPDIR/$attempt.log" >&2
            status=1
            continue
          fi

          if ! grep -qF 'Nothing was published' "$TMPDIR/$attempt.log"; then
            echo "the pipeline wrapper did not say that nothing was published ($attempt)" >&2
            cat "$TMPDIR/$attempt.log" >&2
            status=1
          fi

          if git rev-parse --verify --quiet refs/heads/pages > /dev/null; then
            echo "the pipeline wrapper published although no credential is $attempt" >&2
            status=1
          fi

          if [ -n "$(git remote)" ]; then
            echo "the pipeline wrapper left a remote behind ($attempt)" >&2
            status=1
          fi
        done

        # The secret the pipeline expects, named once and only where a secret
        # can be read from, and the step that keeps a push green in the
        # meantime.
        if ! grep -qF 'from_secret: codeberg_token' "$pagesPipeline"; then
          echo "the pipeline does not read the codeberg_token secret" >&2
          status=1
        fi

        if ! grep -qF 'name: publication-status' "$pagesPipeline"; then
          echo "the pipeline has no step to report on a push while publication is off" >&2
          status=1
        fi

        if [ "$status" -ne 0 ]; then
          exit 1
        fi

        touch "$out"
      '';

  # The site is configured for exactly the address it is published at: the
  # sub-path `book.toml` builds the generated 404 page's URLs from has to be the
  # path of that address, or a visitor landing on a missing page leaves the
  # site. Reachability itself cannot be observed from a build sandbox — it needs
  # the webhook of the activation checklist — and is verified by loading the URL.
  #
  # publishing.SERVING.1
  "publishing.SERVING.1" =
    check "publishing.SERVING.1"
      {
        inherit bookToml pagesPipeline site;
        url = publishedUrl;
      }
      ''
        set -euo pipefail

        status=0

        siteUrl="$(sed -n 's/^site-url[[:blank:]]*=[[:blank:]]*"\(.*\)"[[:blank:]]*$/\1/p' "$bookToml")"
        expected="/''${url#*://*/}"
        if [ "$siteUrl" != "$expected" ]; then
          echo "book.toml builds the site for $siteUrl, but it is published at $url ($expected)" >&2
          status=1
        fi

        # The address a visitor is given, and the address the pipeline's own
        # comments name, are the one this check reads.
        for file in "$site/contributing.html" "$pagesPipeline"; do
          if ! grep -qF "$url" "$file"; then
            echo "''${file##*/} does not name the address the site is published at: $url" >&2
            status=1
          fi
        done

        if [ "$status" -ne 0 ]; then
          exit 1
        fi

        touch "$out"
      '';

  # publishing.SERVING.2
  "publishing.SERVING.2" = publishCheck "publishing.SERVING.2" ''
    status=0

    # git-pages answers a request for a path the site does not carry with the
    # `404.html` at the root of the served content, so the site's own not-found
    # page has to be there — and be the site's, not an empty file.
    if [ ! -s "$site/404.html" ]; then
      echo "the site renders no 404 page" >&2
      status=1
    elif ! grep -qF 'conan-flake' "$site/404.html"; then
      echo "the 404 page is not the site's own" >&2
      status=1
    fi

    publish "$site" > /dev/null
    if [ -z "$(git ls-tree --name-only pages -- 404.html)" ]; then
      echo "the published branch carries no 404.html at its root" >&2
      git ls-tree --name-only pages >&2
      status=1
    fi

    if [ "$status" -ne 0 ]; then
      exit 1
    fi

    touch "$out"
  '';

  # publishing.SETUP.1
  "publishing.SETUP.1" = chapterCheck "publishing.SETUP.1" [
    {
      page = "contributing.html";
      phrases = [
        # The webhook: its type, the target URL that doubles as the address of
        # the site, and the branch it filters on.
        "Forgejo"
        publishedUrl
        "Branch filter"
        "pages"
        # ... that its test delivery fails by design, so nobody reads that as a
        # broken setup.
        "Test delivery"
        # The credential the pipeline reads, by the exact name it looks for.
        "codeberg_token"
        # The first publication, and how to see whether it arrived.
        "just docs-publish"
        ".git-pages/manifest.json"
      ];
    }
  ];

  # publishing.ARTIFACT.1
  "publishing.ARTIFACT.1" = publishCheck "publishing.ARTIFACT.1" ''
    publish "$site" > /dev/null

    # What the branch carries is the output of the site's derivation, file for
    # file: nothing of the repository is added, nothing of the site is left out,
    # and no server-side build step is expected to make up the difference.
    git worktree add --quiet "$TMPDIR/published" pages
    if ! diff -r -x .git "$site" "$TMPDIR/published"; then
      echo "the published branch is not the output of the site's derivation" >&2
      exit 1
    fi

    touch "$out"
  '';

  # publishing.ARTIFACT.2
  "publishing.ARTIFACT.2" = publishCheck "publishing.ARTIFACT.2" ''
    publish "$site" > /dev/null
    git worktree add --quiet "$TMPDIR/published" pages

    status=0

    # git records a symbolic link as mode 120000, so a link into the Nix store
    # would be published as one and dangle for every visitor. The published tree
    # has regular files only.
    unexpected="$(git ls-tree -r pages | awk '$1 != "100644" && $1 != "100755"')"
    if [ -n "$unexpected" ]; then
      echo "the published branch carries entries that are not regular files:" >&2
      echo "$unexpected" >&2
      status=1
    fi

    # ... and a checkout of it is a plain, writable tree, not the read-only
    # store path it was copied from.
    while IFS= read -r path; do
      echo "not readable and writable by its owner: ''${path#"$TMPDIR/published"/}" >&2
      status=1
    done < <(
      find "$TMPDIR/published" -name .git -prune -o \
        \( ! -perm -u+r -o ! -perm -u+w \) -print
    )

    # Nothing in the built site dangles either, which is what a store symlink
    # copied verbatim would look like.
    while IFS= read -r link; do
      echo "dangling symbolic link in the built site: ''${link#"$site"/}" >&2
      status=1
    done < <(find "$site" -xtype l)

    if [ "$status" -ne 0 ]; then
      exit 1
    fi

    touch "$out"
  '';
}
