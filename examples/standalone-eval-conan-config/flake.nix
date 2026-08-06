# file: examples/standalone-eval-conan-config/flake.nix
{
  # { inputs
  # {
    inputs = {
      nixpkgs.url = "github:cachix/devenv-nixpkgs/rolling";

      # Add this:
      conan-flake.url = "git+https://codeberg.org/tarcisio/conan-flake";
    };
    # ...
  # }
  # inputs }

  # { outputs
  #  {
    # ...
    outputs = { self, nixpkgs, conan-flake, ... }:
      let
        eachSystem = nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed;

        # See below for the actual `perSystem` function definition:
  #        perSystem = system:
  #          let
  #            # ...
  #            configuration = conan-flake.lib.evalConanConfig pkgs (
  #              # ...
  #            );
  #          in
  #          {
  #            devShells = {
  #              # ...
  #            };
  #            checks = {
  #              # ...
  #            };
  #          };
  #        systemOutputs = eachSystem perSystem;
  #      in
  #      {
  #        devShells = nixpkgs.lib.mapAttrs (_: s: s.devShells) systemOutputs;
  #        checks = nixpkgs.lib.mapAttrs (_: s: s.checks) systemOutputs;
  #      };
  #  }
  # outputs }

      # { perSystem
      # file: examples/standalone-eval-conan-config/flake.nix
      #  {
        # ...
        perSystem = system:
          let
            pkgs = nixpkgs.legacyPackages.${system};

            configuration = conan-flake.lib.evalConanConfig pkgs (

              { pkgs, config, ... }: {

                configRoot = self;

                profiles.default = {
                  settings.compiler."compiler.cppstd" = "17";
                  settings._.build_type = "Release";
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
                    conan-flake.lib.runCommandWithInSimulatedShell pkgs config.stdenv config.outputs.devShell
                      config.info.configRoot "./config"
                      "standalone-eval-conan-config-example-conan-create"
                      { }
                      ''
                        (
                        set -x
                        conan create . --build=missing 2>&1 | grep -F "example/0.0.1"
                        touch $out
                        )
                      ''; # checks.example
                };
              }
            );
          in
          {
            devShells.default = configuration.config.outputs.devShell;
            checks = configuration.config.outputs.checks;
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
