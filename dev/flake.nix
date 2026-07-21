{
  inputs = {
    devenv-root = {
      url = "file+file:///dev/null";
      flake = false;
    };

    ### nixpkgs
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixpkgs-unstable-lib.url = "github:NixOS/nixpkgs/nixpkgs-unstable?dir=lib";
    devenv-nixpkgs.url = "github:cachix/devenv-nixpkgs/main";
    devenv-nixpkgs-lib.url = "github:cachix/devenv-nixpkgs/main";

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
    git-hooks.inputs.flake-parts.follows = "flake-parts";
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
            self',
            pkgs,
            config,
            lib,
            ...
          }:
          {
            _module.args.pkgs = import inputs.nixpkgs {
              inherit system;
              overlays = [
                (_: prev: {
                  woodpecker-cli =
                    let
                      version = "3.15.0";
                    in
                    prev.woodpecker-cli.overrideAttrs (_: {
                      inherit version;
                      src = prev.fetchFromGitHub {
                        owner = "woodpecker-ci";
                        repo = "woodpecker";
                        tag = "v${version}";
                        hash = "sha256-enWZkYlZq2sWez4Uz78ZdNc+bqiN/UHnI5oOCicyjDI";
                      };
                      ldflags = [
                        "-s"
                        "-w"
                        "-X go.woodpecker-ci.org/woodpecker/v3/version.Version=${version}"
                      ];
                      vendorHash = "sha256-7Hiyf/W1os1+Rd5VY4j96U3n6chub13fhbh0V3hPcCg=";
                    });
                })
                (
                  _: prev:
                  let
                    name = "mdsh";
                    version = "0.9.3";
                    versionHash = "sha256-W9znh93RokghlqIjRRjIUJmkXxUAtLZtpZfGceTPK14=";
                    versionCargoHash = "sha256-JbmHwAn3oXUUXsiQgCcZSBBS9o9Kam66MWHnbo25Fxg=";
                    src = prev.fetchFromGitHub {
                      owner = "tarc";
                      repo = name;
                      # tag = "v${version}";
                      rev = "cd7d2374b551fbe5bf02367398cf6d6b140fca38";
                      hash = versionHash;
                    };
                  in
                  {
                    mdsh = prev.mdsh.overrideAttrs (_: rec {
                      inherit version src;
                      cargoDeps = prev.rustPlatform.fetchCargoVendor {
                        inherit src;
                        name = "${name}-${version}-vendor";
                        hash = versionCargoHash;
                      };
                    });
                  }
                )
              ];
              config = {
                allowUnfree = true;
              };
            };

            packages.embedmd = pkgs.writeShellApplication {
              name = "embedmd";
              runtimeInputs = [ pkgs.go ];
              text = ''
                if [ $# -eq 0 ]; then
                  flag=-w
                else
                  flag="$1"
                fi
                go tool -C "$CONAN_FLAKE_HOME" embedmd "$flag" "$CONAN_FLAKE_ROOT/README.md"
              '';
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
                  go
                  jq
                  just
                  mdsh
                  nixfmt
                  woodpecker-cli
                  self'.packages.embedmd
                  htop

                  autoconf
                  libtool
                ];

                git-hooks = {
                  hooks = {
                    embedmd = {
                      enable = true;
                      name = "Embed code snippets in README";
                      entry = "embedmd";
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
