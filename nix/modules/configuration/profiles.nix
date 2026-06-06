# Definition of the `conan` submodule's `config`
{ config, lib, pkgs, envSubmodule, ... }:
let
  inherit (lib)
    mkOption
    types;

  profilesSubmodule = types.submodule (
    { name, config, ... }:
    let
      data = ''
        [settings]
        ${lib.strings.concatMapAttrsStringSep "\n" (
          name: value: "${name}=${value}"
        ) config.settings}

        [buildenv]
        ${lib.concatMapStringsSep "\n" (
          x: "${x.name}${x.op}${x.value}"
        ) config.buildEnv}

        [runenv]
        ${lib.concatMapStringsSep "\n" (
          x: "${x.name}${x.op}${x.value}"
        ) config.runEnv}

        [conf]
        ${lib.strings.concatMapAttrsStringSep "\n" (
          name: value: "${name}=${value}"
        ) config.conf}

        [platform_tool_requires]
        ${lib.strings.concatMapAttrsStringSep "\n" (
          name: value: "${name}/${value}"
        ) config.platformToolRequires}
      '';
    in
    {
      options = {
        settings = mkOption {
          type = types.attrsOf types.str;
          description = ''Profile settings.'';
          default = { };
        };

        buildEnv = mkOption {
          type = types.listOf envSubmodule;
          description = ''Profile buildenv.'';
          default = [ ];
        };

        runEnv = mkOption {
          type = types.listOf envSubmodule;
          description = ''Profile runenv.'';
          default = [ ];
        };

        conf = mkOption {
          type = types.attrsOf types.str;
          description = ''Profile conf.'';
          default = { };
        };

        platformToolRequires = mkOption {
          type = types.attrsOf types.str;
          description = ''Profile platform tool requires.'';
          default = { };
        };

        text = mkOption {
          type = types.package;
          description = ''
            The profile-outputing derivation generated for the configuration.
          '';
          default = pkgs.writeText "profile" data;
          defaultText = lib.literalExpression ''
            pkgs.writeText "profile" '''
              [settings]
              ''${lib.strings.concatMapAttrsStringSep "\n" (
                name: value: "''${name}=''${value}"
              ) config.settings}

              [buildenv]
              ''${lib.strings.concatMapStringSep "\n" (
                x: "''${x.name}''${x.op}''${x.value}"
              ) config.buildEnv}

              [runenv]
              ''${lib.strings.concatMapStringSep "\n" (
                x: "''${x.name}''${x.op}''${x.value}"
              ) config.runEnv}

              [conf]
              ''${lib.strings.concatMapAttrsStringSep "\n" (
                name: value: "''${name}=''${value}"
              ) config.conf}

              [platform_tool_requires]
              ''${lib.strings.concatMapAttrsStringSep "\n" (
                name: value: "''${name}/''${value}"
              ) config.platformToolRequires}
            '''
          '';
          readOnly = true;
        };
      };
    }
  );
in
{
  options.profiles = mkOption {
    type = profilesSubmodule;
    description = ''
      Conan profiles.
    '';
  };
  config = {
    outputs = {
      configuration.profile = {
        package = config.profiles.text;
        manifest = "config/profiles/default";
        kind = "configuration";
      };

      commands.profile = {
        enterShell = lib.mkBefore ''
          #
          mkdir -p ${lib.escapeShellArg config.configLocal}/profiles
          ln -sf ${config.outputs.packages.configuration}/config/profiles/default ${lib.escapeShellArg config.configLocal}/profiles/default
        '';
        kind = "configuration";
      };
    };
  };
}
