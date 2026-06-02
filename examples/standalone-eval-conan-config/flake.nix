# file: examples/standalone-eval-conan-config/flake.nix
{
  # { inputs
  # {
    inputs = {
      nixpkgs.url = "github:cachix/devenv-nixpkgs/rolling";
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

  #        perSystem = system: {
  #          packages = {
  #            # ...
  #          };
  #          devShells = {
  #            # ...
  #          };
  #          checks = {
  #            # ...
  #          };
  #        };

  #        systemOutputs = eachSystem perSystem;
  #   in
  #   {
  #     packages = nixpkgs.lib.mapAttrs (_: s: s.packages) systemOutputs;
  #     devShells = nixpkgs.lib.mapAttrs (_: s: s.devShells) systemOutputs;
  #     checks = nixpkgs.lib.mapAttrs (_: s: s.checks) systemOutputs;
  #   };
  #  }
  # outputs }

      # { perSystem
      #  {
        # ...
        perSystem = system:
          let
            pkgs = nixpkgs.legacyPackages.${system};

            configuration = conan-flake.lib.evalConanConfig pkgs {

              configRoot = self;

              modules = [
                ({ pkgs, config, ... }: {
                  buildType = "Release";
                  compilerCppStd = "17";

                  platformToolRequires = {
                    cmake = pkgs.cmake.version;
                  };

                  devShell = {
                    # Programs you want to make available in the shell.
                    tools = {
                      inherit (pkgs) cmake;
                    };
                  };

                  remotes.local = {
                    url = "./repo";
                    local = true;
                    allowedPackages = [
                      "hello-world/0.0.1.cci.20260428"
                    ];
                  };

                  # Enable only local remotes (i.e. only of local-recipe-index type):
                  offline = true;
                })
              ];
            };
          in
          {
            packages = configuration.packages;
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
                conan create ${self} -tf "" --build=missing 2>&1 | grep "example/0.0.1"
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
