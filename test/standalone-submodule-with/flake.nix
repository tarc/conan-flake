# file: test/standalone-submodule-with/flake.nix
{
  inputs = {
    nixpkgs.url = "github:cachix/devenv-nixpkgs/ec3063523dcd911aeadb50faa589f237cdab5853";
    conan-flake = { };
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
          };
          conanModuleConfig =
            (lib.evalModules {
              modules = [
                ({ config, ... }: {
                  imports = [ conanModule ];

                  conan = {
                    profiles = {
                      settings.compiler."compiler.cppstd" = "14";
                      settings.rest.build_type = "Debug";
                    };

                    remotes.local = {
                      url = "./repo";
                      local = true;
                      allowedPackages = [ "hello-world/0.0.1.cci.20260428" ];
                    };

                    offline = true;

                    checks.test = {
                      enable = true;
                      drv =
                        conan-flake.lib.runCommandWithInSimulatedShell pkgs config.conan.stdenv
                          config.conan.outputs.devShell
                          config.conan.info.configRoot
                          "."
                          "standalone-submodule-with-test-conan-create"
                          { }
                          ''
                            (
                            set -x
                            echo "CONAN_FLAKE_ROOT:''${CONAN_FLAKE_ROOT@Q}" |
                              grep -F "CONAN_FLAKE_ROOT:'/build/$(basename ${config.conan.info.configRoot})'"
                            echo "CONAN_FLAKE_HOME:''${CONAN_FLAKE_HOME@Q}" |
                              grep -F "CONAN_FLAKE_HOME:'/build/$(basename ${config.conan.info.configRoot})'"
                            echo "CONAN_FLAKE_CONFIG:''${CONAN_FLAKE_CONFIG@Q}" | \
                              grep -F "CONAN_FLAKE_CONFIG:'$(realpath -m "/build/$(basename ${config.conan.info.configRoot})/"${pkgs.lib.escapeShellArg config.conan.configLocal})'"
                            echo "CONAN_HOME:''${CONAN_HOME@Q}" | \
                              grep -F "CONAN_HOME:'$(realpath -m "/build/$(basename ${config.conan.info.configRoot})/"${pkgs.lib.escapeShellArg config.conan.conanHome})'"
                            conan create . --build=missing 2>&1 | grep -F "example/0.0.1"
                            touch $out
                            )
                          '';
                    };
                  };
                })
              ];
            }).config.conan;
        in
        {
          devShells.default = conanModuleConfig.outputs.devShell;
          checks = conanModuleConfig.outputs.checks;
        };
      systemOutputs = eachSystem perSystem;
    in
    {
      devShells = nixpkgs.lib.mapAttrs (_: s: s.devShells) systemOutputs;
      checks = nixpkgs.lib.mapAttrs (_: s: s.checks) systemOutputs;
    };
}
