# file: examples/flake-parts/flake.nix
{
  # { inputs
  # file: examples/flake-parts/flake.nix
  #  {
    inputs = {
      nixpkgs.url = "github:cachix/devenv-nixpkgs/rolling";
      flake-parts.url = "github:hercules-ci/flake-parts";
      treefmt-nix.url = "github:numtide/treefmt-nix";

      # Add these two:
      conan-flake.url = "git+https://codeberg.org/tarcisio/conan-flake?rev=64881ab5c49df503812fc544ffe494ac76199151";
      infuse = {
        url = "git+https://codeberg.org/amjoseph/infuse.nix?rev=364ea18b5611b5fd6a6acd7151411b430a70e194";
        flake = false;
      };
    };
    # ...
  #  }
  # inputs }

  # { outputs
  # file: examples/flake-parts/flake.nix
  #  {
    # ...
    outputs = inputs@{ self, nixpkgs, flake-parts, ... }:
      flake-parts.lib.mkFlake { inherit inputs; } {
        systems = nixpkgs.lib.systems.flakeExposed;

        imports = [
          inputs.conan-flake.flakeModule # Import this module
          inputs.treefmt-nix.flakeModule
        ];

        perSystem = { pkgs, config, ... }: {

          # A suitable Conan profile:
          conan = {
            profiles.default = {
              settings.compiler."compiler.cppstd" = "23";
              settings._.build_type = "Release";
            };
          };

          devShells.default = pkgs.mkShell {
            inputsFrom = [
              # conan-flake computes a devShell that can be used directly or
              # appended to the `inputsFrom` option of another devShell as a
              # means to compose with other devShell modules:
              config.conan.outputs.devShell
              config.treefmt.build.devShell
            ];
            packages = [ pkgs.just ];
          }; # devShells

          treefmt.config = {
            projectRoot = self;
            projectRootFile = "README.md";
            programs = {
              cmake-format.enable = true;
            };
          };
        };
      };
  #  }
  # outputs }
}
