# Definition of the `conan` submodule's `config`
{ config
, lib
, pkgs
, ...
}:
let
  inherit (lib)
    mkOption
    optionalString
    types
    ;
  inherit (pkgs.lib)
    concatMapStringsSep
    escapeShellArg
    ;

  rootFindingSubmodule = types.submodule {
    options = {
      isInStoreRoot = mkOption {
        type = types.bool;
        internal = true;
        readOnly = true;
        default = types.pathInStore.check config.configRoot;
      };

      package = mkOption {
        type = types.package;
        internal = true;
        readOnly = true;
        default = pkgs.writeShellApplication {
          name = "root";
          text = ''
            set -euo pipefail
            # Disable "references arguments, but none are ever passed." for
            # find_config_root() only:
            # shellcheck disable=SC2120
            find_config_root() {
              if [[ -d ${escapeShellArg config.configRoot} ]]; then
                cd ${escapeShellArg config.configRoot}
                echo "$PWD"
                exit 0
              fi
              if [ $# -eq 0 ]; then
                echo "ERROR: Directory not found ${escapeShellArg config.configRoot}" >&2
              else
                echo "ERROR: Directory not found ${escapeShellArg config.configRoot}" >&2
                echo "ERROR: Unable to locate $1 in any of: $2" >&2
              fi
              exit 1
            }
            find_up() { ${
              # `configRoot` is an absolute path not in the store:
              optionalString (!config.rootFinding.isInStoreRoot) ''
                find_config_root
              ''
            } ${
              # `configRoot` is in the store:
              optionalString (config.rootFinding.isInStoreRoot) ''
                ancestors=()
                while true; do
                  if [[ -f $1 ]]; then
                    echo "$PWD"
                    exit 0
                  fi
                  for file in "''${@:2}"; do
                    if [[ -f $file ]]; then
                      echo "$PWD"
                      exit 0
                    fi
                  done
                  ancestors+=("$PWD")
                  if [[ $PWD == / ]] || [[ $PWD == // ]]; then
                    input=( "''${@:2}" )
                    crfs="''${input[*]@Q}"
                    if [[ $crfs != "" ]]; then
                      crfs=" (nor: $crfs)"
                    fi
                    find_config_root "''${1@Q}''${crfs}" "''${ancestors[*]@Q}"
                  fi
                  cd ..
                done
              ''
            }
            }
            find_up \
              ${escapeShellArg config.configRootFile} \
              ${concatMapStringsSep " " escapeShellArg config.configRootFiles}
          '';
        };
      };
    };
  };
in
{
  options = {
    configRoot = mkOption {
      type = types.path;
      description = ''
        Path to the root of the configuration directory. Defaults to the Nix
        store path of the client flakes code (when using the flakes
        integration), or to the devenv root directory (when using devenv
        integration).

        Setting this to an external path (that is, an absolute path not in the
        Nix store) &mdash; which is the case when using devenv integration, for
        instance, &mdash; will have this as the only option when trying to set
        the CONAN_FLAKE_ROOT environment variable.
      '';
    };

    configRootFile = mkOption {
      type = types.str;
      description = ''
        Can be used to discover the root of the configuration.

        Whenever the `configRoot` is not explicitly set, this is used to locate
        the root directory. This option is a string that is used to search for
        a file in the root directory.
      '';
      default = "conanfile.py";
    };

    configRootFiles = mkOption {
      type = types.listOf types.str;
      description = ''
        Can be used to discover the root of the configuration.

        This is a list of files to locate in the root directory to be used only
        as fallbacks when `configRootFile` cannot be found.
      '';
      default = [
        "flake.nix"
        ".git/config"
      ];
    };

    rootFinding = mkOption {
      type = rootFindingSubmodule;
      internal = true;
      readOnly = true;
      default = { };
    };
  };
}
