alias ns := nix-shell

devenv-root-file := `pwd` + "/.devenv/root"

override-conan-flake := "--override-input conan-flake ."

override-devenv-root := "--override-input devenv-root \"file+file://" + devenv-root-file + "\""

vira := "nix --show-trace --accept-flake-config run github:juspay/vira"

default:
    @just --list

[no-cd]
_echo what message:
    @echo "{{ MAGENTA }}{{ what }}{{ NORMAL }}: {{ GREEN }}{{ message }}{{ NORMAL }}"

# Show `conan-flake` dev outputs
[group('dev')]
show: (_echo "Current dir" "`pwd`")
    nix flake show ./dev {{ override-conan-flake }} --show-trace

# Enter dev nix interactive environment
[group('dev')]
repl:
    nix repl ./dev {{ override-conan-flake }} --show-trace

# Enter `nix-shell` with `conan-flake`'s `configuration` package
[group('nix-shell')]
nix-shell:
    cd nix/modules && nix-shell . --attr conan.config.outputs.packages.configuration \
        --extra-experimental-features verified-fetches \
        --show-trace

# Run all checks locally using `vira`
[group('vira')]
check:
    {{ vira }} -- ci -b

set positional-arguments

# Run `vira` with any generic arguments
[group('vira')]
vira *PARAMS:
    @if [ $# -eq 0 ]; then \
        {{ vira }}; \
    else \
        {{ vira }} -- "$@"; \
    fi
