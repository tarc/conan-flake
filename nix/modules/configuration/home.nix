# Definition of the `conan` submodule's `config`
{
  config,
  lib,
  pkgs,
  relativePathType,
  ...
}:
let
  inherit (lib) mkOption optionalString types;
  inherit (pkgs.lib) escapeShellArg;

  homeFindingSubmodule = types.submodule (
    { ... }@args:
    {
      options = {
        homeIsDefined = mkOption {
          type = types.bool;
          internal = true;
          readOnly = true;
          default = config.homeRoot != null;
        };

        homeIsNotDefined = mkOption {
          type = types.bool;
          internal = true;
          readOnly = true;
          default = !args.config.homeIsDefined;
        };

        package = mkOption {
          type = types.package;
          internal = true;
          readOnly = true;
          default = pkgs.writeShellApplication {
            name = "home";
            text = ''
              set -euo pipefail
              export_env_vars() {
                CONAN_FLAKE_HOME="$PWD"
                export CONAN_FLAKE_HOME
                CONAN_FLAKE_CONFIG="$(realpath -m "$PWD/"${escapeShellArg config.configLocal})"
                export CONAN_FLAKE_CONFIG
                CONAN_HOME="$(realpath -m "$PWD/"${escapeShellArg config.conanHome})"
                export CONAN_HOME
              }
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
                cd ${escapeShellArg config.homeRoot}
                if [[ -d ${escapeShellArg config.homeDirectory} ]]; then
                  cd ${escapeShellArg config.homeDirectory}
                fi
                export_env_vars
                get_env_var "$1"
              }
              is_in_nix_store() {
                local path="$1"
                local resolved
                resolved=$(realpath -m "$path" 2>/dev/null || echo "$path")
                [[ "$resolved" == /nix/store/* ]]
              }
              find_env_var() { ${
                # `homeRoot` is defined:
                optionalString (config.homeFinding.homeIsDefined) ''
                  find_config_home "$1"
                ''
              } ${
                # `homeRoot` is not defined:
                optionalString (config.homeFinding.homeIsNotDefined) ''
                  if is_in_nix_store "$CONAN_FLAKE_ROOT"; then
                    if [[ -d ${escapeShellArg config.homeDirectory} ]]; then
                      cd ${escapeShellArg config.homeDirectory}
                    fi
                    export_env_vars
                    get_env_var "$1"
                  else
                    cd "$CONAN_FLAKE_ROOT"
                    if [[ -d ${escapeShellArg config.homeDirectory} ]]; then
                      cd ${escapeShellArg config.homeDirectory}
                    fi
                    export_env_vars
                    get_env_var "$1"
                  fi
                ''
              }
              }
              if [ $# -eq 0 ]; then
                echo "ERROR: No arguments provided" >&2
                exit 1
              fi
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
    }
  );
in
{
  options = {
    configLocal = mkOption {
      type = relativePathType;
      description = ''
        Configuration directory to be created in the developer environment.

        Used to keep links pointing to the generated configuration in the
        store.
      '';
      default = "./config";
    };

    conanHome = mkOption {
      type = relativePathType;
      description = ''
        Conan home relative to the developer environment.

        This is where Conan will keep its local cache, profiles and other
        settings.
      '';
      default = "./.conan2";
    };

    homeRoot = mkOption {
      type = types.nullOr types.externalPath;
      description = ''
        Path to the developer environment initial working directory. Can be
        used to bypass any other finding logic defined in `homeFinding.package`
        to set the CONAN_FLAKE_HOME environment variable (unless it's a non
        existent path). Defaults to `null`.
      '';
      default = null;
    };

    homeDirectory = mkOption {
      type = relativePathType;
      description = ''
        Path to the developer environment working directory relative to the
        initial working directory. Defaults to `"."`.
      '';
      default = ".";
      example = "./dev";
    };

    homeFinding = mkOption {
      type = homeFindingSubmodule;
      internal = true;
      readOnly = true;
      default = { };
    };
  };
}
