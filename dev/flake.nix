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
      flake-parts,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } (
      { ... }: {
        # Only the evaluating machine's system, and deliberately not
        # `nixpkgs.lib.systems.flakeExposed`.
        #
        # `nix flake show` enumerates every declared system in order to list
        # the outputs each one carries, and evaluating `perSystem` for a system
        # instantiates its `pkgs`. devenv's nixpkgs is produced by an
        # import-from-derivation (`import patchedSrc ...`), so that
        # instantiation has to *build* a patched nixpkgs for the foreign
        # system, which cannot be done here — `nix flake show` failed outright
        # while `nix flake check` merely skipped those systems with a warning.
        #
        # Nothing is lost by narrowing: the outputs for a foreign system could
        # never be built on this machine anyway. This does make the flake
        # impure, which is why every entry point passes `--no-pure-eval`; that
        # is already the case for the `justfile` recipes and for the `dev` step
        # of `.woodpecker/checks.yml`. This flake is a development environment
        # and is never consumed as an input by another flake.
        systems = [ builtins.currentSystem ];
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
          let
            docsChecks = inputs.conan-flake.lib.docsChecks pkgs;
          in
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

            # The documentation site, so that `nix build ./dev#docs` (and the
            # `just docs` recipe behind it) has something to build. Its sources
            # live at the root of the checkout, which this flake reaches through
            # the `conan-flake` input every entry point overrides with it.
            #
            # site.BUILD.4
            packages.docs = inputs.conan-flake.lib.packages.docs pkgs;

            # Building the site is itself a check, so CI fails when the site
            # stops building.
            #
            # site.BUILD.3
            checks.docs = config.packages.docs;

            # site.BUILD.1
            checks."site.BUILD.1" = docsChecks."site.BUILD.1";

            # site.NAVIGATION.2
            checks."site.NAVIGATION.2" = docsChecks."site.NAVIGATION.2";

            # site.NAVIGATION.3
            checks."site.NAVIGATION.3" = docsChecks."site.NAVIGATION.3";

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
                  # Builds and serves the documentation site from this shell,
                  # with no further installation step. authoring.PREVIEW.3
                  mdbook
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
                      # NOTE: keep this path relative, and keep it identical to
                      # the same hook in `dev/devenv.nix` — both configs
                      # generate `.pre-commit-config.yaml` at the repo root, so
                      # if they diverge whichever shell was entered last wins.
                      # prek/pre-commit run hooks with the repo root of the tree
                      # being committed as cwd, so a relative path follows that
                      # tree. An absolute
                      # `${config.devenv.shells.default.env.DEVENV_ROOT}/README.md`
                      # is baked into the generated `.pre-commit-config.yaml`
                      # (and into the store derivation), which makes a commit
                      # from a git worktree, a copy or a CI checkout rewrite the
                      # *primary* checkout's `README.md` instead.
                      entry = "embedmd README.md";
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
