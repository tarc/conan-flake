#!/usr/bin/env bash
#
# Build the documentation site and update the `pages` branch of this checkout
# from that build. Codeberg Pages serves the content of that branch at
# https://tarcisio.codeberg.page/conan-flake/ once the webhook described in the
# contributing chapter of the site is registered.
#
# This is the one implementation of publishing: the `just docs-publish` recipe
# and `.woodpecker/pages.yml` (through `scripts/publish-pages-ci.sh`) both run
# this file, so local and CI publishing cannot drift.
#
# publishing.PUBLISH.1
#
# It touches no credential of its own: the push goes through an ordinary git
# remote of the checkout, so locally it uses whatever already lets the
# contributor push to this repository, and in CI it uses the remote the CI
# wrapper prepared.
#
# publishing.PUBLISH.2
#
# Knobs, all optional and all meant for the checks and for the CI wrapper
# rather than for a contributor:
#
#   PAGES_BRANCH         branch to publish to (default `pages`)
#   PAGES_REMOTE         remote to push to (default `origin`)
#   PAGES_PUSH           `0` to update the branch without pushing it
#   PAGES_SITE           a pre-built site to publish instead of building one
#   PAGES_BUILD_COMMAND  the command printing the built site's path
set -euo pipefail

branch="${PAGES_BRANCH:-pages}"
remote="${PAGES_REMOTE:-origin}"
push="${PAGES_PUSH:-1}"

# `just docs` builds the very same derivation, with the very same flags.
build_command=(
  nix build ./dev#docs
  --override-input conan-flake .
  --show-trace
  --no-pure-eval
  --option allow-import-from-derivation true
  --no-link
  --print-out-paths
)
if [ -n "${PAGES_BUILD_COMMAND:-}" ]; then
  read -r -a build_command <<<"$PAGES_BUILD_COMMAND"
fi

repository_root="$(git rev-parse --show-toplevel)"
cd "$repository_root"

original_branch="$(git rev-parse --abbrev-ref HEAD)"

# The build comes first, and nothing below runs unless it produced a site: a
# failed build has to leave the `pages` branch and this working tree exactly as
# they were.
#
# publishing.PUBLISH.3
site="${PAGES_SITE:-}"
if [ -n "$site" ]; then
  echo "Publishing the pre-built site at $site"
else
  echo "Building the documentation site ..."
  if ! site="$("${build_command[@]}")"; then
    echo "the documentation site failed to build; nothing was published" >&2
    echo "the $branch branch and the working tree were left untouched" >&2
    exit 1
  fi
fi

if [ -z "$site" ] || [ ! -s "$site/index.html" ]; then
  echo "the build produced no site with an entry page at its root: ${site:-<nothing>}/index.html" >&2
  echo "the $branch branch and the working tree were left untouched" >&2
  exit 1
fi

# The `pages` branch is updated through a worktree of its own, in a temporary
# directory outside this checkout. Nothing else keeps the branch that was
# checked out checked out, and the working tree unmodified, while the site is
# committed.
#
# publishing.PUBLISH.3
# publishing.PUBLISH.4
scratch="$(mktemp -d "${TMPDIR:-/tmp}/conan-flake-pages.XXXXXXXX")"
worktree="$scratch/$branch"

cleanup() {
  if [ -d "$worktree" ]; then
    git worktree remove --force "$worktree" >/dev/null 2>&1 || true
  fi
  rm -rf "$scratch"
  git worktree prune
}
trap cleanup EXIT

if [ "$push" = 1 ] && git ls-remote --exit-code --heads "$remote" "$branch" >/dev/null 2>&1; then
  # Continue the published history rather than diverging from it.
  git fetch --quiet "$remote" "$branch"
  git worktree add --quiet -B "$branch" "$worktree" FETCH_HEAD
elif git show-ref --verify --quiet "refs/heads/$branch"; then
  git worktree add --quiet "$worktree" "$branch"
else
  # First publication: the branch is created as an orphan, so it carries no
  # commit of the source history and its own history starts at a root commit.
  #
  # publishing.BRANCH.3
  if ! git worktree add --quiet --orphan -b "$branch" "$worktree" 2>/dev/null; then
    # `git worktree add --orphan` needs git >= 2.42.
    git worktree add --quiet --detach "$worktree" HEAD
    git -C "$worktree" switch --quiet --orphan "$branch"
  fi
fi

# Everything the branch carried is dropped before the new build is copied in,
# so that a page removed from the site stops being served instead of surviving
# on the branch. `git add --all` below stages those deletions.
#
# publishing.BRANCH.2
find "$worktree" -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +

# The site is copied out of the Nix store dereferencing symbolic links and
# without the store's permissions: a store path is read-only and may hold links
# pointing back into the store, neither of which belongs in a checkout of a
# branch. The entry page of the site lands at the root of the worktree, which
# is where Codeberg Pages serves the site's entry page from.
#
# publishing.BRANCH.1
# publishing.ARTIFACT.1
# publishing.ARTIFACT.2
cp -RL --no-preserve=mode,ownership "$site/." "$worktree/"
chmod -R u+rwX "$worktree"

source_commit="$(git rev-parse --short HEAD)"

# `--force` because an ignore rule of this checkout (`.git/info/exclude`, or the
# contributor's global one) must not decide what the published site contains:
# the branch carries the derivation output, whole.
#
# publishing.ARTIFACT.1
git -C "$worktree" add --all --force

if git -C "$worktree" rev-parse --verify --quiet HEAD >/dev/null &&
  git -C "$worktree" diff --cached --quiet; then
  echo "The built site is identical to $branch; nothing to commit."
else
  git -C "$worktree" commit --quiet \
    --message "Publish the documentation site built from $source_commit"
  echo "Committed the site to $branch ($(git -C "$worktree" rev-parse --short HEAD))."
fi

if [ "$push" = 1 ]; then
  git -C "$worktree" push "$remote" "HEAD:refs/heads/$branch"
  echo "Pushed $branch to $remote."
else
  echo "PAGES_PUSH=0: $branch was updated locally and not pushed."
fi

echo "Still on $original_branch; the working tree was not touched."
