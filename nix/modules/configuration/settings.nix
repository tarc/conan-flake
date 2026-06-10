# Definition of the `conan` submodule's `config`
{ config, lib, pkgs, infuse, ... }:
let
  inherit (lib)
    filterAttrs
    mkOption
    types;

  settingsSubmodule = types.submodule (
    {
      options = {
        compiler = mkOption {
          type = types.attrs;
          description = ''
            Conan user settings compiler properties (compiler section in
            `settings_user.yml`).
          '';
          default = { };
        };

        yaml = mkOption {
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
    }
  );
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
    settings.yaml = (pkgs.formats.yaml { }).generate "settings_user.yml" {
      inherit (config.final.settings) compiler;
    };

    final.settings.compiler = filterAttrs (_: v: v != null)
      (infuse config.defaults.settings.compiler config.settings.compiler);

    outputs = {
      configuration.settings = {
        package = config.settings.yaml;
        manifest = "config/settings_user.yml";
        kind = "configuration";
      };

      commands.settings = {
        enterShell = lib.mkBefore ''
          #
          mkdir -p ${lib.escapeShellArg config.configLocal}
          ln -sf ${config.outputs.packages.configuration}/config/settings_user.yml ${lib.escapeShellArg config.configLocal}/settings_user.yml
        '';
        kind = "configuration";
      };
    };
  };
}
