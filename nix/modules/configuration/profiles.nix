# Definition of the `conan` submodule's `config`
{
  config,
  lib,
  pkgs,
  envSubmodule,
  ...
}:
let
  inherit (lib)
    filterAttrs
    mkOption
    types
    ;

  profilesSubmodule = types.submodule {
    options = {
      settings.compiler = mkOption {
        type = types.lazyAttrsOf (types.nullOr types.str);
        description = ''
          Profile [settings] section compiler properties. These are
          properties with names matching _compiler_ or _compiler.*_.

          These properties are merged with the conan-flake defaults defined
          in the `defaults.profiles.settings.compiler` option. Set the entry
          to `null` to remove that default.
        '';
        default = { };
      };

      settings.rest = mkOption {
        type = types.lazyAttrsOf (types.nullOr types.str);
        description = ''
          Profile [settings] section properties.

          These properties are merged with the conan-flake defaults defined
          in the `defaults.profiles.settings.rest` option. Set the entry to
          `null` to remove that default.
        '';
        default = { };
      };

      buildEnv = mkOption {
        type = types.listOf envSubmodule;
        description = ''
          Profile [buildenv] section.
        '';
        default = [ ];
      };

      runEnv = mkOption {
        type = types.listOf envSubmodule;
        description = ''
          Profile [runenv] section.
        '';
        default = [ ];
      };

      conf = mkOption {
        type = types.lazyAttrsOf (types.nullOr types.str);
        description = ''
          Profile [conf] section properties.

          These properties are merged with the conan-flake defaults defined
          in the `defaults.profiles.conf` option. Set the entry to `null` to
          remove that default.
        '';
        default = { };
      };

      platformToolRequires = mkOption {
        type = types.lazyAttrsOf (types.nullOr types.str);
        description = ''
          Profile [platform_tool_requires] section properties.

          These properties are merged with the conan-flake defaults defined
          in the `defaults.profiles.platformToolRequires` option. Set the
          entry to `null` to remove that default "require".
        '';
        default = { };
      };

      text = mkOption {
        type = types.package;
        description = ''
          The profile-outputing derivation generated for the configuration.
        '';
        defaultText = lib.literalExpression ''
          pkgs.writeText "profile" '''
            [settings]
            ''${lib.strings.concatMapAttrsStringSep "\n" (
              name: value: "''${name}=''${value}"
            ) final.profiles.settings.rest}
            ''${lib.strings.concatMapAttrsStringSep "\n" (
              name: value: "''${name}=''${value}"
            ) final.profiles.settings.compiler}

            [buildenv]
            ''${lib.strings.concatMapStringSep "\n" (
              x: "''${x.name}''${x.op}''${x.value}"
            ) profiles.buildEnv}

            [runenv]
            ''${lib.strings.concatMapStringSep "\n" (
              x: "''${x.name}''${x.op}''${x.value}"
            ) profiles.runEnv}

            [conf]
            ''${lib.strings.concatMapAttrsStringSep "\n" (
              name: value: "''${name}=''${value}"
            ) final.profiles.conf}

            [platform_tool_requires]
            ''${lib.strings.concatMapAttrsStringSep "\n" (
              name: value: "''${name}/''${value}"
            ) final.profiles.platformToolRequires}
          '''
        '';
        readOnly = true;
      };
    };
  };

  data = ''
    [settings]
    ${lib.strings.concatMapAttrsStringSep "\n" (
      name: value: "${name}=${value}"
    ) config.final.profiles.settings.rest}
    ${lib.strings.concatMapAttrsStringSep "\n" (
      name: value: "${name}=${value}"
    ) config.final.profiles.settings.compiler}

    [buildenv]
    ${lib.concatMapStringsSep "\n" (x: "${x.name}${x.op}${x.value}") config.profiles.buildEnv}

    [runenv]
    ${lib.concatMapStringsSep "\n" (x: "${x.name}${x.op}${x.value}") config.profiles.runEnv}

    [conf]
    ${lib.strings.concatMapAttrsStringSep "\n" (
      name: value: "${name}=${value}"
    ) config.final.profiles.conf}

    [platform_tool_requires]
    ${lib.strings.concatMapAttrsStringSep "\n" (
      name: value: "${name}/${value}"
    ) config.final.profiles.platformToolRequires}
  '';

  cfg = config.profiles;
in
{
  options = {
    profiles = mkOption {
      type = profilesSubmodule;
      description = ''
        Conan profiles.
      '';
    };

    final.profiles.settings.compiler = mkOption {
      type = types.lazyAttrsOf types.str;
      readOnly = true;
      description = ''
        Final configuration of profile [settings] section compiler properties.
      '';
    };

    final.profiles.settings.rest = mkOption {
      type = types.lazyAttrsOf types.str;
      readOnly = true;
      description = ''
        Final configuration of profile [settings] section properties.
      '';
    };

    final.profiles.conf = mkOption {
      type = types.lazyAttrsOf types.str;
      readOnly = true;
      description = ''
        Final configuration of profile [conf] section properties.
      '';
    };

    final.profiles.platformToolRequires = mkOption {
      type = types.lazyAttrsOf types.str;
      readOnly = true;
      description = ''
        Final configuration of profile [platform_tool_requires] section
        properties.
      '';
    };
  };

  config = {
    profiles = {
      text = pkgs.writeText "profile" data;
    };

    final.profiles.settings.compiler = filterAttrs (_: v: v != null) (
      config.defaults.profiles.settings.compiler // cfg.settings.compiler
    );

    final.profiles.settings.rest = filterAttrs (_: v: v != null) (
      config.defaults.profiles.settings.rest // cfg.settings.rest
    );

    final.profiles.conf = filterAttrs (_: v: v != null) (config.defaults.profiles.conf // cfg.conf);

    final.profiles.platformToolRequires = filterAttrs (_: v: v != null) (
      config.defaults.profiles.platformToolRequires // cfg.platformToolRequires
    );

    wrappers.preConfigInstallHook = ''
      #
      mkdir -p "$CONAN_FLAKE_CONFIG/profiles"
      ln -sf ${config.outputs.packages.configuration}/config/profiles/default "$CONAN_FLAKE_CONFIG/profiles/default"
    '';

    outputs = {
      configuration.profile = {
        package = cfg.text;
        manifest = "config/profiles/default";
        kind = "configuration";
      };
    };
  };
}
