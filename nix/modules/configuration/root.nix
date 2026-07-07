# Definition of the `conan` submodule's `config`
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    escapeShellArg
    mkOption
    optionalString
    types
    ;
  inherit (pkgs.lib) concatMapStringsSep;

  rootFindingSubmodule = types.submodule {
    options = {
      package = mkOption {
        type = types.package;
        internal = true;
        readOnly = true;
        default = pkgs.writeShellApplication {
          name = "root";
          text = ''
            # Disable "references arguments, but none are ever passed." for
            # handle_fallback() only:
            # shellcheck disable=SC2120
            handle_fallback() { ${
              # If `homeRoot` is set, allow `configRoot` to be returned,
              # in which case the developer environment working directory
              # is well-defined and there's no problem returning an
              # immutable store path here:
              optionalString (config.homeFinding.homeRootIsDefined) ''
                echo ${config.configRoot}
                exit 0
              ''
            } ${
              # `homeRoot` is not set:
              optionalString (config.homeFinding.homeRootIsNotDefined) ''
                echo "ERROR: Unable to locate $1 in any of: $2" >&2
                exit 1
              ''
            }
            }
            find_up() {
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
                  handle_fallback "''${1@Q}''${crfs}" "''${ancestors[*]@Q}"
                fi
                cd ..
              done
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
      type = types.pathInStore;
      description = ''
        Path to the root of the configuration. Defaults to the Nix store path
        of client's code `self`.
      '';
    };

    configRootFile = mkOption {
      type = types.str;
      description = ''
        Can be used to discover the root of the configuration on a
        developer environment. It's a parameter of the root finding
        algorithm defined in `rootFinding.package`.

        This option is a string that represents a filename which is
        searched for in the root directory.
      '';
      default = "conanfile.py";
    };

    configRootFiles = mkOption {
      type = types.listOf types.str;
      description = ''
        Can be used to discover the root of the configuration on a
        developer environment. It's a parameter of the root finding
        algorithm defined in `rootFinding.package`.

        This is a list of files to locate in the root directory to be
        used only as fallbacks when `configRootFile` cannot be found.
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
