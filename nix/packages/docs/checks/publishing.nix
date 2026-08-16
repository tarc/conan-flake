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

  # The address the site is served from once the webhook of the activation
  # checklist is registered. Read from here by the checks below, and compared
  # against `book.toml` rather than trusted.
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

  # Once the credential is registered, the pipeline publishes when it is run on
  # demand. Read out of the parsed workflow rather than grepped for, so that
  # deleting the publishing step or re-gating it on an event the activation
  # checklist does not prescribe fails here: every assertion below is about the
  # step that does the publishing, not about the file it lives in.
  #
  # publishing.CI.3
  "publishing.CI.3" =
    check "publishing.CI.3"
      {
        inherit pagesPipeline publishCiScript;
        nativeBuildInputs = [ yq-go ];
      }
      ''
        set -euo pipefail

        status=0

        # The trigger the activation checklist tells the maintainer to use, and
        # the branch it tells them to use it on.
        trigger=manual
        default_branch=main

        # Every `event:`/`branch:` a `when:` constrains on, wherever it sits in
        # the given part of the workflow, one per line.
        constraint() {
          yq "[$1 | .. | select(tag == \"!!map\") | select(has(\"$2\")) | .$2] | flatten | .[]" \
            "$pagesPipeline"
        }

        publishing_step='.steps[] | select(.name == "pages")'

        if [ "$(yq "[$publishing_step] | length" "$pagesPipeline")" != 1 ]; then
          echo "the pages pipeline has no step named pages to publish from" >&2
          yq '[.steps[].name] | .[]' "$pagesPipeline" >&2
          exit 1
        fi

        # A run of the workflow reaches the publishing step: both the workflow
        # and the step admit the trigger, and neither is restricted to another
        # branch. Every assertion is scoped to the `when:` of the part it is
        # about — `.` would walk the whole document, and the step's own trigger
        # would then answer for the workflow's.
        if ! constraint .when event | grep -qxF "$trigger"; then
          echo "the pages pipeline does not run on a $trigger run" >&2
          constraint .when event >&2
          status=1
        fi

        if ! constraint "$publishing_step | .when" event | grep -qxF "$trigger"; then
          echo "the publishing step is not reached by a $trigger run" >&2
          constraint "$publishing_step | .when" event >&2
          status=1
        fi

        for part in .when "$publishing_step | .when"; do
          branches="$(constraint "$part" branch)"
          if [ -n "$branches" ] && ! printf '%s\n' "$branches" | grep -qxF "$default_branch"; then
            echo "the site would not be published from $default_branch: $branches" >&2
            status=1
          fi
        done

        # It publishes by running the wrapper, which reads the credential the
        # activation checklist tells the maintainer to register ...
        if ! yq "$publishing_step | .commands | .[]" "$pagesPipeline" |
          grep -qF 'publish-pages-ci.sh'; then
          echo "the publishing step does not run the publishing wrapper" >&2
          status=1
        fi

        if ! constraint "$publishing_step" from_secret | grep -qxF codeberg_token; then
          echo "the publishing step reads no codeberg_token secret" >&2
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
      '';

  # What is left after the manual run works: the one edit that turns publishing
  # on demand into publishing on every change, written down where the rest of
  # the one-time setup is. That the edit is enough is the other half — the
  # pipeline's own trigger already selects pushes of the documentation sources
  # to the default branch, so nothing but the step's own `when` stands between
  # a documentation change and a publication.
  #
  # publishing.CI.4
  "publishing.CI.4" =
    check "publishing.CI.4"
      {
        inherit pagesPipeline site;
        nativeBuildInputs = [ yq-go ];
      }
      ''
        set -euo pipefail

        status=0

        for phrase in \
          '.woodpecker/pages.yml' \
          '- event: [push, manual]' \
          'publication-status'; do
          if ! grep -qF -- "$phrase" "$site/contributing.html"; then
            echo "the setup steps do not state the edit: $phrase" >&2
            status=1
          fi
        done

        events="$(yq '[.when[].event] | flatten | .[]' "$pagesPipeline")"
        if ! printf '%s\n' "$events" | grep -qxF push; then
          echo "the pages pipeline does not run on a push, so the edit would not be enough" >&2
          status=1
        fi

        if ! yq '[.when[].branch] | flatten | .[]' "$pagesPipeline" | grep -qxF main; then
          echo "the pages pipeline does not run on the default branch" >&2
          status=1
        fi

        # The documentation sources it selects those pushes on. `docs/**` stands
        # for the whole of the site's sources here; `site.SOURCES.2` is what
        # covers the list.
        if ! yq '[.when[].path.include] | flatten | .[]' "$pagesPipeline" |
          grep -qxF 'docs/**'; then
          echo "the pages pipeline does not select pushes touching the documentation sources" >&2
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
  # and a push reaches a step that publishes nothing while the secret does not
  # exist — Woodpecker resolves secrets at compile time and fails the whole
  # workflow with `secret "codeberg_token" not found` otherwise, which is why
  # the publishing step is gated on `manual` and a step carrying no secret runs
  # the wrapper on a push.
  #
  # publishing.CI.2
  "publishing.CI.2" =
    check "publishing.CI.2"
      {
        inherit pagesPipeline publishCiScript;
        nativeBuildInputs = [
          git
          yq-go
        ];
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

        # The secret the pipeline expects, named only where a secret can be read
        # from.
        if ! grep -qF 'from_secret: codeberg_token' "$pagesPipeline"; then
          echo "the pipeline does not read the codeberg_token secret" >&2
          status=1
        fi

        # The `event:`s a named step's own `when:` constrains on, or the secrets
        # it names, one per line. A step that constrains on no event of its own
        # runs on every event the workflow itself runs on.
        step_field() {
          yq "[.steps[] | select(.name == \"$1\") | $2 | .. | select(tag == \"!!map\") | select(has(\"$3\")) | .$3] | flatten | .[]" \
            "$pagesPipeline"
        }

        # A push has to reach the workflow at all, or there is no run left to
        # report anything.
        if ! yq '[.when | .. | select(tag == "!!map") | select(has("event")) | .event] | flatten | .[]' \
          "$pagesPipeline" | grep -qxF push; then
          echo "the pipeline does not run on a push at all, so it reports nothing" >&2
          status=1
        fi

        # The pipeline is in one of the two shapes this requirement admits.
        # While no credential is registered, no step naming it can be reachable
        # by a push — Woodpecker fails the whole workflow at compile time over a
        # secret that does not exist — so a push has to reach a step that names
        # no secret and runs the wrapper, which reports that nothing was
        # published and exits 0. Once the credential is registered, the last
        # step of the activation checklist hands the push to the publishing step
        # itself, and no run is left whose credential is absent. Both shapes
        # pass here, so taking that step does not turn this check red.
        #
        # publishing.CI.4
        reporting_step=
        publishing_step_on_push=

        while IFS= read -r step; do
          events="$(step_field "$step" .when event)"
          if [ -n "$events" ] && ! printf '%s\n' "$events" | grep -qxF push; then
            continue
          fi

          if [ -n "$(step_field "$step" . from_secret)" ]; then
            publishing_step_on_push="$step"
          elif yq ".steps[] | select(.name == \"$step\") | .commands | .[]" "$pagesPipeline" |
            grep -qF 'publish-pages-ci.sh'; then
            reporting_step="$step"
          fi
        done < <(yq '.steps[].name' "$pagesPipeline")

        if [ -z "$reporting_step" ] && [ -z "$publishing_step_on_push" ]; then
          echo "a push reaches no step that reports that nothing was published," >&2
          echo "and none that publishes with a registered credential either" >&2
          yq '.steps[].name' "$pagesPipeline" >&2
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
