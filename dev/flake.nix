{
  inputs = {
    devenv-root = {
      url = "file+file:///dev/null";
      flake = false;
    };
    nixpkgs.url = "github:cachix/devenv-nixpkgs/rolling";
    flake-parts.url = "github:hercules-ci/flake-parts";
    git-hooks.url = "github:cachix/git-hooks.nix";
    devenv.url = "github:cachix/devenv";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    nix2container.url = "github:nlewo/nix2container";
    mk-shell-bin.url = "github:rrbutani/nix-mk-shell-bin";
    conan-flake.url = "git+https://codeberg.org/tarcisio/conan-flake";
    infuse = {
      url = "git+https://codeberg.org/amjoseph/infuse.nix?rev=e837ece1b9de6ebcb7abd261f54a09bad3a2f820";
      flake = false;
    };
  };

  outputs = inputs@{ self, nixpkgs, flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } ({ withSystem, ... }: {
      systems = nixpkgs.lib.systems.flakeExposed;
      imports = [
        inputs.devenv.flakeModule
        inputs.conan-flake.flakeModule
      ];

      # `flake-parts` options to enable debug inspecting.
      debug = true;

      perSystem = { system, self', pkgs, config, ... }: {

        packages.embedmd = pkgs.writeShellApplication {
          name = "embedmd";
          runtimeInputs = [ pkgs.go ];
          text = ''
            if [ $# -eq 0 ]; then
              flag=-w
            else
              flag="$1"
            fi
            go tool -C "$CONAN_FLAKE_ROOT/dev" embedmd "$flag" "$CONAN_FLAKE_ROOT/README.md"
          '';
        };

        conan = {
          platformToolRequires = {
            cmake = pkgs.cmake.version;
          };

          devShell = {
            tools = { inherit (pkgs) cmake go; };
          };

          remotes.local = {
            url = "./repo";
            local = true;
            allowedPackages = [
              "hello-world/0.0.1.cci.20260428"
            ];
          };

          offline = true;
        };

        devenv = {
          shells.default = {
            name = "conan-flake-dev";

            inputsFrom = [
              # conan-flake exposes a `configuration` devShell by default that
              # can be used directly, or passed in the inputsFrom option as a
              # means to compose with other devShell modules.
              config.conan.outputs.devShell
            ];

            packages = [
              pkgs.just
              self'.packages.embedmd
            ];

            git-hooks.hooks.embedmd = {
              enable = true;
              name = "Embed code snippets in README";
              entry = "embedmd";
              types = [ "text" "nix" ];
              pass_filenames = false;
            };

            treefmt = {
              enable = true;
              config = {
                programs = {
                  nixpkgs-fmt.enable = true;
                  cmake-format.enable = true;
                };
                settings.formatter = {
                  nixpkgs-fmt = {
                    excludes = [
                      "examples/devenv-module/devenv.nix"
                      "examples/devenv-module-recipe/devenv.nix"
                      "examples/flake-parts/flake.nix"
                      "examples/standalone-eval-conan-config/flake.nix"
                      "test/standalone-submodule-with/flake.nix"
                    ];
                  };
                };
              };
            };
          };
        };

        # conan-flake doesn't set the default package, but you can do it here.
        # packages.default = self'.packages.example;
      };
    });
}
