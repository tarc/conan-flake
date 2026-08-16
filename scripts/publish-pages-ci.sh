#!/usr/bin/env bash
#
# What `.woodpecker/pages.yml` runs. Everything credential-shaped lives here:
# it turns the Woodpecker secret into an ordinary git remote and then hands over
# to `scripts/publish-pages.sh`, which is the same code path `just docs-publish`
# runs locally.
#
# publishing.CI.1
set -euo pipefail

# Nothing is published while the push credential is missing, and that is not an
# error: the pipeline has to be mergeable before anyone registers a credential.
# `.woodpecker/pages.yml` runs this file from a step that names no secret while
# none exists — Woodpecker resolves secrets while compiling a workflow and fails
# the whole pipeline when the named secret is absent, so it cannot simply leave
# the variable unset — and from the publishing step once one does. Either way
# the decision to publish or not is made right here, by the same code path
# `just docs-publish` runs locally.
#
# publishing.CI.2
token="${CODEBERG_TOKEN:-}"
if [ -z "$token" ]; then
  echo "CODEBERG_TOKEN is empty: no push credential is registered for this repository."
  echo "Nothing was published. See the contributing chapter of the documentation"
  echo "site for the one-time steps that switch publication on."
  exit 0
fi

repository_root="$(git rev-parse --show-toplevel)"
cd "$repository_root"

# The commit is made by the pipeline, which has no git identity of its own.
# Exported rather than written to the repository configuration, so that nothing
# of this survives in the checkout.
export GIT_AUTHOR_NAME="${PAGES_GIT_NAME:-conan-flake CI}"
export GIT_AUTHOR_EMAIL="${PAGES_GIT_EMAIL:-ci@conan-flake.invalid}"
export GIT_COMMITTER_NAME="$GIT_AUTHOR_NAME"
export GIT_COMMITTER_EMAIL="$GIT_AUTHOR_EMAIL"

host="${PAGES_HOST:-codeberg.org}"
repository="${PAGES_REPOSITORY:-tarcisio/conan-flake}"
user="${PAGES_USER:-tarcisio}"
remote="pages-publish"

# The token is interpolated into the remote URL here and never appears in a
# command Woodpecker echoes: the pipeline only ever runs this file by name.
git remote remove "$remote" >/dev/null 2>&1 || true
git remote add "$remote" "https://${user}:${token}@${host}/${repository}.git"

remove_remote() {
  git remote remove "$remote" >/dev/null 2>&1 || true
}
trap remove_remote EXIT

PAGES_REMOTE="$remote" ./scripts/publish-pages.sh
