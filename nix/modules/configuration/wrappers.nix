# Definition of the `conan` submodule's `config`
{
  pkgs,
  lib,
  config,
  relativePathType,
  ...
}:
let
  inherit (lib)
    escapeShellArg
    mkOption
    optionalString
    types
    ;
  inherit (pkgs) writeShellScript;
  cfg = config.wrappers;
  wrappersSubmodule = types.submodule (
    { ... }@args:
    {
      options = {
        conanHomeIsExternal = mkOption {
          type = types.bool;
          internal = true;
          readOnly = true;
          default = types.externalPath.check config.conanHome;
        };

        conanHomeIsRelative = mkOption {
          type = types.bool;
          internal = true;
          readOnly = true;
          default = relativePathType.check config.conanHome;
        };

        conanHomeQualifier = mkOption {
          type = types.str;
          internal = true;
          readOnly = true;
          default = "${
            # Add a space:
            optionalString (args.config.conanHomeIsRelative || args.config.conanHomeIsExternal) " "
          }${
            # `conanHome` is relative:
            optionalString (args.config.conanHomeIsRelative) "in relative path"
          }${
            # `conanHome` is external:
            optionalString (args.config.conanHomeIsExternal) "in absolute path"
          }";
        };

        initEnvScript = mkOption {
          type = types.package;
          internal = true;
          readOnly = true;
          default = writeShellScript "init-env-script.sh" ''
            CONAN_FLAKE_ROOT="''$(${lib.getExe config.rootFinding.package})"
            export CONAN_FLAKE_ROOT
            CONAN_FLAKE_HOME="''$(${lib.getExe config.homeFinding.package} "''${CONAN_FLAKE_ROOT}" CONAN_FLAKE_HOME)"
            export CONAN_FLAKE_HOME
            CONAN_FLAKE_CONFIG="''$(${lib.getExe config.homeFinding.package} "''${CONAN_FLAKE_ROOT}" CONAN_FLAKE_CONFIG)"
            export CONAN_FLAKE_CONFIG
            CONAN_HOME="''$(${lib.getExe config.homeFinding.package} "''${CONAN_FLAKE_ROOT}" CONAN_HOME)"
            export CONAN_HOME
          '';
        };

        conanFlakeLockFile = mkOption {
          type = types.nullOr types.str;
          description = ''
            The path to the lock file to output or null to disable lock file generation.
            Defaults to `null`.
          '';
          default = null;
          example = "conan-flake.lock";
        };

        infoWrapperStdoutOutput = mkOption {
          type = types.bool;
          description = ''
            Whether to output the lock file to stdout.
            Defaults to `true`.
          '';
          default = true;
        };

        infoWrapper = mkOption {
          type = types.package;
          internal = true;
          readOnly = true;
          default = pkgs.writeShellApplication {
            name = "info-wrapper";
            runtimeInputs = [
              pkgs.coreutils-full
              pkgs.jq
              pkgs.moreutils
              # Make it possible to use the "conan" command in the script below:
              config.package
            ];
            text = ''
              # shellcheck source=/dev/null
              source ${args.config.initEnvScript}
              printf "CONAN_FLAKE_ROOT:\t%s\n" "''${CONAN_FLAKE_ROOT@Q}" >&2
              printf "CONAN_FLAKE_HOME:\t%s\n" "''${CONAN_FLAKE_HOME@Q}" >&2
              printf "CONAN_FLAKE_CONFIG:\t%s\n" "''${CONAN_FLAKE_CONFIG@Q}" >&2
              printf "CONAN_HOME:\t\t%s\n" "''${CONAN_HOME@Q}" >&2
              cd "$CONAN_FLAKE_HOME"
              if [[ ! -d "$CONAN_HOME" ]]; then
                printf "Missing Conan home${args.config.conanHomeQualifier}...\t(${config.conanHome})\n" >&2
              else
                printf "Found Conan home${args.config.conanHomeQualifier}!\t(${config.conanHome})\n" >&2
                conan_flake_lock="$(mktemp)"
                # shellcheck disable=SC2034
                jq -n \
                    --argjson remotes "$(conan remote list --format json)" \
                    --argjson profiles "$(conan profile list --format json)" \
                    '{remotes: $remotes, profiles: $profiles}' \
                  | tee "$conan_flake_lock" \
                  | xargs -0 printf "%s\n" \
                  | jq -r '.profiles | to_entries[] | "\(.value) [\(.key)]"' \
                  | sort \
                  | while read -r profile key; do
                      profile_object="$(conan profile show -pr "$profile" --format json)"
                      jq \
                          --argjson name "\"$profile\"" \
                          --argjson profile "$profile_object" \
                          '._profiles += {$name: $profile}' \
                          "$conan_flake_lock" \
                        | sponge "$conan_flake_lock"
                    done
                jq --arg prefix "$CONAN_FLAKE_ROOT" '
                    .remotes |= map(
                        if ((.url | startswith("http://")) or (.url | startswith("https://"))) | not
                        then .url |= sub($prefix; ".")
                        else .
                        end
                    )
                ' "$conan_flake_lock" \
                  | sponge "$conan_flake_lock"
                ${
                  #
                  optionalString (args.config.conanFlakeLockFile != null) ''
                    cp "$conan_flake_lock" ${escapeShellArg args.config.conanFlakeLockFile}
                    conan_flake_lock=${escapeShellArg args.config.conanFlakeLockFile}
                  ''
                }
                ${
                  #
                  optionalString (args.config.infoWrapperStdoutOutput) ''
                    cat "$conan_flake_lock" | jq '.'
                  ''
                }
              fi
            '';
          };
        };

        configHomeWrapper = mkOption {
          type = types.package;
          internal = true;
          readOnly = true;
          default = pkgs.writeShellApplication {
            name = "config-home-wrapper";
            text = ''
              # shellcheck source=/dev/null
              source ${args.config.initEnvScript}
              cd "$CONAN_FLAKE_HOME"
              ${lib.getExe config.package} config home
            '';
          };
        };

        preConfigInstallHook = lib.mkOption {
          type = types.lines;
          internal = true;
          description = ''
            Bash code to execute before installing the config.
          '';
          default = "";
        };

        runPreConfigInstallHookWrapper = mkOption {
          type = types.package;
          internal = true;
          readOnly = true;
          default = pkgs.writeShellApplication {
            name = "run-pre-config-install-hook-wrapper";
            text = ''
              # shellcheck source=/dev/null
              source ${args.config.initEnvScript}
              cd "$CONAN_FLAKE_HOME"
              ${cfg.preConfigInstallHook}
            '';
          };
        };

        configInstallWrapper = mkOption {
          type = types.package;
          internal = true;
          readOnly = true;
          default = pkgs.writeShellApplication {
            name = "config-install-wrapper";
            text = ''
              # shellcheck source=/dev/null
              source ${args.config.initEnvScript}
              cd "$CONAN_FLAKE_HOME"
              ${cfg.preConfigInstallHook}
              ${lib.getExe config.package} config install "$CONAN_FLAKE_CONFIG"
            '';
          };
        };

        conanWrapper = mkOption {
          type = types.package;
          internal = true;
          readOnly = true;
          default = pkgs.writeShellApplication {
            name = "conan-wrapper";
            runtimeInputs = [ config.package ];
            text = ''
              # shellcheck source=/dev/null
              source ${args.config.initEnvScript}
              cd "$CONAN_FLAKE_HOME"
              conan "$@"
            '';
          };
        };

        conanLockFile = mkOption {
          type = types.nullOr types.str;
          description = ''
            The conan lock file to generate, or `null` to disable lock file generation.
            Defaults to `null`.
          '';
          default = null;
          example = "conan.lock";
        };

        isLockDefined = mkOption {
          type = types.bool;
          internal = true;
          readOnly = true;
          default = config.wrappers.conanLockFile != null;
        };

        lockCreateWrapper = mkOption {
          type = types.package;
          internal = true;
          readOnly = true;
          default = pkgs.writeShellApplication {
            name = "lock-create-wrapper";
            runtimeInputs = [ config.wrappers.conanWrapper ];
            text = ''
              conan-wrapper lock create . "$@" ${optionalString args.config.isLockDefined ''
                --lockfile-out=${escapeShellArg config.wrappers.conanLockFile}
              ''}
            '';
          };
        };

        lockExtendWrapper = mkOption {
          type = types.package;
          internal = true;
          readOnly = true;
          default = pkgs.writeShellApplication {
            name = "lock-extend-wrapper";
            runtimeInputs = [ config.wrappers.conanWrapper ];
            text = ''
              conan-wrapper lock create . "$@" ${optionalString args.config.isLockDefined ''
                --lockfile=${escapeShellArg config.wrappers.conanLockFile} \
                --lockfile-out=${escapeShellArg config.wrappers.conanLockFile}
              ''}
            '';
          };
        };

        installBuildMissingWrapper = mkOption {
          type = types.package;
          internal = true;
          readOnly = true;
          default = pkgs.writeShellApplication {
            name = "install-build-missing-wrapper";
            runtimeInputs = [ config.wrappers.conanWrapper ];
            text = ''
              conan-wrapper install . "$@" --build=missing ${optionalString args.config.isLockDefined ''
                --lockfile=${escapeShellArg config.wrappers.conanLockFile}
              ''}
            '';
          };
        };

        createLockInstallWrapper = mkOption {
          type = types.package;
          internal = true;
          readOnly = true;
          default = pkgs.writeShellApplication {
            name = "create-lock-install-wrapper";
            runtimeInputs = [
              config.package
              pkgs.coreutils-full
            ];
            text = ''
              # shellcheck source=/dev/null
              source ${args.config.initEnvScript}
              cd "$CONAN_FLAKE_HOME"
              ${optionalString args.config.isLockDefined ''
                conan_lock="$(mktemp)"
                if [[ -f ${escapeShellArg args.config.conanLockFile} ]]
                then
                  conan_lock="$(mktemp)"
                  cp ${escapeShellArg args.config.conanLockFile} "$conan_lock"
                else
                  conan_lock="$(mktemp -u)"
                fi
                conan lock create . "$@" --lockfile-out="$conan_lock"
              ''}
              conan install . "$@" ${optionalString args.config.isLockDefined ''--lockfile="$conan_lock"''}
              ${optionalString args.config.isLockDefined ''cp "$conan_lock" ${escapeShellArg args.config.conanLockFile}''}
            '';
          };
        };

        conanInstall = mkOption {
          type = types.bool;
          description = ''
            Whether to run `conan install` automatically during shell activation.
            Defaults to `false`.
          '';
          default = false;
        };

        allWrapper = mkOption {
          type = types.package;
          internal = true;
          readOnly = true;
          default = pkgs.writeShellApplication {
            name = "all-wrapper";
            runtimeInputs = [ config.package ];
            text = ''
              # shellcheck source=/dev/null
              source ${args.config.initEnvScript}

              cd "$CONAN_FLAKE_HOME"

              ${cfg.preConfigInstallHook}

              conan config install "$CONAN_FLAKE_CONFIG"

              ${
                #
                optionalString args.config.isLockDefined ''
                  conan lock create . "$@" --lockfile-out=${escapeShellArg config.wrappers.conanLockFile}
                ''
              }

              ${
                #
                optionalString config.wrappers.conanInstall ''
                  conan install . "$@" --build=missing ${optionalString args.config.isLockDefined ''
                    --lockfile=${escapeShellArg config.wrappers.conanLockFile}
                  ''}
                ''
              }
            '';
          };
        };
      };
    }
  );
in
{
  options = {
    wrappers = mkOption {
      type = wrappersSubmodule;
      internal = true;
      # readOnly = true;
      default = { };
    };
  };

  config = {
    outputs.packages = {
      inherit (config.wrappers) infoWrapper;
      inherit (config.wrappers) configHomeWrapper;
      inherit (config.wrappers) runPreConfigInstallHookWrapper;
      inherit (config.wrappers) configInstallWrapper;
      inherit (config.wrappers) conanWrapper;
      inherit (config.wrappers) lockCreateWrapper;
      inherit (config.wrappers) lockExtendWrapper;
      inherit (config.wrappers) installBuildMissingWrapper;
      inherit (config.wrappers) createLockInstallWrapper;
      inherit (config.wrappers) allWrapper;
    };
  };
}
