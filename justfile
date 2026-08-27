# Point conan-flake at this checkout, exactly as `.woodpecker/checks.yml` and
# `vira.hs` do. Keep it relative: an absolute path works only on the machine it
# was written on, and `just` runs recipes from the directory holding this file,
# so `.` is always this repo.
override-conan-flake := "--override-input conan-flake ."

# `allow-import-from-derivation` is needed by `nix flake show`, which disables
# IFD, while devenv's nixpkgs is produced by one. `nix flake check` allows it
# already; passing it here keeps the three recipes evaluating identically.
dev-group-modifiers := "--show-trace --no-pure-eval --option allow-import-from-derivation true"

vira := "nix --show-trace --accept-flake-config run github:juspay/vira"

default:
    @just --list

[no-cd]
_echo what message:
    @echo "{{ MAGENTA }}{{ what }}{{ NORMAL }}: {{ GREEN }}{{ message }}{{ NORMAL }}"

set positional-arguments

# Show conan-flake dev outputs
[group('dev')]
show *PARAMS: (_echo "Current dir" "`pwd`")
    @if [ $# -eq 0 ]; then \
        nix flake show ./dev {{ override-conan-flake }} {{ dev-group-modifiers }}; \
    else \
        nix flake show "$@" {{ override-conan-flake }} {{ dev-group-modifiers }}; \
    fi

# Show conan-flake dev outputs
[group('dev')]
check *PARAMS: (_echo "Current dir" "`pwd`")
    @if [ $# -eq 0 ]; then \
        nix flake check ./dev {{ override-conan-flake }} {{ dev-group-modifiers }}; \
    else \
        nix flake check "$@" {{ override-conan-flake }} {{ dev-group-modifiers }}; \
    fi

# Enter dev nix interactive environment
[group('dev')]
repl:
    nix repl ./dev {{ override-conan-flake }} {{ dev-group-modifiers }}

# The documented commands for working on the site. `just docs` builds the same
# derivation CI builds; `just docs-serve` runs the Astro development server
# against the checkout instead, since it serves the sources it watches and
# reloads on every change, neither of which a store path allows. The server
# needs no installation step: the development shell places the site's
# dependencies at `docs/node_modules`.
#
# authoring.PREVIEW.1
# authoring.PREVIEW.2

# Build the documentation site (result symlinked as ./result)
[group('docs')]
docs:
    nix build ./dev#docs {{ override-conan-flake }} {{ dev-group-modifiers }}

# Build the documentation site and update the `pages` branch from that build.
# The script is the one `.woodpecker/pages.yml` runs too, so what a contributor
# publishes and what CI publishes cannot drift; it needs no credential beyond
# the one that already pushes to this repository.
#
# publishing.PUBLISH.1
# publishing.PUBLISH.2

# Publish the documentation site to the `pages` branch (Codeberg Pages)
[group('docs')]
docs-publish:
    ./scripts/publish-pages.sh

# Serve the documentation site locally, reloading on every source change
[group('docs')]
docs-serve *PARAMS:
    @if [ $# -eq 0 ]; then \
        pnpm -C docs dev; \
    else \
        pnpm -C docs dev "$@"; \
    fi

# Run all checks locally using `vira`
[group('vira')]
ci:
    {{ vira }} --no-pure-eval -- ci -b

# Run `vira` with any generic arguments
[group('vira')]
vira *PARAMS:
    @if [ $# -eq 0 ]; then \
        {{ vira }}; \
    else \
        {{ vira }} -- "$@"; \
    fi

# Search Conan packages
[group('Conan')]
search *PARAMS:
    @if [ $# -eq 0 ]; then \
        conan search "*"; \
    else \
        conan search "$@"; \
    fi
