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
