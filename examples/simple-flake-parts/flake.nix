# file: examples/simple-flake-parts/flake.nix
{
  inputs = {
    nixpkgs.url = "github:cachix/devenv-nixpkgs/rolling";
    flake-parts.url = "github:hercules-ci/flake-parts";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    conan-flake.url = "git+https://codeberg.org/tarcisio/conan-flake";
    infuse = {
      url = "git+https://codeberg.org/amjoseph/infuse.nix?rev=364ea18b5611b5fd6a6acd7151411b430a70e194";
      flake = false;
    };
  };

  outputs = inputs@{ self, nixpkgs, flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = nixpkgs.lib.systems.flakeExposed;
      imports = [
        # `flake-parts` module import declaration:
        inputs.conan-flake.flakeModule
      ];
      perSystem = { self', pkgs, config, ... }: {
        conan = {
        };
        devShells.default = pkgs.mkShell {
          inputsFrom = [
            # The preferred way to interface with the conan-flake module in a
            # devShell:
            config.conan.outputs.devShell
          ];
        };
      };
    }; # outputs
}
