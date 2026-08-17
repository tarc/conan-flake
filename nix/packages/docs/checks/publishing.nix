# Assertions over publishing the built site to Codeberg Pages, one derivation
# per ACID of the `publishing` feature: the branch the site is served from, the
# script that updates it, the pipeline that runs that script, and the content
# that ends up published. `../checks.nix` merges these with the site ones.
#
# site.BUILD.3
{
  check,
  chapterCheck,
  git,
  site,
  bookToml,
  publishedUrl,
  yq-go,
  ...
}:
let
  # The publishing side: the one script `just docs-publish` and
  # `.woodpecker/pages.yml` both run, the wrapper the pipeline runs it through,
  # and the two files that call them. The checks below read these rather than
  # restating what they say.
  publishScript = builtins.path {
    path = ../../../../scripts/publish-pages.sh;
    name = "conan-flake-publish-pages.sh";
  };

  publishCiScript = builtins.path {
    path = ../../../../scripts/publish-pages-ci.sh;
    name = "conan-flake-publish-pages-ci.sh";
  };

  justfile = builtins.path {
    path = ../../../../justfile;
    name = "conan-flake-justfile";
  };

  pagesPipeline = builtins.path {
    path = ../../../../.woodpecker/pages.yml;
    name = "conan-flake-woodpecker-pages.yml";
  };

  # The address the site is served from is `publishedUrl`, taken from
  # `common.nix` above: the checks below compare it against `book.toml` and
  # against what the documentation tells a reader, rather than trusting it.
  #
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

  # The environment variable the publishing wrapper takes its credential from,
  # read out of the wrapper itself: the checks below are about a credential
  # arriving where that script looks for it, and a name restated here would go on
  # matching after the script stopped reading it. Needs `publishCiScript` in the
  # environment.
  tokenVariable = ''
    token_variable="$(
      sed -n 's/^token="''${\([A-Za-z_][A-Za-z0-9_]*\):-}".*/\1/p' "$publishCiScript"
    )"

    if [ -z "$token_variable" ]; then
      echo "cannot tell which variable the publishing wrapper reads the credential from" >&2
      exit 1
    fi
  '';

  # What the two checks about the pipeline share: Woodpecker's trigger
  # conditions, read out of the parsed workflow rather than out of its text, and
  # the two questions the requirements ask of a step. A check using this needs
  # `pagesPipeline` and `publishCiScript` in its environment and `yq-go` on its
  # path, and starts its own logic after it.
  #
  # The shape being read: a `when:` is a list of entries and a run matches when
  # *one* entry admits it — every field that entry constrains at once. Asserting
  # the fields one at a time across the whole list would accept a workflow whose
  # `push` and whose branch live in different entries and never co-occur. A field
  # is written either as a value, as a list of values, or as `include`/`exclude`
  # lists of patterns; a field an entry does not constrain admits everything, and
  # so does a `when:` that is not there at all — which is why a step without one
  # runs whenever its workflow does.
  whenHelpers = ''
    set -euo pipefail

    # Every `when:` as a list of entries, so that the three forms above are one
    # form from here on.
    workflow="$TMPDIR/workflow.yml"
    yq '(.when, .steps[].when) |= ([.] | flatten)' "$pagesPipeline" > "$workflow"

    if [ "$(yq '.steps | tag' "$workflow")" != '!!seq' ]; then
      echo "the pages pipeline does not list its steps as a sequence" >&2
      exit 1
    fi

    # A Woodpecker filter pattern as an extended regular expression: `**` crosses
    # directory separators and stands for no directory at all as well, `*` and
    # `?` stay inside one segment, and everything else is literal.
    pattern_regex() {
      printf '%s' "$1" |
        sed -e 's@\\@\\\\@g' \
          -e 's@[]$.^*+?(){}|[]@\\&@g' \
          -e 's@\\[*]\\[*]/@(.*/)?@g' \
          -e 's@\\[*]\\[*]@.*@g' \
          -e 's@\\[*]@[^/]*@g' \
          -e 's@\\[?]@[^/]@g'
    }

    matches() {
      local regex
      regex="$(pattern_regex "$1")"
      [[ "$2" =~ ^$regex$ ]]
    }

    # The patterns the given field of the given `when:` entry admits, and the
    # ones it rules out, one per line: a field given as a map carries them under
    # `include`/`exclude`, and one given as a value or a list is that list.
    include_patterns() {
      yq "[$1.$2 | select(tag == \"!!map\") | .include // []] | flatten | .[]" "$workflow"
      yq "[$1.$2 | select(tag != \"!!map\") | select(. != null)] | flatten | .[]" "$workflow"
    }

    exclude_patterns() {
      yq "[$1.$2 | select(tag == \"!!map\") | .exclude // []] | flatten | .[]" "$workflow"
    }

    # Does that entry admit that value for that field? An `exclude` cancels an
    # `include` that matches, which is how a filter can be written to select
    # everything under a directory and then drop part of it again.
    admits() {
      local include exclude pattern admitted=1

      include="$(include_patterns "$1" "$2")"
      exclude="$(exclude_patterns "$1" "$2")"

      if [ -z "$include" ]; then
        admitted=0
      else
        while IFS= read -r pattern; do
          if [ -n "$pattern" ] && matches "$pattern" "$3"; then
            admitted=0
          fi
        done <<< "$include"
      fi

      if [ "$admitted" -ne 0 ]; then
        return 1
      fi

      while IFS= read -r pattern; do
        if [ -n "$pattern" ] && matches "$pattern" "$3"; then
          return 1
        fi
      done <<< "$exclude"

      return 0
    }

    # Is the part of the workflow the given `when:` belongs to reached by an
    # event on a branch changing a file — one entry admitting all three? An empty
    # path is a run whose paths Woodpecker does not evaluate at all: the path
    # conditions are read for a push and a pull request only (`Constraint.Match`
    # in `pipeline/frontend/yaml/constraint/constraint.go`).
    reached() {
      local entry
      while IFS= read -r entry; do
        if admits "$1[$entry]" event "$2" &&
          admits "$1[$entry]" branch "$3" &&
          { [ -z "$4" ] || admits "$1[$entry]" path "$4"; }; then
          return 0
        fi
      done < <(yq "$1 | keys | .[]" "$workflow")

      return 1
    }

    # Does the step at that index publish at all, and does it publish with a
    # credential? A secret bound to any name but the one the wrapper reads leaves
    # it reporting that nothing was published, however green the run goes.
    runs_wrapper() {
      local commands
      commands="$(yq ".steps[$1].commands // [] | .[]" "$workflow")"
      [[ "$commands" == *publish-pages-ci.sh* ]]
    }

  ''
  + tokenVariable
  + ''

    publishes() {
      local bound
      bound="$(yq ".steps[$1].environment.\"$token_variable\".from_secret // \"\"" "$workflow")"
      [ "$bound" = "$2" ]
    }
  '';
in
{
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
            echo "''${caller##*/} does not run the publish script" >&2
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

    # And it does push: everything above runs with the push suppressed, which is
    # not the path a publication takes. A bare repository stands in for the
    # forge — nothing else is needed to exercise it, and nothing hands the
    # script a credential to reach it with.
    remote="$TMPDIR/remote.git"
    git init --bare --quiet "$remote"
    git remote add origin "$remote"
    git branch --quiet --delete --force pages

    push_publish() {
      PAGES_SITE="$1" bash "$publishScript"
    }

    # First publication: the remote carries no such branch yet, so the branch is
    # created here and pushed there.
    cp -RL --no-preserve=mode,ownership "$site" "$TMPDIR/stale-site"
    chmod -R u+rwX "$TMPDIR/stale-site"
    echo 'a page that goes away' > "$TMPDIR/stale-site/gone.html"
    push_publish "$TMPDIR/stale-site" > /dev/null

    first="$(git -C "$remote" rev-parse --verify --quiet refs/heads/pages || true)"
    if [ -z "$first" ]; then
      echo "publishing pushed no pages branch to the remote" >&2
      exit 1
    fi

    # A checkout that has never seen the branch: the published history is
    # fetched and continued, rather than replaced by a second history of its
    # own, and the removals of the new build travel to the remote too.
    git branch --quiet --delete --force pages
    push_publish "$site" > /dev/null

    second="$(git -C "$remote" rev-parse refs/heads/pages)"

    if [ "$second" = "$first" ]; then
      echo "republishing pushed nothing to the remote" >&2
      status=1
    elif ! git -C "$remote" merge-base --is-ancestor "$first" "$second"; then
      echo "republishing replaced the published history instead of continuing it" >&2
      status=1
    fi

    if [ "$(git -C "$remote" rev-list --max-parents=0 --count refs/heads/pages)" != 1 ]; then
      echo "the published history does not start at a single root commit" >&2
      status=1
    fi

    if [ -n "$(git -C "$remote" ls-tree --name-only refs/heads/pages -- gone.html)" ]; then
      echo "a page dropped from the site survived the push" >&2
      status=1
    fi

    if [ -z "$(git -C "$remote" ls-tree --name-only refs/heads/pages -- index.html)" ]; then
      echo "the pushed branch carries no entry page at its root" >&2
      status=1
    fi

    # A remote that cannot be reached at all is not a remote that carries no
    # such branch: publishing to it has to stop before it touches the branch,
    # rather than rewrite it in the belief that nothing was ever published and
    # find out only at the push. A site of its own, so that a run that got that
    # far would leave a commit behind.
    if PAGES_REMOTE="$TMPDIR/unreachable.git" PAGES_SITE="$TMPDIR/stale-site" bash "$publishScript" \
      > "$TMPDIR/unreachable.log" 2>&1; then
      echo "publishing succeeded against a remote it could never reach" >&2
      cat "$TMPDIR/unreachable.log" >&2
      status=1
    fi

    if [ "$(git rev-parse refs/heads/pages)" != "$second" ]; then
      echo "publishing to an unreachable remote moved the pages branch" >&2
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

  # Publishing on demand: a manual run of the pipeline publishes the site, which
  # is how it is republished without a commit. Read out of the parsed workflow
  # rather than grepped for, so that deleting the publishing step or re-gating it
  # on an event the activation checklist does not prescribe fails here: every
  # assertion below is about the step that does the publishing, not about the
  # file it lives in.
  #
  # publishing.CI.3
  "publishing.CI.3" =
    check "publishing.CI.3"
      {
        inherit pagesPipeline publishCiScript;
        nativeBuildInputs = [ yq-go ];
      }
      (
        whenHelpers
        + ''

          status=0

          # The trigger the activation checklist tells the maintainer to use, the
          # branch it tells them to use it on, and the secret it tells them to
          # register.
          trigger=manual
          default_branch=main
          secret=codeberg_token

          publishing_step=

          while IFS= read -r index; do
            if [ "$(yq ".steps[$index].name" "$workflow")" = pages ]; then
              publishing_step="$index"
            fi
          done < <(yq '.steps | keys | .[]' "$workflow")

          if [ -z "$publishing_step" ]; then
            echo "the pages pipeline has no step named pages to publish from" >&2
            yq '.steps[].name' "$workflow" >&2
            exit 1
          fi

          # A run started by hand reaches the publishing step: the workflow
          # admits it from the default branch, and so does the step. No path is
          # given, because Woodpecker evaluates none for such a run.
          if ! reached .when "$trigger" "$default_branch" ""; then
            echo "no trigger of the pages pipeline admits a $trigger run on $default_branch" >&2
            yq '.when' "$workflow" >&2
            status=1
          fi

          if ! reached ".steps[$publishing_step].when" "$trigger" "$default_branch" ""; then
            echo "the publishing step is not reached by a $trigger run on $default_branch" >&2
            yq ".steps[$publishing_step].when" "$workflow" >&2
            status=1
          fi

          # It publishes by running the wrapper, with the credential the
          # activation checklist tells the maintainer to register in the variable
          # the wrapper reads ...
          if ! runs_wrapper "$publishing_step"; then
            echo "the publishing step does not run the publishing wrapper" >&2
            status=1
          fi

          if ! publishes "$publishing_step" "$secret"; then
            echo "the publishing step does not hand the $secret secret to the wrapper" >&2
            echo "as $token_variable, so it would publish nothing" >&2
            yq ".steps[$publishing_step].environment" "$workflow" >&2
            status=1
          fi

          # ... and the wrapper publishes through the same script a contributor
          # runs.
          if ! grep -qF './scripts/publish-pages.sh' "$publishCiScript"; then
            echo "the pipeline wrapper does not run the publish script" >&2
            status=1
          fi

          if [ "$status" -ne 0 ]; then
            exit 1
          fi

          touch "$out"
        ''
      );

  # A push of a documentation change to the default branch publishes the site.
  # What makes that true is a chain of conditions spread over the workflow — the
  # trigger it runs on, the branch and the paths it filters those runs down to,
  # the trigger of the step that publishes, and the credential that step hands
  # the wrapper — so the whole chain is read out of the parsed workflow here,
  # about one and the same run rather than field by field. The last link is what
  # tells a push that publishes apart from a push that reports that nothing was
  # published: a step running the wrapper without the credential in the variable
  # the wrapper reads publishes nothing, however green it goes.
  #
  # publishing.CI.5
  "publishing.CI.5" =
    check "publishing.CI.5"
      {
        inherit pagesPipeline publishCiScript;
        nativeBuildInputs = [ yq-go ];
      }
      (
        whenHelpers
        + ''

          status=0

          default_branch=main
          secret=codeberg_token

          # A file under the site's sources standing for the whole list here;
          # `site.SOURCES.2` is what covers the list itself.
          documentation_source=docs/src/index.md

          # The run this requirement is about reaches the workflow: one trigger
          # admitting a push, on the default branch, of a change to the
          # documentation sources — all three at once, since a trigger admitting
          # each of them in a different entry admits no such run.
          if ! reached .when push "$default_branch" "$documentation_source"; then
            echo "no trigger of the pages pipeline admits a push to $default_branch" >&2
            echo "changing $documentation_source" >&2
            yq '.when' "$workflow" >&2
            status=1
          fi

          # ... and inside that run, the wrapper is reached with the credential
          # it publishes with, and nowhere without it.
          publishing_step=

          while IFS= read -r index; do
            if ! reached ".steps[$index].when" push "$default_branch" "$documentation_source"; then
              continue
            fi

            if ! runs_wrapper "$index"; then
              continue
            fi

            if publishes "$index" "$secret"; then
              publishing_step="$(yq ".steps[$index].name" "$workflow")"
            else
              echo "such a push reaches the step $(yq ".steps[$index].name" "$workflow"), which runs the" >&2
              echo "publishing wrapper without the $secret secret in $token_variable:" >&2
              echo "it would report that nothing was published" >&2
              status=1
            fi
          done < <(yq '.steps | keys | .[]' "$workflow")

          if [ -z "$publishing_step" ]; then
            echo "such a push reaches no step that publishes with the $secret secret" >&2
            echo "in $token_variable" >&2
            yq '.steps[].name' "$workflow" >&2
            status=1
          fi

          if [ "$status" -ne 0 ]; then
            exit 1
          fi

          touch "$out"
        ''
      );

  # Nothing is published while no push credential reaches the wrapper the
  # pipeline publishes through, and that is not a failure: the guard is in the
  # wrapper, on the code path `just docs-publish` takes too, so whether to
  # publish is decided in one place. Observed by running the wrapper, which is
  # all this requirement is about — what a run of the pipeline hands it is
  # `publishing.CI.3`'s and `publishing.CI.5`'s to say — and with the variable it
  # reads taken from the wrapper rather than restated here.
  #
  # publishing.CI.6
  "publishing.CI.6" =
    check "publishing.CI.6"
      {
        inherit publishCiScript;
        nativeBuildInputs = [ git ];
      }
      (
        ''
          set -euo pipefail

        ''
        + tokenVariable
        + ''

          export HOME="$TMPDIR"
          export GIT_AUTHOR_NAME="conan-flake checks"
          export GIT_AUTHOR_EMAIL="checks@conan-flake.invalid"
          export GIT_COMMITTER_NAME="$GIT_AUTHOR_NAME"
          export GIT_COMMITTER_EMAIL="$GIT_AUTHOR_EMAIL"

          git init --quiet --initial-branch main "$TMPDIR/checkout"
          cd "$TMPDIR/checkout"
          git commit --quiet --allow-empty --message 'the source history'

          status=0

          # Nothing in the environment of a run without a credential tells the
          # two cases apart: a secret Woodpecker did not offer leaves the
          # variable unset, and one whose value never arrived leaves it empty.
          for attempt in unset empty; do
            case "$attempt" in
              unset) credential=(env -u "$token_variable") ;;
              empty) credential=(env "$token_variable=") ;;
            esac

            if ! "''${credential[@]}" bash "$publishCiScript" > "$TMPDIR/$attempt.log" 2>&1; then
              echo "the publishing wrapper failed while the credential is $attempt" >&2
              cat "$TMPDIR/$attempt.log" >&2
              status=1
              continue
            fi

            if ! grep -qF 'Nothing was published' "$TMPDIR/$attempt.log"; then
              echo "the publishing wrapper did not say that nothing was published ($attempt)" >&2
              cat "$TMPDIR/$attempt.log" >&2
              status=1
            fi

            if git rev-parse --verify --quiet refs/heads/pages > /dev/null; then
              echo "the publishing wrapper published although the credential is $attempt" >&2
              status=1
            fi

            if [ -n "$(git remote)" ]; then
              echo "the publishing wrapper left a remote behind ($attempt)" >&2
              status=1
            fi
          done

          if [ "$status" -ne 0 ]; then
            exit 1
          fi

          touch "$out"
        ''
      );

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

  # The events the credential has to be offered at. Woodpecker looks a secret up
  # while compiling the workflow and refuses it to a run whose event the secret
  # does not list, so a checklist that stops at the secret's name leaves the
  # maintainer with a run that fails before it starts.
  #
  # publishing.SETUP.1-1
  "publishing.SETUP.1-1" = chapterCheck "publishing.SETUP.1-1" [
    {
      page = "contributing.html";
      phrases = [
        # Woodpecker's own label for the event list of a secret
        # (`secrets.events` in `web/src/assets/locales/en.json`), so that the
        # checklist names what the maintainer is looking at.
        "Available at the following events"
        # The event the checklist's own publishing run uses, and the one the
        # last step of the checklist adds.
        "manual"
        "push"
        # The default list, so that "tick it" reads as a change rather than as a
        # confirmation.
        "deployment"
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
    # A site carrying a link into the Nix store, which is what publishing has to
    # cope with: the site's own build happens not to emit one today, and a
    # requirement about store links cannot be proven by a tree that has none.
    # Published verbatim, `linked.html` would point at a store path no visitor
    # has.
    cp -RL --no-preserve=mode,ownership "$site" "$TMPDIR/linked-site"
    chmod -R u+rwX "$TMPDIR/linked-site"
    ln -s "$site/index.html" "$TMPDIR/linked-site/linked.html"

    publish "$TMPDIR/linked-site" > /dev/null
    git worktree add --quiet "$TMPDIR/published" pages

    status=0

    # git records a symbolic link as mode 120000, and a regular file as 100644:
    # the store link was published as the page it pointed at.
    unexpected="$(git ls-tree -r pages | awk '$1 != "100644" && $1 != "100755"')"
    if [ -n "$unexpected" ]; then
      echo "the published branch carries entries that are not regular files:" >&2
      echo "$unexpected" >&2
      status=1
    fi

    published_link="$TMPDIR/published/linked.html"
    if [ ! -f "$published_link" ] || ! cmp -s "$published_link" "$site/index.html"; then
      echo "the link into the store was not published as the page it pointed at" >&2
      status=1
    fi

    # Nothing else in a checkout of the branch is a link either, whether it
    # points anywhere or not.
    while IFS= read -r link; do
      echo "symbolic link in the published tree: ''${link#"$TMPDIR/published"/}" >&2
      status=1
    done < <(find "$TMPDIR/published" -name .git -prune -o -type l -print)

    # ... and it is a plain, writable tree, not the read-only store path it was
    # copied from.
    while IFS= read -r path; do
      echo "not readable and writable by its owner: ''${path#"$TMPDIR/published"/}" >&2
      status=1
    done < <(
      find "$TMPDIR/published" -name .git -prune -o \
        \( ! -perm -u+r -o ! -perm -u+w \) -print
    )

    if [ "$status" -ne 0 ]; then
      exit 1
    fi

    touch "$out"
  '';
}
