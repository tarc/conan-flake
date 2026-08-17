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
  sourceTree,
  under,
  summary,
  publishedUrl,
  optionsReference,
  treefmtConfigFile,
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

  # `README.md` next to the example projects it embeds from, laid out as in the
  # checkout, so that the embedding step can be run over it here exactly as the
  # commit hook runs it there.
  #
  # readme.INTEGRITY.2
  readmeSources = sourceTree {
    name = "conan-flake-readme-source";
    wanted = relative: _type: relative == "README.md" || under "examples" relative;
  };

  # The trees of the repository a reference to a heading of `README.md` could
  # live in: its own sources, its documentation, its pipelines and its scripts.
  # Everything else at the root of the checkout is left out — a local agent or
  # editor directory is not part of the repository, `.boost` carries a socket
  # that `builtins.path` cannot copy, and `tmp` holds the task files this work
  # is described in.
  #
  # readme.INTEGRITY.3
  sourceDirectories = [
    ".woodpecker"
    "dev"
    "docs"
    "examples"
    "features"
    "nix"
    "scripts"
    "test"
  ];

  repositoryText = sourceTree {
    name = "conan-flake-readme-referrers";
    wanted =
      relative: type:
      let
        base = baseNameOf relative;
        # A file that could carry such a reference: prose, Nix, a pipeline, a
        # shell script or the `justfile`. The shell suffix is what makes the
        # `scripts` entry above reach anything — the publishing scripts are the
        # only files under it.
        text =
          lib.hasSuffix ".md" base
          || lib.hasSuffix ".nix" base
          || lib.hasSuffix ".sh" base
          || lib.hasSuffix ".yml" base
          || lib.hasSuffix ".yaml" base
          || base == "justfile";
        inTree = builtins.any (directory: under directory relative) sourceDirectories;
        atRoot = !lib.hasInfix "/" relative;
      in
      if type == "directory" then
        # Kept only so the files under it can be reached at all.
        inTree
      else
        text && (inTree || atRoot);
  };

  # The two files that point a commit hook at `README.md`. The formatter side is
  # read out of `treefmtConfigFile`, the *generated* `treefmt.toml`, rather than
  # out of the Nix that produces it.
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

        # ... which is what every `nix`/`ini` block in it has to be: the line
        # above a fence opening one has to be the marker it is generated from.
        # A fence on the first line has no line above it, and is reported the
        # same way rather than handed to `sed` as line 0.
        while IFS= read -r match; do
          number="''${match%%:*}"
          fence="''${match#*:}"
          if [ "$number" -gt 1 ]; then
            previous="$(sed -n "$((number - 1))p" "$readme")"
          else
            previous=
          fi

          case "$previous" in
            '[embedmd]:#'*) ;;
            *)
              echo "README.md:$number: a $fence block is written by hand instead of embedded from an example project" >&2
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
  # The formatters are read out of the generated `treefmt.toml`, which is what
  # `treefmt` itself is handed. The Nix that produces it cannot answer this:
  # `treefmt-nix` ships `programs.mdsh` as
  # `mkFormatterModule { includes = [ "README.md" ]; }`, so a `README.md` this
  # file never mentions is in the effective configuration all the same, and an
  # assertion over its text would report an exclusion that never happened.
  #
  # readme.INTEGRITY.2
  "readme.INTEGRITY.2" =
    check "readme.INTEGRITY.2"
      {
        inherit
          readme
          readmeSources
          devenvConfig
          devFlake
          ;
        treefmtConfig = treefmtConfigFile;
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

        # Both copies of the commit hook — `dev/devenv.nix` and `dev/flake.nix`
        # generate the same `.pre-commit-config.yaml`, so both have to run the
        # embedding step over the file. Their Nix comments talk about
        # `README.md` at length; only what they configure is read here.
        settings() {
          sed -E 's/#.*//' "$1"
        }

        # Named by the path it has in the checkout, not by the store path it
        # was copied to, so that a failure names a file a reader can open.
        hook() {
          if ! settings "$1" | grep -qE 'embedmd README\.md'; then
            echo "$2 does not run the embedding step over README.md" >&2
            status=1
          fi
        }

        hook "$devenvConfig" dev/devenv.nix
        hook "$devFlake" dev/flake.nix

        # The settings of a named formatter, as `treefmt` reads them: the
        # section it opens in the generated configuration, up to the next one.
        formatter() {
          awk -v section="[formatter.$1]" '
            $0 == section { inside = 1; next }
            inside && /^\[/ { inside = 0 }
            inside { print }
          ' "$treefmtConfig"
        }

        # One list of that section — `includes` or `excludes` — as generated:
        # one line of comma-separated quoted patterns.
        patterns() {
          formatter "$1" | sed -n "s/^$2 = //p"
        }

        covers() {
          patterns "$1" "$2" | grep -qF 'README.md'
        }

        if [ -z "$(formatter embedmd)" ]; then
          echo "the generated treefmt configuration has no embedmd formatter at all" >&2
          status=1
        elif ! covers embedmd includes; then
          echo "the embedmd formatter no longer covers README.md" >&2
          patterns embedmd includes >&2
          status=1
        fi

        # `deno fmt` respells the marker it carries, so the file stays out of
        # it. `deno` is off on the one platform its package does not build for,
        # and a formatter that is not configured rewrites nothing.
        if [ -n "$(formatter deno)" ] && ! covers deno excludes; then
          echo "README.md is no longer excluded from deno, which rewrites its marker" >&2
          patterns deno excludes >&2
          status=1
        fi

        # The command-output side, in whichever state it is: a file carrying no
        # such block is not to be handed to `mdsh`, and one carrying a block has
        # to be.
        if grep -qF '<!-- BEGIN mdsh -->' "$readme"; then
          if ! covers mdsh includes; then
            echo "README.md carries a command-output block that mdsh does not refresh" >&2
            patterns mdsh includes >&2
            status=1
          fi
        elif covers mdsh includes && ! covers mdsh excludes; then
          echo "mdsh is pointed at README.md, which carries no command-output block" >&2
          patterns mdsh includes >&2
          status=1
        fi

        if [ "$status" -ne 0 ]; then
          exit 1
        fi

        touch "$out"
      '';

  # Nothing else in the repository points at a heading of `README.md`. Every
  # source that could — its Markdown, its Nix, its pipelines, its shell scripts,
  # its `justfile` — is scanned, rather than the handful of files that happen to
  # name the file today.
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
        # `#` is spelled as a one-character bracket expression so that this
        # file, which is one of the files scanned, does not match itself.
        references="$(grep -rn 'README\.md[#]' "$repositoryText" || true)"

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
