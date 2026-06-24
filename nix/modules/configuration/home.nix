# Definition of the `conan` submodule's `config`
{ config
, lib
, pkgs
, relativePathType
, ...
}:
let
  inherit (lib) mkOption optionalString types;
  inherit (pkgs.lib) escapeShellArg;

  homeFindingSubmodule = types.submodule {
    options = {
      isNotNullHome = mkOption {
        type = types.bool;
        internal = true;
        readOnly = true;
        default = config.configHome != null;
      };

      package = mkOption {
        type = types.package;
        internal = true;
        readOnly = true;
        default = pkgs.writeShellApplication {
          name = "home";
          text = ''
            set -euo pipefail
            get_env_var() {
              local var_name="$1"
              if [ -z "$var_name" ]; then
                echo "ERROR: No variable name provided" >&2
                exit 1
              fi
              if [ -z "''${!var_name+x}" ]; then
                echo "ERROR: Environment variable '$var_name' is not defined" >&2
                exit 1
              fi
              echo "''${!var_name}"
              exit 0
            }
            # Disable "This function is never invoked." for find_config_home() only:
            # shellcheck disable=SC2329
            find_config_home() {
              if [[ -d ${escapeShellArg config.configHome} ]]; then
                cd ${escapeShellArg config.configHome}
              ${
                # `configRoot` is in the store:
                optionalString (config.rootFinding.isInStoreRoot) ''
                  fi
                ''
              }
              ${
                # `configRoot` is an absolute path not in the store:
                optionalString (!config.rootFinding.isInStoreRoot) ''
                  elif [[ -d ${escapeShellArg config.configRoot} ]]; then
                    cd ${escapeShellArg config.configRoot}
                  fi
                ''
              }
              CONAN_FLAKE_HOME="$PWD"
              export CONAN_FLAKE_HOME
              CONAN_FLAKE_CONFIG="$(realpath "$PWD/"${escapeShellArg config.configLocal})"
              export CONAN_FLAKE_CONFIG
              CONAN_HOME="$(realpath "$PWD/"${escapeShellArg config.conanHome})"
              export CONAN_HOME
              get_env_var "$1"
            }
            is_in_nix_store() {
              local path="$1"
              local resolved
              resolved=$(realpath "$path" 2>/dev/null || echo "$path")
              [[ "$resolved" == /nix/store/* ]]
            }
            find_env_var() { ${
              # `configHome` is set:
              optionalString (config.homeFinding.isNotNullHome) ''
                find_config_home "$1"
              ''
            } ${
              # `configHome` is not set:
              optionalString (!config.homeFinding.isNotNullHome) ''
                if is_in_nix_store "$CONAN_FLAKE_ROOT"; then
                  CONAN_FLAKE_HOME="$PWD"
                  export CONAN_FLAKE_HOME
                  CONAN_FLAKE_CONFIG="$(realpath "$PWD/"${escapeShellArg config.configLocal})"
                  export CONAN_FLAKE_CONFIG
                  CONAN_HOME="$(realpath "$PWD/"${escapeShellArg config.conanHome})"
                  export CONAN_HOME
                  get_env_var "$1"
                else
                  cd "$CONAN_FLAKE_ROOT"
                  CONAN_FLAKE_HOME="$PWD"
                  export CONAN_FLAKE_HOME
                  CONAN_FLAKE_CONFIG="$(realpath "$PWD/"${escapeShellArg config.configLocal})"
                  export CONAN_FLAKE_CONFIG
                  CONAN_HOME="$(realpath "$PWD/"${escapeShellArg config.conanHome})"
                  export CONAN_HOME
                  get_env_var "$1"
                fi
              ''
            }
            }
            if [ $# -eq 0 ]; then
              echo "ERROR: No arguments provided" >&2
              exit 1
            fi
            # Resolve out directory:
            out="/out"
            export out
            # Resolve the Conan Flake root directory:
            CONAN_FLAKE_ROOT="$1"
            export CONAN_FLAKE_ROOT
            # Resolve the query to respond:
            query="CONAN_FLAKE_HOME"
            if [ $# -gt 1 ]; then
              query="$2"
            fi
            find_env_var "$query"
          '';
        };
      };
    };
  };
in
{
  options = {
    configLocal = mkOption {
      type = relativePathType;
      description = ''
        Relative path to a developer environment configuration directory.

        Used to keep links pointing to the generated configuration in the
        store.
      '';
      default = "./config";
    };

    conanHome = mkOption {
      type = relativePathType;
      description = ''
        Relative path to the developer environment Conan home.

        This is where Conan will keep its local cache, profiles and other
        settings.
      '';
      default = "./.conan2";
    };

    configHome = mkOption {
      type = types.nullOr types.externalPath;
      description = ''
        Path to the home of the configuration. Defaults to the Nix store
        path of the client flakes code (when using the flakes integration), or
        to the devenv root directory (when using devenv integration).

        Setting this to an external path (that is, an absolute path not in the
        Nix store) &mdash; which is the case when using devenv integration, for
        instance, &mdash; will have this as the only option when trying to set
        the CONAN_FLAKE_ROOT environment variable.
      '';
      default = null;
    };

    homeFinding = mkOption {
      type = homeFindingSubmodule;
      internal = true;
      readOnly = true;
      default = { };
    };
  };
}
