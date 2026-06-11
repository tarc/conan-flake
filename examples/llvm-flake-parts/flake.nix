# file: examples/llvm-flake-parts/flake.nix
{
  inputs = {
    nixpkgs.url = "github:cachix/devenv-nixpkgs/rolling";
    flake-parts.url = "github:hercules-ci/flake-parts";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    conan-flake.url = "git+https://codeberg.org/tarcisio/conan-flake";
    infuse = {
      url = "git+https://codeberg.org/amjoseph/infuse.nix?rev=e837ece1b9de6ebcb7abd261f54a09bad3a2f820";
      flake = false;
    };
  };
  # { outputs
  # file: examples/llvm-flake-parts/flake.nix
  #  {
    outputs = inputs@{ self, nixpkgs, flake-parts, ... }:
      flake-parts.lib.mkFlake { inherit inputs; } {
        systems = nixpkgs.lib.systems.flakeExposed;
        imports = [
          inputs.conan-flake.flakeModule
        ];
        perSystem = { self', pkgs, config, ... }: {
          conan = {
            buildType = "Release";
            compilerCppStd = "23";

            stdenv = pkgs.overrideCC
              (
                pkgs.llvmPackages.libcxxStdenv.override {
                  targetPlatform.useLLVM = true;
                  targetPlatform.linker = "lld";
                }
              )
              pkgs.llvmPackages.clangUseLLVM;

            # By default: compiler.libcxx=libstdc++11, so undo it:
            compilerLibCxx = null;
          };

          devShells.default = pkgs.mkShell {
            inputsFrom = [
              config.conan.outputs.devShell
            ];
          };
        };
      };
  #  }
  # outputs }
}
