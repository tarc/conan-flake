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
          The YAML-outputing derivation generated for the user configuration.
        '';
        defaultText = lib.literalExpression ''
          (pkgs.formats.yaml { }).generate "settings_user.yml" final.settings.compiler
        '';
        readOnly = true;
      };
    };
  };
in
{
  options = {
    settings = mkOption {
      type = settingsSubmodule;
      description = ''
        Conan user settings (`settings_user.yml`).
      '';
    };

    final.settings.compiler = mkOption {
      type = types.attrs;
      readOnly = true;
      description = ''
        Final state of Conan user settings compiler properties (compiler
        section in `settings_user.yml`).
      '';
    };
  };

  config = {
    settings.settingsUserYamlData = (pkgs.formats.yaml { }).generate "settings_user.yml" {
      inherit (config.final.settings) compiler;
    };

    settings.globalConfData = (pkgs.formats.yaml { }).generate "global.conf" {
      inherit (config.final.settings) compiler;
    };

    final.settings.compiler = filterAttrs (_: v: v != null) (
      infuse config.defaults.settings.compiler config.settings.compiler
    );

    wrappers.preConfigInstallHook = ''
      #
      mkdir -p "$CONAN_FLAKE_CONFIG"
      ln -sf ${config.outputs.packages.configuration}/config/settings_user.yml "$CONAN_FLAKE_CONFIG/settings_user.yml"
      ln -sf ${config.outputs.packages.configuration}/config/global.conf "$CONAN_FLAKE_CONFIG/_global.conf"
    '';

    outputs = {
      configuration = {
        settingsUser = {
          package = config.settings.settingsUserYamlData;
          manifest = "config/settings_user.yml";
          kind = "configuration";
        };
        globalConf = {
          package = config.settings.settingsUserYamlData;
          manifest = "config/global.conf";
          kind = "configuration";
        };
      };
    };
  };
}
