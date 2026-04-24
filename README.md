# conan-flake - Nix module for Conan configuration

The standard way to support C/C++ packages using [Nix](https://nixos.org/) is to integrate their build system

and expose a specialized `stdenv` derivation capable of supporting navigating &mdash; at least &mdash; its generate, configure and build spheres. It works with plain Nix (no flakes), Nix flakes, [`flake-parts`](https://flake.parts/), or as a [`devenv`](https://devenv.sh/) module.


## Getting started

The example in this session makes use of the [flake-parts](https://flake.parts/) integration &mdash; for other approaches see [below](#integrations).

```nix
# file: flake.nix
{
  inputs = {
    ...
    flake-parts.url = "github:hercules-ci/flake-parts";
    haskell-flake.url = "github:srid/haskell-flake";
  };

  outputs = inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux", ... ];
      imports = [
        ...
        inputs.haskell-flake.flakeModule
      ];
      perSystem = { self', system, lib, config, pkgs, ... }: {
        haskellProjects.default = {
          # basePackages = pkgs.haskellPackages;

          # Packages to add on top of `basePackages`, e.g. from Hackage
          packages = {
            aeson.source = "1.5.0.0"; # Hackage version
          };

          # my-haskell-package development shell configuration
          devShell = {
            hlsCheck.enable = false;
          };

          # What should haskell-flake add to flake outputs?
          autoWire = [ "packages" "apps" "checks" ]; # Wire all but the devShell
        };

        devShells.default = pkgs.mkShell {
          name = "my-haskell-package custom development shell";
          inputsFrom = [
            ...
            config.haskellProjects.default.outputs.devShell
          ];
          nativeBuildInputs = with pkgs; [
            # other development tools.
          ];
        };
      };
    };
}
```


## Integrations

Integrating with [`devenv`](https://devenv.sh/).


## References

This project is heavily based on [`haskell-flake`](https://github.com/srid/haskell-flake), from where it takes its overall structure.

It's also influenced by the following projects in a number of ways:

- [`devenv`](https://devenv.sh/) ([GitHub](https://github.com/cachix/devenv)):
  - The way it handles the Apple SDK in the developer environment on macOS &mdash; see [devshell.nix](nix/modules/configuration/devshell.nix);
- [`treefmt-nix`](https://github.com/numtide/treefmt-nix):
  - Integration with the bare Nix module system &mdash; see [default.nix](nix/modules/default.nix).
