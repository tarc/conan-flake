# Definition of the `conan` submodule's `config`
configuration@{
  config,
  lib,
  pkgs,
  envSubmodule,
  finalEnvSubmodule,
  ...
}:
let
  inherit (lib)
    attrNames
    concatMapStrings
    escapeShellArg
    filterAttrs
    mapAttrs
    mapAttrs'
    mkOption
    nameValuePair
    types
    ;

  # Closes profile.nix's outer stage over pkgs/envSubmodule/lib, so that
  # `profiles`' `deferredModuleWith staticModules` below can walk its
  # `options` for doc-generation purposes without needing a concrete profile
  # to evaluate (see profile.nix's own comment).
  profileModule = import ./profile.nix { inherit lib pkgs envSubmodule; };

  # The read-only view of the merged entries of a profile. Its entry types
  # mirror the ones of the profile itself, minus the `null` marker, which the
  # merge consumes.
  finalProfileSubmodule = types.submodule {
    options = {
      settings = mkOption {
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

      buildEnv = mkOption {
        type = types.listOf finalEnvSubmodule;
        readOnly = true;
        description = ''
          Final configuration of profile [buildenv] section entries.
        '';
      };

      runEnv = mkOption {
        type = types.listOf finalEnvSubmodule;
        readOnly = true;
        description = ''
          Final configuration of profile [runenv] section entries.
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

  # The same merge for the `[buildenv]`/`[runenv]` sections, which are lists
  # rather than attribute sets (see `envSubmodule`). An entry is identified by
  # its `name`: a profile entry replaces the default entry of the same name,
  # and a `null` value removes it, contributing no line of its own.
  #
  # Defaults keep their relative order and come first, followed by the
  # profile's own entries in their declared order, because Conan applies the
  # operators of a section in file order. An attribute set could not express
  # this: `attrValues` would reorder the entries alphabetically by name.
  #
  # profile.PROFILE.2
  # profile.FINAL.2
  mergeDefaultsEnv =
    defaults: profileEntries:
    let
      replaced = map (entry: entry.name) profileEntries;
      kept = builtins.filter (entry: !(builtins.elem entry.name replaced)) defaults;
    in
    builtins.filter (entry: entry.value != null) (kept ++ profileEntries);

  # `profiles` is typed as a `deferredModule`, not a `submodule`: each
  # profile's value is deferred module configuration, evaluated here, one
  # profile at a time, exactly as `types.submodule` would otherwise do for
  # each `profiles.<name>` attribute, `name` special arg included.
  evalProfile =
    name: deferred:
    (lib.evalModules {
      modules = [ deferred ];
      specialArgs = {
        inherit name;
        inherit (configuration.config) final;
      };
    }).config;

  cfg = mapAttrs evalProfile config.profiles;
in
{
  options = {
    # multiple-profiles.PROFILES.1
    # profile.PROFILE.1
    profiles = mkOption {
      type = types.lazyAttrsOf (types.deferredModuleWith { staticModules = [ profileModule ]; });
      description = ''
        Conan profiles.

        Each attribute of this set defines one Conan profile, named after its
        attribute name. A profile named `default` is always present.
      '';
      default = { };
      example = lib.literalExpression ''
        {
          default.settings.build_type = "Release";
          debug.settings.build_type = "Debug";
        }
      '';
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
      settings = mergeDefaults config.defaults.profiles.settings profile.settings;
      options = mergeDefaults config.defaults.profiles.options profile.options;
      toolRequires = mergeDefaults config.defaults.profiles.toolRequires profile.toolRequires;
      conf = mergeDefaults config.defaults.profiles.conf profile.conf;
      replaceRequires = mergeDefaults config.defaults.profiles.replaceRequires profile.replaceRequires;
      replaceToolRequires = mergeDefaults config.defaults.profiles.replaceToolRequires profile.replaceToolRequires;
      platformRequires = mergeDefaults config.defaults.profiles.platformRequires profile.platformRequires;
      platformToolRequires = mergeDefaults config.defaults.profiles.platformToolRequires profile.platformToolRequires;
      buildEnv = mergeDefaultsEnv config.defaults.profiles.buildEnv profile.buildEnv;
      runEnv = mergeDefaultsEnv config.defaults.profiles.runEnv profile.runEnv;
    }) cfg;

    # multiple-profiles.PROFILES.3-1
    wrappers.preConfigInstallHook = ''
      #
      mkdir -p "$CONAN_FLAKE_CONFIG/profiles"
      ${concatMapStrings (name: ''
        ln -sf ${escapeShellArg "${config.outputs.packages.configuration}/config/profiles/${name}"} "$CONAN_FLAKE_CONFIG/profiles/"${escapeShellArg name}
      '') (attrNames cfg)}
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
        manifest = "config/profiles/${key}";
        kind = "configuration";
      }
    ) cfg;
  };
}
