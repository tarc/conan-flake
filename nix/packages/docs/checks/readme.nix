# Assertions over the repository's `README.md`, one derivation per ACID of the
# `readme` feature: what the file still carries now that the site carries the
# documentation, where it sends a reader for everything else, and that neither
# its own links nor the wiring around its generated blocks were left pointing at
# something that is gone. `../checks.nix` merges these with the site and
# publishing ones.
#
# site.BUILD.3
{
  lib,
  check,
  embedmd,
  site,
  summary,
  publishedUrl,
  optionsReference,
  ...
}:
let
  readme = builtins.path {
    path = ../../../../README.md;
    name = "conan-flake-README.md";
  };

  license = builtins.path {
    path = ../../../../LICENSE;
    name = "conan-flake-LICENSE";
  };

  repositoryRoot = toString ../../../..;

  # `README.md` next to the example projects it embeds from, laid out as in the
  # checkout, so that the embedding step can be run over it here exactly as the
  # commit hook runs it there. Generated and git-ignored trees are left out:
  # they are not embedded from, and they would make this derivation change on
  # every local Conan run.
  #
  # readme.INTEGRITY.2
  readmeSources = builtins.path {
    path = ../../../..;
    name = "conan-flake-readme-source";
    filter =
      path: _type:
      let
        relative = lib.removePrefix "${repositoryRoot}/" path;
        wanted = relative == "README.md" || relative == "examples" || lib.hasPrefix "examples/" relative;
        generated = builtins.elem (baseNameOf path) [
          ".conan2"
          ".direnv"
          "config"
          "flake.lock"
          "result"
        ];
      in
      wanted && !generated;
  };

  # Every file of the repository that could name a heading of `README.md`: its
  # Markdown, its Nix, its pipelines and its `justfile`. Trees that are
  # generated, git-ignored or not part of the repository's sources are left out
  # — `.boost` in particular carries a socket, which is not something
  # `builtins.path` can copy.
  #
  # readme.INTEGRITY.3
  repositoryText = builtins.path {
    path = ../../../..;
    name = "conan-flake-readme-referrers";
    filter =
      path: type:
      let
        base = baseNameOf path;
        ignored = builtins.elem base [
          ".boost"
          ".conan2"
          ".devenv"
          ".direnv"
          ".git"
          "book"
          "config"
          "node_modules"
          "result"
          "tmp"
        ];
        text =
          lib.hasSuffix ".md" base
          || lib.hasSuffix ".nix" base
          || lib.hasSuffix ".yml" base
          || lib.hasSuffix ".yaml" base
          || base == "justfile";
      in
      !ignored && (type == "directory" || text);
  };

  # The files that point a formatter or a commit hook at `README.md`.
  treefmtConfig = builtins.path {
    path = ../../../../dev/treefmt.nix;
    name = "conan-flake-dev-treefmt.nix";
  };

  devenvConfig = builtins.path {
    path = ../../../../dev/devenv.nix;
    name = "conan-flake-dev-devenv.nix";
  };

  devFlake = builtins.path {
    path = ../../../../dev/flake.nix;
    name = "conan-flake-dev-flake.nix";
  };

  # Every page the table of contents names, as the `.html` the site renders it
  # to, one per line. `README.md` has to link to each of them, and each has to
  # exist in the built site.
  chapterPages = ''
    chapter_pages() {
      grep -oE '\]\([^)]+\.md\)' "$summary" |
        sed -E 's|^\]\((\./)?||; s|\.md\)$|.html|' |
        sort -u
    }
  '';

  # The bodies of the Markdown links `README.md` carries, one per line. Written
  # once because three checks below read them.
  readmeLinks = ''
    readme_links() {
      grep -oE '\]\([^)]+\)' "$readme" | sed -E 's/^\]\(//; s/\)$//'
    }
  '';
in
{
  # What the file still says: what conan-flake is, one configuration example,
  # and the command that instantiates it. The example is embedded from an
  # example project rather than written out, the way the site's samples are.
  #
  # readme.SCOPE.1
  "readme.SCOPE.1" =
    check "readme.SCOPE.1"
      {
        inherit readme;
      }
      ''
        set -euo pipefail

        status=0

        # What the project is, in terms of the two things it bridges.
        for phrase in Nix Conan; do
          if ! grep -qF -- "$phrase" "$readme"; then
            echo "README.md never says what conan-flake has to do with $phrase" >&2
            status=1
          fi
        done

        # The one configuration example, declared by a marker rather than
        # transcribed ...
        markers="$(grep -c '^\[embedmd\]:#' "$readme" || true)"
        if [ "$markers" -lt 1 ]; then
          echo "README.md shows no embedded configuration example" >&2
          status=1
        fi

        # ... which is what every `nix`/`ini` block in it has to be.
        while IFS= read -r line; do
          number="''${line%%:*}"
          previous="$(sed -n "$((number - 1))p" "$readme")"
          case "$previous" in
            '[embedmd]:#'*) ;;
            *)
              echo "README.md:$number: a $line block is written by hand instead of embedded from an example project" >&2
              status=1
              ;;
          esac
        done < <(grep -nE '^```(nix|ini)$' "$readme")

        # And how to instantiate it.
        if ! grep -qF 'nix flake init -t' "$readme"; then
          echo "README.md never says how to instantiate conan-flake" >&2
          status=1
        fi

        if [ "$status" -ne 0 ]; then
          exit 1
        fi

        touch "$out"
      '';

  # The three destinations a visitor of the forge page has to be given: the
  # site, the generated option reference, and the licence the file it links to
  # actually is.
  #
  # readme.SCOPE.2
  "readme.SCOPE.2" =
    check "readme.SCOPE.2"
      {
        inherit readme license;
        url = publishedUrl;
        options = optionsReference;
      }
      ''
        set -euo pipefail

        status=0

        for destination in "$url" "$options"; do
          if ! grep -qF -- "$destination" "$readme"; then
            echo "README.md does not link to $destination" >&2
            status=1
          fi
        done

        if ! grep -qF '](LICENSE)' "$readme"; then
          echo "README.md does not link to the LICENSE file next to it" >&2
          status=1
        fi

        if [ ! -s "$license" ]; then
          echo "the LICENSE file README.md links to is empty" >&2
          status=1
        fi

        if [ "$status" -ne 0 ]; then
          exit 1
        fi

        touch "$out"
      '';

  # Every chapter of the site is linked from `README.md`, so that each topic the
  # file stopped covering has a visible destination. The list is read from the
  # table of contents rather than restated here: a chapter added to the site and
  # not to `README.md` fails this.
  #
  # readme.SCOPE.3
  "readme.SCOPE.3" =
    check "readme.SCOPE.3"
      {
        inherit readme summary;
        url = publishedUrl;
      }
      (
        chapterPages
        + ''
          set -euo pipefail

          pages="$(chapter_pages)"
          if [ -z "$pages" ]; then
            echo "the table of contents names no chapter at all: $summary" >&2
            exit 1
          fi

          status=0
          while IFS= read -r page; do
            case "$page" in
              # The entry page of the site is linked as the site itself.
              index.html) target="$url" ;;
              *) target="$url$page" ;;
            esac

            if ! grep -qF -- "$target" "$readme"; then
              echo "README.md does not link to the chapter that covers it: $target" >&2
              status=1
            fi
          done <<< "$pages"

          if [ "$status" -ne 0 ]; then
            exit 1
          fi

          touch "$out"
        ''
      );

  # Every anchor `README.md` points at is a heading `README.md` still has. The
  # links removed with the sections they pointed at are what this catches.
  #
  # readme.INTEGRITY.1
  "readme.INTEGRITY.1" =
    check "readme.INTEGRITY.1"
      {
        inherit readme;
      }
      (
        readmeLinks
        + ''
          set -euo pipefail

          # The anchor a forge derives from a heading: lowercased, punctuation
          # dropped, spaces turned into hyphens.
          slug() {
            printf '%s\n' "$1" |
              tr '[:upper:]' '[:lower:]' |
              sed -E 's/[^a-z0-9 _-]//g; s/ +/-/g'
          }

          headings="$(
            while IFS= read -r heading; do
              slug "''${heading#\#* }"
            done < <(grep -E '^#{1,6} ' "$readme")
          )"

          status=0
          while IFS= read -r link; do
            case "$link" in
              '#'*) ;;
              *) continue ;;
            esac

            if ! printf '%s\n' "$headings" | grep -qxF -- "''${link#\#}"; then
              echo "README.md links to $link, which is not a heading it has" >&2
              status=1
            fi
          done < <(readme_links)

          if [ "$status" -ne 0 ]; then
            exit 1
          fi

          touch "$out"
        ''
      );

  # The sample `README.md` kept is still refreshed by the repository's own
  # embedding step: running it here has to be a no-op, and the formatter and the
  # commit hook have to keep naming the file. The other direction is checked too
  # — a formatter pointed at a kind of block the file no longer carries is as
  # incoherent as a block nobody refreshes.
  #
  # readme.INTEGRITY.2
  "readme.INTEGRITY.2" =
    check "readme.INTEGRITY.2"
      {
        inherit
          readme
          readmeSources
          treefmtConfig
          devenvConfig
          devFlake
          ;
        nativeBuildInputs = [ embedmd ];
      }
      ''
        set -euo pipefail

        cp -R --no-preserve=mode,ownership "$readmeSources" tree
        cd tree

        embedmd README.md

        if ! diff -u "$readme" README.md; then
          echo "README.md is not what embedmd generates from the example project it names" >&2
          exit 1
        fi

        cd ..

        status=0

        # The formatter and both copies of the commit hook — `dev/devenv.nix`
        # and `dev/flake.nix` generate the same `.pre-commit-config.yaml`, so
        # both have to run the embedding step over the file.
        #
        # The Nix comments of those files talk about `README.md` at length;
        # only what they configure is read here.
        settings() {
          sed -E 's/#.*//' "$1"
        }

        if ! settings "$treefmtConfig" | grep -qF 'README.md'; then
          echo "dev/treefmt.nix no longer points any formatter at README.md" >&2
          status=1
        fi

        for hook in "$devenvConfig" "$devFlake"; do
          if ! settings "$hook" | grep -qE 'embedmd README\.md'; then
            echo "''${hook##*/} does not run the embedding step over README.md" >&2
            status=1
          fi
        done

        # The block of a named formatter in `dev/treefmt.nix`, comments
        # stripped: the attribute set it opens, up to the `};` closing it at the
        # same indentation.
        formatter() {
          settings "$treefmtConfig" | awk -v name="$1" '
            !inside && index($0, name " = {") { indent = match($0, /[^ ]/); inside = 1; next }
            inside && $0 ~ /^[[:space:]]*\};/ && match($0, /[^ ]/) == indent { inside = 0 }
            inside { print }
          '
        }

        if ! formatter embedmd | grep -qF 'README.md'; then
          echo "the embedmd formatter no longer covers README.md" >&2
          status=1
        fi

        # `deno fmt` respells the marker it carries, so the file stays out of it.
        if ! formatter deno | grep -qF 'README.md'; then
          echo "README.md is no longer excluded from deno, which rewrites its marker" >&2
          status=1
        fi

        # The command-output side, in whichever state it is: a file carrying no
        # such block is not to be handed to `mdsh`, and one carrying a block has
        # to be.
        if grep -qF '<!-- BEGIN mdsh -->' "$readme"; then
          if ! formatter mdsh | grep -qF 'README.md'; then
            echo "README.md carries a command-output block that mdsh does not refresh" >&2
            status=1
          fi
        elif formatter mdsh | grep -qF 'README.md'; then
          echo "mdsh is pointed at README.md, which carries no command-output block" >&2
          status=1
        fi

        if [ "$status" -ne 0 ]; then
          exit 1
        fi

        touch "$out"
      '';

  # Nothing else in the repository points at a heading of `README.md`. Every
  # source that could — its Markdown, its Nix, its pipelines, its `justfile` —
  # is scanned, rather than the handful of files that happen to name the file
  # today.
  #
  # readme.INTEGRITY.3
  "readme.INTEGRITY.3" =
    check "readme.INTEGRITY.3"
      {
        inherit readme repositoryText;
      }
      ''
        set -euo pipefail

        # A link naming the file and then a section of it, however it spells
        # the path: relative, repository-relative, or a full forge URL. The
        # pattern is assembled rather than written out, so that this file does
        # not match itself.
        references="$(grep -rn "README\.md$(printf '#')" "$repositoryText" || true)"

        if [ -n "$references" ]; then
          echo "these refer to a heading of README.md, which is a pointer at the site now:" >&2
          printf '%s\n' "$references" >&2
          exit 1
        fi

        touch "$out"
      '';

  # The material `README.md` stopped carrying is on the site before the file
  # sends anyone there: every page it links to has to have been rendered by the
  # build this check reads. A link into the site added ahead of the chapter
  # behind it fails here.
  #
  # readme.ORDER.1
  "readme.ORDER.1" =
    check "readme.ORDER.1"
      {
        inherit readme site;
        url = publishedUrl;
      }
      (
        readmeLinks
        + ''
          set -euo pipefail

          status=0
          linked=0

          while IFS= read -r link; do
            case "$link" in
              "$url"*) ;;
              *) continue ;;
            esac

            linked=$((linked + 1))

            page="''${link#"$url"}"
            page="''${page%%#*}"
            # A link to the site itself is a link to its entry page.
            if [ -z "$page" ]; then
              page=index.html
            fi

            if [ ! -s "$site/$page" ]; then
              echo "README.md sends a reader to $link, which the site does not carry" >&2
              status=1
            fi
          done < <(readme_links)

          if [ "$linked" -eq 0 ]; then
            echo "README.md links to no page of the site at all" >&2
            status=1
          fi

          if [ "$status" -ne 0 ]; then
            exit 1
          fi

          touch "$out"
        ''
      );
}
