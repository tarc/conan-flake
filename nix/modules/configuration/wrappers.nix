# Definition of the `conan` submodule's `config`
{
  pkgs,
  lib,
  config,
  relativePathType,
  ...
}:
let
  inherit (lib) mkOption optionalString types;
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

        infoWrapper = mkOption {
          type = types.package;
          internal = true;
          readOnly = true;
          default = pkgs.writeShellApplication {
            name = "info-wrapper";
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
                ${lib.getExe config.package} remote list
                ${lib.getExe config.package} profile list
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
