alias ns := nix-shell

devenv-root-file := `pwd` + "/.devenv/root"

override-conan-flake := "--override-input conan-flake ."

override-devenv-root := "--override-input devenv-root \"file+file://" + devenv-root-file + "\""

default:
    @just --list

[no-cd]
_echo what message:
    @echo "{{ MAGENTA }}{{ what }}{{ NORMAL }}: {{ GREEN }}{{ message }}{{ NORMAL }}"

# Show conan-flake dev outputs
[group('dev')]
show: (_echo "Current dir" "`pwd`")
    nix flake show ./dev {{ override-conan-flake }} --show-trace

# Enter dev environment nix repl prompt
[group('dev')]
repl:
    nix repl ./dev {{ override-conan-flake }} --show-trace

# Enter nix-shell with Conan `configuration` package
[group('nix-shell')]
nix-shell:
    cd nix/modules && nix-shell . --attr conan.config.outputs.packages.configuration --show-trace --extra-experimental-features verified-fetches
