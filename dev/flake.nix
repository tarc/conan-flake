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

            # Guard against dead negative assertions in the repository's builder
            # snippets: POSIX and bash both specify that `set -e` ignores the
            # exit status of a pipeline prefixed with the `!` reserved word, and
            # every check here relies on `set -e` alone to propagate failures.
            # An assertion spelled `! grep ...` therefore can never fail its
            # build, which is how seven of them survived green in CI.
            #
            # The sources scanned are the `conan-flake` input, which CI and
            # `just check` both override with this checkout, the way the `conan`
            # configuration below does.
            checks.negated-shell-assertions =
              pkgs.runCommand "negated-shell-assertions"
                {
                  src = inputs.conan-flake;
                }
                ''
                  set -euo pipefail

                  # A line whose first non-blank character is `!` followed by
                  # whitespace is shell negation inside an indented string; Nix's
                  # own uses of `!` (`!=`, `!x`, `!/regex/`) are never spelled
                  # that way.
                  if grep -rnE '^[[:blank:]]*![[:blank:]]' --include='*.nix' -- "$src"; then
                    echo >&2
                    echo 'Negated shell assertion(s) found above.' >&2
                    echo 'A pipeline prefixed with the "!" reserved word has its exit status' >&2
                    echo 'ignored by "set -e", so such an assertion can never fail its build.' >&2
                    echo 'Spell it as an "if" instead, for instance:' >&2
                    echo '  if grep -nF -e PATTERN -- FILE; then' >&2
                    echo '    echo "unexpected match:" PATTERN FILE >&2' >&2
                    echo '    exit 1' >&2
                    echo '  fi' >&2
                    exit 1
                  fi

                  touch $out
                '';

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
