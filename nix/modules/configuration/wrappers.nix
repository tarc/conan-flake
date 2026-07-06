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

        infoWrapperOutput = mkOption {
          type = types.str;
          internal = true;
          readOnly = true;
          default = "conan-flake.lock";
        };

        infoWrapperStdoutOutput = mkOption {
          type = types.bool;
          internal = true;
          readOnly = true;
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
                # shellcheck disable=SC2034
                jq -n \
                    --argjson remotes "$(conan remote list --format json)" \
                    --argjson profiles "$(conan profile list --format json)" \
                    '{remotes: $remotes, profiles: $profiles}' \
                  | tee ${escapeShellArg args.config.infoWrapperOutput} \
                  | xargs -0 printf "%s\n" \
                  | jq -r '.profiles | to_entries[] | "\(.value) [\(.key)]"' \
                  | sort \
                  | while read -r profile key; do
                      profile_object="$(conan profile show -pr "$profile" --format json)"
                      jq \
                          --argjson name "\"$profile\"" \
                          --argjson profile "$profile_object" \
                          '._profiles += {$name: $profile}' \
                          ${escapeShellArg args.config.infoWrapperOutput} \
                        | sponge ${escapeShellArg args.config.infoWrapperOutput}
                    done
                jq --arg prefix "$CONAN_FLAKE_ROOT" '
                    .remotes |= map(
                        if ((.url | startswith("http://")) or (.url | startswith("https://"))) | not
                        then .url |= sub($prefix; ".")
                        else .
                        end
                    )
                ' ${escapeShellArg args.config.infoWrapperOutput} \
                  | sponge ${escapeShellArg args.config.infoWrapperOutput}
                ${optionalString (args.config.infoWrapperStdoutOutput) "cat ${escapeShellArg args.config.infoWrapperOutput} | jq '.'"}
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
            text = ''
              # shellcheck source=/dev/null
              source ${args.config.initEnvScript}
              cd "$CONAN_FLAKE_HOME"
              ${lib.getExe config.package} "$*"
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
    };
  };
}
