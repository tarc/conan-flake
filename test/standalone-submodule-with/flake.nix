# file: test/standalone-submodule-with/flake.nix
{
  inputs = {
    nixpkgs.url = "github:cachix/devenv-nixpkgs/ec3063523dcd911aeadb50faa589f237cdab5853";
    conan-flake = { };
  };
  outputs = { self, nixpkgs, conan-flake, ... }:
    let
      eachSystem = nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed;

      # { perSystem
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
            };
            conanModuleConfig = (lib.evalModules {
              modules = [
                {
                  imports = [
                    conanModule
                  ];

                  conan = {
                    # conf = {
                    #   "tools.cmake.cmaketoolchain:user_presets" = "";
                    # };

                    platformToolRequires = {
                      cmake = pkgs.cmake.version;
                    };

                    devShell = {
                      # Programs you want to make available in the shell.
                      tools = {
                        inherit (pkgs) cmake;
                      };
                    };

                    # It's possible to specify Conan remotes explicitly, including
                    # local-recipe-index remotes -- in which case the `url` is
                    # taken as a relative path to the root of the configuration:
                    remotes.local = {
                      url = "./repo";
                      local = true;
                      allowedPackages = [
                        "hello-world/0.0.1.cci.20260428"
                      ];
                    };

                    # Enable only local remotes (i.e. only of local-recipe-index type):
                    offline = true;
                  };
                }
              ];
            }).config.conan;
          in
          {
            packages = conanModuleConfig.outputs.packages;
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
      packages = nixpkgs.lib.mapAttrs (_: s: s.packages) systemOutputs;
      devShells = nixpkgs.lib.mapAttrs (_: s: s.devShells) systemOutputs;
      checks = nixpkgs.lib.mapAttrs (_: s: s.checks) systemOutputs;
    };
}
