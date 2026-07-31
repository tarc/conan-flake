{
  inputs = {
    devenv-root = {
      url = "file+file:///dev/null";
      flake = false;
    };

    ### nixpkgs
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixpkgs-unstable-lib.url = "github:NixOS/nixpkgs/nixpkgs-unstable?dir=lib";
    devenv-nixpkgs.url = "github:cachix/devenv-nixpkgs/rolling";
    devenv-nixpkgs-lib.url = "github:cachix/devenv-nixpkgs/rolling";

    # Default nixpkgs
    nixpkgs.follows = "devenv-nixpkgs";
    nixpkgs-lib.follows = "devenv-nixpkgs-lib";

    flake-parts.url = "github:hercules-ci/flake-parts";
    git-hooks.url = "github:cachix/git-hooks.nix";
    devenv.url = "github:cachix/devenv";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    nix2container.url = "github:nlewo/nix2container";
    mk-shell-bin.url = "github:tarc/nix-mk-shell-bin";
    conan-flake.url = "git+https://codeberg.org/tarcisio/conan-flake";
    infuse = {
      url = "git+https://codeberg.org/amjoseph/infuse.nix?rev=364ea18b5611b5fd6a6acd7151411b430a70e194";
      flake = false;
    };

    # Minimize duplicate instances of inputs
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs-lib";
    git-hooks.inputs.nixpkgs.follows = "nixpkgs";
    devenv.inputs.nixpkgs.follows = "nixpkgs";
    devenv.inputs.flake-parts.follows = "flake-parts";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
    nix2container.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    inputs@{
      nixpkgs,
      flake-parts,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } (
      { ... }: {
        systems = nixpkgs.lib.systems.flakeExposed;
        imports = [
          inputs.devenv.flakeModule
          inputs.conan-flake.flakeModule
        ];

        # `flake-parts` options to enable debug inspecting.
        debug = true;

        perSystem =
          {
            system,
            pkgs,
            config,
            lib,
            ...
          }:
          {
            _module.args.pkgs = import inputs.nixpkgs {
              inherit system;
              overlays = [
                (_: _prev: {
                  woodpecker-cli = inputs.conan-flake.lib.packages.woodpecker-cli pkgs;
                  embedmd = inputs.conan-flake.lib.packages.embedmd pkgs;
                  mdsh = inputs.conan-flake.lib.packages.mdsh_0_9_3 pkgs;
                })
              ];
              config = {
                allowUnfree = true;
              };
            };

            conan = {
              configRoot = inputs.conan-flake;

              homeDirectory = "./dev";

              wrappers = {
                conanFlakeLockFile = "conan-flake.lock";
                conanInstall = true;
                conanLockFile = "conan.lock";
              };

              remotes.local = {
                url = "./dev/repo";
                local = true;
                allowedPackages = [
                  "hello-world/0.0.1.cci.20260428"
                ];
              };

              offline = true;

              checks.test = {
                enable = true;
                drv =
                  inputs.conan-flake.lib.runCommandWithInSimulatedShell pkgs config.conan.stdenv
                    config.conan.outputs.devShell
                    config.conan.info.configRoot
                    "./config"
                    "dev"
                    { }
                    ''
                      (
                      set -x
                      echo "Testing dev ..."

                      echo "Checking local development pipeline..."

                      echo "CONAN_FLAKE_ROOT:''${CONAN_FLAKE_ROOT@Q}" \
                        | grep -F "CONAN_FLAKE_ROOT:'$HOME/config'"
                      echo "CONAN_FLAKE_HOME:''${CONAN_FLAKE_HOME@Q}" \
                        | grep -F "CONAN_FLAKE_HOME:'$(realpath -m "$HOME/config/"${lib.escapeShellArg config.conan.homeDirectory})'"
                      echo "CONAN_FLAKE_CONFIG:''${CONAN_FLAKE_CONFIG@Q}" \
                        | grep -F "CONAN_FLAKE_CONFIG:'$(realpath -m "$HOME/config/"${lib.escapeShellArg config.conan.homeDirectory}"/"${lib.escapeShellArg config.conan.configLocal})'"
                      echo "CONAN_HOME:''${CONAN_HOME@Q}" \
                        | grep -F "CONAN_HOME:'$(realpath -m "$HOME/config/"${lib.escapeShellArg config.conan.homeDirectory}"/"${lib.escapeShellArg config.conan.conanHome})'"

                      echo "CONAN_FLAKE_ROOT:''${CONAN_FLAKE_ROOT@Q}" \
                        | grep -F "CONAN_FLAKE_ROOT:'$HOME/config'"
                      echo "CONAN_FLAKE_HOME:''${CONAN_FLAKE_HOME@Q}" \
                        | grep -F "CONAN_FLAKE_HOME:'$(realpath -m "$HOME/config/dev")'"
                      echo "CONAN_FLAKE_CONFIG:''${CONAN_FLAKE_CONFIG@Q}" \
                        | grep -F "CONAN_FLAKE_CONFIG:'$(realpath -m "$HOME/config/dev/config")'"
                      echo "CONAN_HOME:''${CONAN_HOME@Q}" \
                        | grep -F "CONAN_HOME:'$(realpath -m "$HOME/config/dev/.conan2")'"

                      conan install . --build=missing
                      conan build . --build=missing
                      ./build/Release/foo | grep -F "foo/1.0 test_package"

                      touch $out
                      )
                    '';
              };
            };

            devenv = {
              shells.default = {
                name = "conan-flake-dev";

                languages = {
                  haskell = {
                    enable = true;
                  };
                };

                env = {
                  LD_LIBRARY_PATH = "/usr/lib/wsl/lib";
                  MESA_D3D12_DEFAULT_ADAPTER_NAME = "NVIDIA";
                  GALLIUM_DRIVER = "d3d12";
                };

                inputsFrom = [
                  # conan-flake exposes a `configuration` devShell by default that
                  # can be used directly, or passed in the inputsFrom option as a
                  # means to compose with other devShell modules:
                  config.conan.outputs.devShell
                ];

                packages = with pkgs; [
                  ccls
                  jq
                  just
                  mdsh
                  nixfmt
                  woodpecker-cli
                  htop

                  autoconf
                  libtool
                ];

                git-hooks = {
                  hooks = {
                    embedmd = {
                      enable = true;
                      name = "Embed code snippets in README";
                      entry = "embedmd ${config.devenv.shells.default.env.DEVENV_ROOT}/README.md";
                      types = [
                        "text"
                        "nix"
                      ];
                      pass_filenames = false;
                    };
                  };
                };

                treefmt = {
                  enable = true;
                  config = ./treefmt.nix;
                };
              };
            };
          };
      }
    );
}
