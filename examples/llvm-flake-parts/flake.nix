# file: examples/llvm-flake-parts/flake.nix
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
  # { outputs
  # file: examples/llvm-flake-parts/flake.nix
  #  {
    outputs = inputs@{ nixpkgs, flake-parts, ... }:
      flake-parts.lib.mkFlake { inherit inputs; } {
        systems = nixpkgs.lib.systems.flakeExposed;
        imports = [
          inputs.conan-flake.flakeModule
        ];
        perSystem = { pkgs, config, ... }:
        {
          conan = {
            profiles = {
              settings.compiler = {
                "compiler.cppstd" = "23";
              };
              settings._.build_type = "Release";
            };

            stdenv = pkgs.overrideCC
              (
                pkgs.llvmPackages.libcxxStdenv.override {
                  targetPlatform.useLLVM = true;
                  targetPlatform.linker = "lld";
                }
              )
              pkgs.llvmPackages.clangUseLLVM;
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
