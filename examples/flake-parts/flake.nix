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
      conan-flake.url = "git+https://codeberg.org/tarcisio/conan-flake";
      infuse = {
        url = "git+https://codeberg.org/amjoseph/infuse.nix?rev=e837ece1b9de6ebcb7abd261f54a09bad3a2f820";
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

        perSystem = { self', pkgs, config, ... }: {
          # A suitable Conan profile:
          conan = {
            buildType = "Release";
            compilerCppStd = "23";

            platformToolRequires = {
              cmake = pkgs.cmake.version;
            };

            devShell = {
              tools = { inherit (pkgs) cmake; };
            };
          };

          devShells.default = pkgs.mkShell {
            inputsFrom = [
              # conan-flake exposes a `configuration` devShell by default that
              # can be used directly, or passed in the `inputsFrom` option as a
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
