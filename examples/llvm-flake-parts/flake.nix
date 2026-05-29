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
  # file: examples/llvm-flake-parts/flake.nix
  outputs = inputs@{ self, nixpkgs, flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = nixpkgs.lib.systems.flakeExposed;
      imports = [
        # `flake-parts` module import declaration:
        inputs.conan-flake.flakeModule
      ];
      perSystem = { self', pkgs, config, ... }: {
        conan = {
          # The `stdenv` module option:
          stdenv = pkgs.overrideCC
            (
              pkgs.llvmPackages.libcxxStdenv.override {
                targetPlatform.useLLVM = true;
              }
            )
            pkgs.llvmPackages.clangUseLLVM;
          # By default: compiler.libcxx=libstdc++11, so undo it:
          compilerLibCxx = null;
          # Section [platform_tool_requires]
          platformToolRequires = {
            cmake = pkgs.cmake.version;
          };
          # Further customize devShell options:
          devShell = {
            tools = {
              inherit (pkgs) cmake;
            };
          };
        };
        devShells.default = pkgs.mkShell {
          inputsFrom = [
            # The preferred way to interface with the conan-flake module in
            # devShell:
            config.devShells.configuration # == `config.conan.outputs.devShell`
          ];
        };
      };
    }; # outputs
}
