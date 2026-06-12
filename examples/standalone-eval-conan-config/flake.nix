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
  #            configuration = conan-flake.lib.evalConanConfig pkgs {
  #              # ...
  #            };
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

            configuration = conan-flake.lib.evalConanConfig pkgs {

              configRoot = self;

              modules = [
                ({ pkgs, config, ... }: {
                  profiles.settings.rest.build_type = "Release";
                  compilerCppStd = "17";

                  remotes.local = {
                    url = "./repo";
                    local = true;
                    allowedPackages = [ "hello-world/0.0.1.cci.20260428" ];
                  };

                  offline = true;
                })
              ];
            };
          in
          {
            devShells.default = configuration.devShell;
            checks.test = pkgs.runCommandWith
              {
                name = "standalone-eval-conan-config-test-conan-create";
                inherit (pkgs) stdenv;
                derivationArgs = { inherit (configuration.devShell) buildInputs nativeBuildInputs; };
              }
              ''
                (
                set -x
                ${configuration.devShell.shellHook}
                conan create ${self} -tf "" --build=missing 2>&1 | grep -F "example/0.0.1"
                touch $out
                )
              ''; # checks.test
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
