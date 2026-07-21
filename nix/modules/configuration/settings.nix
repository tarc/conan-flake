# Definition of the `conan` submodule's `config`
{
  config,
  lib,
  pkgs,
  infuse,
  ...
}:
let
  inherit (lib)
    filterAttrs
    mkOption
    types
    ;

  settingsSubmodule = types.submodule {
    options = {
      compiler = mkOption {
        type = types.attrs;
        description = ''
          Conan user settings compiler properties (compiler section in
          `settings_user.yml`).
        '';
        default = { };
      };

      core = mkOption {
        type = types.attrs;
        description = ''
          Conan `global.conf` core properties (configuration variables matching
          the "core.*" pattern).
        '';
        default = { };
      };

      tools = mkOption {
        type = types.attrs;
        description = ''
          Conan `global.conf` tools properties (configuration variables
          matching the "tools.*" pattern).
        '';
        default = { };
      };

      user = mkOption {
        type = types.attrs;
        description = ''
          Conan `global.conf` user properties (configuration variables matching
          the "user.*" pattern).
        '';
        default = { };
      };

      settingsUserYamlData = mkOption {
        type = types.package;
        description = ''
          The YAML-outputing derivation generated for the user configuration.
        '';
        defaultText = lib.literalExpression ''
          (pkgs.formats.yaml { }).generate "settings_user.yml" final.settings.compiler
        '';
        readOnly = true;
      };

      globalConfData = mkOption {
        type = types.package;
        description = ''
          The conf-outputing derivation generated for the global configuration.
        '';
        defaultText = lib.literalExpression ''
          pkgs.writeText "profile" '''
            ''${lib.strings.concatMapAttrsStringSep "\n" (
              name: value: "core.''${name}=''${value}"
            ) final.settings.core}
            ''${lib.strings.concatMapAttrsStringSep "\n" (
              name: value: "tools.''${name}=''${value}"
            ) final.settings.tools}
            ''${lib.strings.concatMapAttrsStringSep "\n" (
              name: value: "user.''${name}=''${value}"
            ) final.settings.user}
        '';
        readOnly = true;
      };
    };
  };

  globalConfData = ''
    ${lib.strings.concatMapAttrsStringSep "\n" (
      name: value: "core.${name}=${value}"
    ) config.final.settings.core}
    ${lib.strings.concatMapAttrsStringSep "\n" (
      name: value: "tools.${name}=${value}"
    ) config.final.settings.tools}
    ${lib.strings.concatMapAttrsStringSep "\n" (
      name: value: "user.${name}=${value}"
    ) config.final.settings.user}
  '';
in
{
  options = {
    settings = mkOption {
      type = settingsSubmodule;
      description = ''
        Conan user settings (`settings_user.yml`).
      '';
    };

    final.settings = {
      compiler = mkOption {
        type = types.attrs;
        readOnly = true;
        description = ''
          Final state of Conan user settings compiler properties (compiler
          section in `settings_user.yml`).
        '';
      };

      core = mkOption {
        type = types.attrs;
        readOnly = true;
        description = ''
          Final state of Conan `global.conf` core properties (configuration
          variables matching the "core.*" pattern).
        '';
      };

      tools = mkOption {
        type = types.attrs;
        readOnly = true;
        description = ''
          Final state of Conan `global.conf` tools properties (configuration
          variables matching the "tools.*" pattern).
        '';
      };

      user = mkOption {
        type = types.attrs;
        readOnly = true;
        description = ''
          Final state of Conan `global.conf` user properties (configuration
          variables matching the "user.*" pattern).
        '';
      };
    };
  };

  config = {
    settings.settingsUserYamlData = (pkgs.formats.yaml { }).generate "settings_user.yml" {
      inherit (config.final.settings) compiler;
    };

    settings.globalConfData = pkgs.writeText "global.conf" globalConfData;

    final.settings = {
      compiler = filterAttrs (_: v: v != null) (
        infuse config.defaults.settings.compiler config.settings.compiler
      );
      core = filterAttrs (_: v: v != null) (config.defaults.settings.core // config.settings.core);
      tools = filterAttrs (_: v: v != null) (config.defaults.settings.tools // config.settings.tools);
      user = filterAttrs (_: v: v != null) (config.defaults.settings.user // config.settings.user);
    };

    wrappers.preConfigInstallHook = ''
      #
      mkdir -p "$CONAN_FLAKE_CONFIG"
      ln -sf ${config.outputs.packages.configuration}/config/settings_user.yml "$CONAN_FLAKE_CONFIG/settings_user.yml"
      ln -sf ${config.outputs.packages.configuration}/config/global.conf "$CONAN_FLAKE_CONFIG/global.conf"
    '';

    outputs = {
      configuration = {
        settingsUser = {
          package = config.settings.settingsUserYamlData;
          manifest = "config/settings_user.yml";
          kind = "configuration";
        };
        globalConf = {
          package = config.settings.globalConfData;
          manifest = "config/global.conf";
          kind = "configuration";
        };
      };
    };
  };
}
