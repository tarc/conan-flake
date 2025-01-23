flags := "--show-trace --accept-flake-config"
override := "--override-input conan-flake ../.."

default:
    @just --list

# Build example-library
[group('examples')]
ex-lib:
    cd ./examples/library && nix build . --print-build-logs {{ flags }} {{ override }}

# Build example-app
[group('examples')]
ex-app:
    cd ./examples/app && nix flake show . {{ flags }} {{ override }}

# Develop example-app
[group('examples')]
ex-app-dev:
    cd ./examples/app && nix develop . {{ flags }} {{ override }}

# Lock cfp and cfp/emanote
[group('docs')]
[group('inputs')]
lock-cfp:
    cd ./doc && nix flake lock \
        --override-input  cfp "github:tarc/community.flake.parts/conan-flake" \
        --override-input "cfp/emanote" "github:tarc/emanote/dark-mode-rebased"

# Lock `flake-parts` site
[group('docs')]
[group('inputs')]
lock-flake-parts-website:
    cd ./doc && nix flake lock \
        --override-input flake-parts-website "github:tarc/flake.parts-website/conan-flake"

# Update cfp and cfp/emanote
[group('docs')]
[group('inputs')]
update-cfp:
    cd ./doc && nix flake update cfp "cfp/emanote"

# Update `flake-parts` site
[group('docs')]
[group('inputs')]
update-flake-parts-website:
    cd ./doc && nix flake update flake-parts-website

# Open `conan-flake` docs live preview
[group('docs')]
docs:
    cd ./doc && nix run

# Open `flake-parts` docs, previewing local `conan-flake` version
[group('docs')]
docs-flake-parts:
    cd ./doc && nix run .#flake-parts

# Run the checks locally using `nixci`
check:
    om ci

# Auto-format the project tree
fmt:
    treefmt
