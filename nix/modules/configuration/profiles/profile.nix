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

  # The profile file is rendered from the final (defaults-merged) values of this
  # very profile, as exposed by the read-only `final.profiles.<key>` options,
  # never from the profile's own (unmerged) values.
  #
  # profile.PROFILE_FILE.1
  final = configuration.config.final.profiles.${key};

  # Profile entries are typed lazily, so that the actual type of an entry is
  # only determined when that very entry is used, and `null` is accepted as the
  # marker removing the corresponding default entry.
  #
  # profile.PROFILE.1
  # profile.PROFILE.2
  entriesType = types.lazyAttrsOf (types.nullOr types.str);

  # Entries rendered as `name=value`, one entry per line.
  #
  # profile.SETTINGS.2
  # profile.CONF.2
  assignments = lib.strings.concatMapAttrsStringSep "\n" (name: value: "${name}=${value}");

  # Entries rendered as `name/value`, one entry per line.
  #
  # profile.PLATFORM_TOOL_REQUIRES.2
  requires = lib.strings.concatMapAttrsStringSep "\n" (name: value: "${name}/${value}");

  # Environment entries rendered as `name<op>value`, one entry per line. The
  # default `op` is `=`; Conan's remaining buildenv/runenv operators (`+=`,
  # `=+`, ...) are an extension of the very same rendering.
  #
  # profile.BUILDENV.2
  # profile.RUNENV.2
  environment = lib.concatMapStringsSep "\n" (x: "${x.name}${x.op}${x.value}");

  # profile.SETTINGS.1
  settingsSection = ''
    [settings]
    ${assignments final.settings._}
    ${assignments final.settings.compiler}
  '';

  # profile.BUILDENV.1
  buildEnvSection = ''
    [buildenv]
    ${environment config.buildEnv}
  '';

  # profile.RUNENV.1
  runEnvSection = ''
    [runenv]
    ${environment config.runEnv}
  '';

  # profile.CONF.1
  confSection = ''
    [conf]
    ${assignments final.conf}
  '';

  # profile.PLATFORM_TOOL_REQUIRES.1
  platformToolRequiresSection = ''
    [platform_tool_requires]
    ${requires final.platformToolRequires}
  '';

  # The profile file is the sequence of its sections, each one starting with its
  # own header line.
  #
  # profile.PROFILE_FILE.2
  # profile.PROFILE_FILE.2-1
  data = lib.concatStringsSep "\n" [
    # profile.PROFILE_FILE.3
    settingsSection
    # profile.PROFILE_FILE.6
    buildEnvSection
    # profile.PROFILE_FILE.7
    runEnvSection
    # profile.PROFILE_FILE.8
    confSection
    # profile.PROFILE_FILE.12
    platformToolRequiresSection
  ];
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
      type = entriesType;
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
      type = entriesType;
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
      type = entriesType;
      description = ''
        Profile [conf] section properties.

        These properties are merged with the conan-flake defaults defined
        in the `defaults.profiles.conf` option. Set the entry to `null` to
        remove that default.
      '';
      default = { };
    };

    platformToolRequires = mkOption {
      type = entriesType;
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
      # NOTE: keep in sync with `data` above: this is the published
      # documentation of the very rendering `data` performs.
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
          ''${lib.concatMapStringsSep "\n" (
            x: "''${x.name}''${x.op}''${x.value}"
          ) profiles.''${name}.buildEnv}

          [runenv]
          ''${lib.concatMapStringsSep "\n" (
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
