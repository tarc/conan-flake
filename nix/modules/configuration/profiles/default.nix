# Definition of the `conan` submodule's `config`
configuration@{
  config,
  lib,
  pkgs,
  envSubmodule,
  ...
}:
let
  inherit (lib)
    attrValues
    concatMapStrings
    escapeShellArg
    filterAttrs
    mapAttrs
    mapAttrs'
    mkOption
    nameValuePair
    types
    ;

  profileSubmodule = import ./profile.nix {
    inherit
      configuration
      lib
      pkgs
      envSubmodule
      ;
  };

  # The read-only view of the merged entries of a profile. Its entry types
  # mirror the ones of the profile itself, minus the `null` marker, which the
  # merge consumes.
  finalProfileSubmodule = types.submodule {
    options = {
      settings.compiler = mkOption {
        type = types.lazyAttrsOf types.str;
        readOnly = true;
        description = ''
          Final configuration of profile [settings] section compiler properties.
        '';
      };

      settings._ = mkOption {
        type = types.lazyAttrsOf types.str;
        readOnly = true;
        description = ''
          Final configuration of profile [settings] section properties.
        '';
      };

      options = mkOption {
        type = types.lazyAttrsOf types.str;
        readOnly = true;
        description = ''
          Final configuration of profile [options] section properties.
        '';
      };

      toolRequires = mkOption {
        type = types.lazyAttrsOf types.str;
        readOnly = true;
        description = ''
          Final configuration of profile [tool_requires] section properties.
        '';
      };

      conf = mkOption {
        type = types.lazyAttrsOf types.str;
        readOnly = true;
        description = ''
          Final configuration of profile [conf] section properties.
        '';
      };

      replaceRequires = mkOption {
        type = types.lazyAttrsOf types.str;
        readOnly = true;
        description = ''
          Final configuration of profile [replace_requires] section
          properties.
        '';
      };

      replaceToolRequires = mkOption {
        type = types.lazyAttrsOf types.str;
        readOnly = true;
        description = ''
          Final configuration of profile [replace_tool_requires] section
          properties.
        '';
      };

      platformRequires = mkOption {
        type = types.lazyAttrsOf types.str;
        readOnly = true;
        description = ''
          Final configuration of profile [platform_requires] section
          properties.
        '';
      };

      platformToolRequires = mkOption {
        type = types.lazyAttrsOf types.str;
        readOnly = true;
        description = ''
          Final configuration of profile [platform_tool_requires] section
          properties.
        '';
      };
    };
  };

  # The conan-flake defaults are a single, global set of profile defaults
  # merged into every profile. Entries set to `null` in the profile remove the
  # corresponding default.
  #
  # profile.PROFILE.2
  # profile.FINAL.2
  mergeDefaults = defaults: profileAttrs: filterAttrs (_: v: v != null) (defaults // profileAttrs);

  cfg = config.profiles;
in
{
  options = {
    # multiple-profiles.PROFILES.1
    profiles = mkOption {
      type = types.lazyAttrsOf (types.submodule profileSubmodule);
      description = ''
        Conan profiles.

        Each attribute of this set defines one Conan profile, named after its
        attribute name unless the `name` option is set. A profile named
        `default` is always present.
      '';
      default = { };
      example = lib.literalExpression ''
        {
          default.settings._.build_type = "Release";
          debug.settings._.build_type = "Debug";
        }'';
    };

    final.profiles = mkOption {
      type = types.lazyAttrsOf finalProfileSubmodule;
      readOnly = true;
      description = ''
        Final configuration of each Conan profile, that is, the profile
        properties merged with the conan-flake defaults.
      '';
    };
  };

  config = {
    # multiple-profiles.PROFILES.2
    profiles.default = { };

    # profile.FINAL.1
    final.profiles = mapAttrs (_: profile: {
      settings.compiler = mergeDefaults config.defaults.profiles.settings.compiler profile.settings.compiler;
      settings._ = mergeDefaults config.defaults.profiles.settings._ profile.settings._;
      options = mergeDefaults config.defaults.profiles.options profile.options;
      toolRequires = mergeDefaults config.defaults.profiles.toolRequires profile.toolRequires;
      conf = mergeDefaults config.defaults.profiles.conf profile.conf;
      replaceRequires = mergeDefaults config.defaults.profiles.replaceRequires profile.replaceRequires;
      replaceToolRequires = mergeDefaults config.defaults.profiles.replaceToolRequires profile.replaceToolRequires;
      platformRequires = mergeDefaults config.defaults.profiles.platformRequires profile.platformRequires;
      platformToolRequires = mergeDefaults config.defaults.profiles.platformToolRequires profile.platformToolRequires;
    }) cfg;

    # multiple-profiles.PROFILES.3-1
    wrappers.preConfigInstallHook = ''
      #
      mkdir -p "$CONAN_FLAKE_CONFIG/profiles"
      ${concatMapStrings (profile: ''
        ln -sf ${escapeShellArg "${config.outputs.packages.configuration}/config/profiles/${profile.name}"} "$CONAN_FLAKE_CONFIG/profiles/"${escapeShellArg profile.name}
      '') (attrValues cfg)}
    '';

    # multiple-profiles.PROFILES.3
    #
    # The `profile_` prefix keeps profile entries in their own namespace within
    # `outputs.configuration`, whose keys are shared with the other
    # configuration producers (`setup`, `settingsUser`, `global`, ...): without
    # it, a profile named `global` would silently replace `global.conf`.
    outputs.configuration = mapAttrs' (
      key: profile:
      nameValuePair "profile_${key}" {
        package = profile.text;
        manifest = "config/profiles/${profile.name}";
        kind = "configuration";
      }
    ) cfg;
  };
}
