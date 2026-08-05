# file: examples/standalone-submodule-with/flake.nix
{
  inputs = {
    nixpkgs.url = "github:cachix/devenv-nixpkgs/rolling";
    conan-flake.url = "git+https://codeberg.org/tarcisio/conan-flake";
  };
  outputs =
    {
      self,
      nixpkgs,
      conan-flake,
      ...
    }:
    let
      eachSystem = nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed;

      # { perSystem
      # file: examples/standalone-submodule-with/flake.nix
      #  {
        # ...
        perSystem =
          system:
          let
            pkgs = nixpkgs.legacyPackages.${system};
            lib = pkgs.lib;
            conanSubmodule = conan-flake.lib.submoduleWith lib {
              modules = [
                {
                  options.pkgs = lib.mkOption {
                    default = pkgs;
                    defaultText = lib.literalExpression "pkgs";
                  };
                  config.configRoot = self;
                }
              ];
            };
            conanModule = {
              options = {
                conan = lib.mkOption {
                  type = conanSubmodule;
                  description = "Conan configuration";
                  default = { };
                };
              };
            }; # conanModule
            conanModuleConfig =
              (lib.evalModules {
                modules = [
                  ({ config, ... }: {
                    imports = [ conanModule ];

                    conan = {
                      profiles.default = {
                        settings.compiler."compiler.cppstd" = "14";
                        settings._.build_type = "Debug";
                      };

                      devShell = {
                        tools = { inherit (pkgs) just; };
                      };

                      remotes.local = {
                        url = "./repo";
                        local = true;
                        allowedPackages = [ "hello-world/0.0.1.cci.20260428" ];
                      };

                      offline = true;

                      checks.example = {
                        enable = true;
                        drv =
                          conan-flake.lib.runCommandWithInSimulatedShell pkgs config.conan.stdenv config.conan.outputs.devShell
                            config.conan.info.configRoot "./config"
                            "standalone-submodule-with-example-conan-create"
                            { }
                            ''
                              (
                              set -x
                              conan create . --build=missing 2>&1 | grep -F "example/0.0.1"
                              touch $out
                              )
                            ''; # checks.example
                      };
                    };
                  })
                ];
              }).config.conan; # conanModuleConfig
          in
          {
            devShells.default = conanModuleConfig.outputs.devShell;
            checks = conanModuleConfig.outputs.checks;
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
