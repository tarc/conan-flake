# conan.profiles.<name> module.
{
  configuration,
  lib,
  pkgs,
  envSubmodule,
  ...
}:
let
  inherit (lib) mkOption types;
in
{ name, config, ... }:
let
  # The attribute name this profile is defined under, as opposed to
  # `config.name`, which is the (possibly overridden) Conan profile name.
  key = name;

  # The final (defaults-merged) values of this very profile, as exposed by the
  # read-only `final.profiles.<key>` options.
  final = configuration.config.final.profiles.${key};

  data = ''
    [settings]
    ${lib.strings.concatMapAttrsStringSep "\n" (name: value: "${name}=${value}") final.settings._}
    ${lib.strings.concatMapAttrsStringSep "\n" (
      name: value: "${name}=${value}"
    ) final.settings.compiler}

    [buildenv]
    ${lib.concatMapStringsSep "\n" (x: "${x.name}${x.op}${x.value}") config.buildEnv}

    [runenv]
    ${lib.concatMapStringsSep "\n" (x: "${x.name}${x.op}${x.value}") config.runEnv}

    [conf]
    ${lib.strings.concatMapAttrsStringSep "\n" (name: value: "${name}=${value}") final.conf}

    [platform_tool_requires]
    ${lib.strings.concatMapAttrsStringSep "\n" (
      name: value: "${name}/${value}"
    ) final.platformToolRequires}
  '';
in
{
  options = {
    # multiple-profiles.PROFILES.1
    name = mkOption {
      type = types.nonEmptyStr;
      description = ''
        Name of the Conan profile.

        Defaults to the attribute name of this profile, and is the file name
        used for the generated Conan profile.
      '';
      default = key;
      defaultText = lib.literalMD "profile's attribute name";
    };

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

    settings._ = mkOption {
      type = types.lazyAttrsOf (types.nullOr types.str);
      description = ''
        Profile [settings] section properties.

        These properties are merged with the conan-flake defaults defined
        in the `defaults.profiles.settings._` option. Set the entry to
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
        pkgs.writeText "conan-profile-''${profiles.''${name}.name}" '''
          [settings]
          ''${lib.strings.concatMapAttrsStringSep "\n" (
            name: value: "''${name}=''${value}"
          ) final.profiles.''${name}.settings._}
          ''${lib.strings.concatMapAttrsStringSep "\n" (
            name: value: "''${name}=''${value}"
          ) final.profiles.''${name}.settings.compiler}

          [buildenv]
          ''${lib.strings.concatMapStringSep "\n" (
            x: "''${x.name}''${x.op}''${x.value}"
          ) profiles.''${name}.buildEnv}

          [runenv]
          ''${lib.strings.concatMapStringSep "\n" (
            x: "''${x.name}''${x.op}''${x.value}"
          ) profiles.''${name}.runEnv}

          [conf]
          ''${lib.strings.concatMapAttrsStringSep "\n" (
            name: value: "''${name}=''${value}"
          ) final.profiles.''${name}.conf}

          [platform_tool_requires]
          ''${lib.strings.concatMapAttrsStringSep "\n" (
            name: value: "''${name}/''${value}"
          ) final.profiles.''${name}.platformToolRequires}
        '''
      '';
      readOnly = true;
    };
  };

  config = {
    # The Conan profile name is part of the derivation name so that a
    # multi-profile configuration does not build several indistinguishable
    # `profile.drv`s.
    text = pkgs.writeText "conan-profile-${config.name}" data;
  };
}
