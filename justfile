default:
    @just --list

[no-cd]
_echo what message:
    @echo "{{ MAGENTA }}{{ what }}{{ NORMAL }}: {{ GREEN }}{{ message }}{{ NORMAL }}"

# Show conan-flake dev outputs
[group('dev')]
show: (_echo "Current dir" "`pwd`")
    nix flake show ./dev --override-input conan-flake . --no-pure-eval --allow-import-from-derivation --show-trace

# Enter nix-shell with conan `configuration` package
[group('nix-shell')]
ns:
    cd nix/modules && nix-shell . --attr conan.config.outputs.packages.configuration --show-trace --extra-experimental-features verified-fetches
