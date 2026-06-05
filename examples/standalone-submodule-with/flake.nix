# file: examples/standalone-submodule-with/flake.nix
{
  inputs = {
    nixpkgs.url = "github:cachix/devenv-nixpkgs/rolling";
    conan-flake.url = "git+https://codeberg.org/tarcisio/conan-flake";
  };
  outputs = { self, nixpkgs, conan-flake, ... }:
    let
      eachSystem = nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed;

      # { perSystem
      # file: examples/standalone-submodule-with/flake.nix
      #  {
        # ...
        perSystem = system:
          let
            pkgs = nixpkgs.legacyPackages.${system};
            lib = pkgs.lib;
            stdenv = pkgs.stdenv;
            conanSubmodule = conan-flake.lib.submoduleWith pkgs { configRoot = self; };
            conanModule = {
              options = {
                conan = lib.mkOption {
                  type = conanSubmodule;
                  description = "Conan configuration";
                  default = { };
                };
              };
            }; # conanModule
            conanModuleConfig = (lib.evalModules {
              modules = [
                {
                  imports = [ conanModule ];

                  conan = {
                    buildType = "Debug";
                    compilerCppStd = "14";

                    platformToolRequires = {
                      cmake = pkgs.cmake.version;
                    };

                    devShell = {
                      tools = { inherit (pkgs) cmake; };
                    };

                    remotes.local = {
                      url = "./repo";
                      local = true;
                      allowedPackages = [ "hello-world/0.0.1.cci.20260428" ];
                    };

                    offline = true;
                  };
                }
              ];
            }).config.conan; # conanModuleConfig
          in
          {
            devShells.default = conanModuleConfig.outputs.devShell;
            checks.test = pkgs.runCommandWith
              {
                name = "standalone-submodule-with-test-conan-create";
                inherit (conanModuleConfig) stdenv;
                derivationArgs = { inherit (conanModuleConfig.outputs.devShell) buildInputs nativeBuildInputs; };
              }
              ''
                (
                set -x
                ${conanModuleConfig.outputs.devShell.shellHook}
                conan create ${conanModuleConfig.info.configRoot} -tf="" --build=missing 2>&1 | grep "example/0.0.1"
                touch $out
                )
              '';
          };
          # ...
      #  }
      # perSystem }

      systemOutputs = eachSystem perSystem;
    in
    {
      devShells = nixpkgs.lib.mapAttrs (_: s: s.devShells) systemOutputs;
      checks = nixpkgs.lib.mapAttrs (_: s: s.checks) systemOutputs;
    };
}
