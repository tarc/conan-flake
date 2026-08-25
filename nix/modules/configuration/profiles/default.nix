# Definition of the `conan` submodule's `config`
configuration@{
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

  # Drops the `null`-marker entries left in an attribute-set-shaped section
  # once the module system has already resolved which of a default entry and
  # a profile entry of the same name wins (native option priority, defaults.
  # PROFILE.2): a profile entry assigning `null` removes the corresponding
  # default from the rendered profile file. The merge itself does not happen
  # here -- `evalProfile` already performed it, by importing
  # `defaults.profiles` and the profile's own value into the same
  # `evalModules` call.
  #
  # profile.PROFILE.2
  # profile.FINAL.2
  filterNulls = filterAttrs (_: v: v != null);

  # `[buildenv]`/`[runenv]` entries are a list, not an attribute set: unlike
  # `lazyAttrsOf`, where each attribute is its own option and per-entry
  # `mkDefault` (defaults.PROFILE.2) is exactly what is needed, `listOf` is a
  # single option whose priority is all-or-nothing. Importing
  # `defaults.profiles` into the very same `evalModules` call as a profile's
  # own value, the way the attribute-set-shaped sections are merged, would
  # therefore either concatenate both lists unconditionally (no way for a
  # profile entry to replace a default entry of the same `name`, nor for
  # `null` to remove one) or -- if the defaults were `mkDefault`-wrapped --
  # discard the *entire* defaults list the moment a profile declares any
  # `buildEnv`/`runEnv` entry of its own, which is worse.
  #
  # So these two sections keep the pre-`deferredModule` two-source merge
  # instead: `resolvedDefaults.buildEnv`/`.runEnv` (evaluated once, with no
  # specific profile's value mixed in) against each profile's own,
  # `defaults.profiles`-free evaluation (`ownProfile`, below) -- a default
  # entry is replaced (not merged) by a profile entry of the same `name`;
  # entries the profile leaves alone keep their relative order and come
  # first; a profile's own entries are otherwise untouched, so declaring the
  # same `name` twice (a normal Conan idiom, e.g. `PATH=(path)/a` followed by
  # `PATH+=(path)/b`) is preserved.
  #
  # profile.PROFILE.2
  # profile.FINAL.2
  # profile.BUILDENV.3
  # profile.BUILDENV.4
  # profile.RUNENV.3
  # profile.RUNENV.4
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
      modules = [
        ./profile.nix
        configuration.config.defaults.profiles
        deferred
      ];
      specialArgs = {
        inherit name pkgs envSubmodule;
        inherit (configuration.config) final;
      };
    }).config;

  # WARNING: `cfg.<name>.buildEnv`/`.runEnv` are a plain, unfiltered
  # concatenation of `defaults.profiles`' list and the profile's own (see the
  # comment on `mergeDefaultsEnv` above for why that is not the merge these
  # two sections need) -- they are never read anywhere below; `final.profiles`
  # goes through `mergeDefaultsEnv`/`ownCfg`/`resolvedDefaults` instead, and
  # `text`'s rendering reads `final`, never `cfg` directly.
  cfg = mapAttrs evalProfile configuration.config.profiles;

  # Each profile's own `buildEnv`/`runEnv`, evaluated without
  # `defaults.profiles` mixed in, so `mergeDefaultsEnv` can tell a profile's
  # own entries apart from the defaults' (see the comment on
  # `mergeDefaultsEnv` above). `name`/`final` are still required by
  # `./profile.nix`'s module signature, but neither `buildEnv` nor `runEnv`
  # ever reference them (only `text`'s `config` does), so forcing just these
  # two fields never forces `name`/`final` either.
  evalOwnProfile =
    name: deferred:
    (lib.evalModules {
      modules = [
        ./profile.nix
        deferred
      ];
      specialArgs = {
        inherit name pkgs envSubmodule;
        inherit (configuration.config) final;
      };
    }).config;

  ownCfg = mapAttrs evalOwnProfile configuration.config.profiles;

  # `defaults.profiles`' own `buildEnv`/`runEnv`, evaluated once, with no
  # specific profile mixed in -- see the comment on `mergeDefaultsEnv` above.
  # `name`/`final` are placeholders for the same reason as `evalOwnProfile`'s:
  # neither field ever forces them.
  resolvedDefaults =
    (lib.evalModules {
      modules = [
        ./profile.nix
        configuration.config.defaults.profiles
      ];
      specialArgs = {
        name = "defaults";
        inherit pkgs envSubmodule;
        final = null;
      };
    }).config;
in
{
  options = {
    # multiple-profiles.PROFILES.1
    # profile.PROFILE.1
    profiles = mkOption {
      type = types.lazyAttrsOf types.deferredModule;
      description = ''
        Conan profiles.

        Each attribute of this set defines one Conan profile, named after its
        attribute name. A profile named `default` is always present.

        Each profile accepts `settings`, `options`, `toolRequires`, `buildEnv`,
        `runEnv`, `conf`, `replaceRequires`, `replaceToolRequires`,
        `platformRequires` and `platformToolRequires` (see profile.nix, whose
        own option declarations describe each section's shape and rendering
        in detail). `profiles` is a `deferredModule`, which has no
        discoverable sub-options of its own, so every section is demonstrated
        below rather than left to be found on a per-option reference page.
      '';
      default = { };
      example = lib.literalExpression ''
        {
          default.settings.build_type = "Release";

          debug.settings.build_type = "Debug";

          settingsEx.settings = {
            arch = "x86_64";
            build_type = "Release";
            compiler = "apple-clang";
            "compiler.cppstd" = "gnu17";
            "compiler.libcxx" = "libc++";
            "compiler.version" = "14";
            os = "Macos";
          };

          buildEnvEx.buildEnv = [
            # Rendered as `CFLAGS=-O2`.
            {
              name = "CFLAGS";
              value = "-O2";
            }
            # Rendered as `PATH+=(path)/opt/bin`.
            {
              name = "PATH";
              op = "+=(path)";
              value = "/opt/bin";
            }
          ];

          # `options` is a reserved top-level attribute name for a Nix
          # module: nest it under `config` (see `profile.PROFILE.1-1`).
          optionsEx.config.options = {
            # Rendered as `mylib/*:shared=True`.
            "mylib/*:shared" = "True";
          };

          runEnvEx.runEnv = [
            # Rendered as `LD_LIBRARY_PATH+=(path)/opt/lib`.
            {
              name = "LD_LIBRARY_PATH";
              op = "+=(path)";
              value = "/opt/lib";
            }
          ];

          confEx.conf = {
            # Rendered as `tools.build:jobs=4`.
            "tools.build:jobs" = "4";
          };

          toolRequiresEx.toolRequires = {
            # Rendered as `tool1/0.1@user/channel`.
            tool1 = "0.1@user/channel";
          };

          replaceRequiresEx.replaceRequires = {
            # Rendered as `zlib/1.2.12: zlib/[*]`.
            "zlib/1.2.12" = "zlib/[*]";
            # Rendered as `dep/*: dep/*@system`.
            "dep/*" = "dep/*@system";
          };

          replaceToolRequiresEx.replaceToolRequires = {
            # Rendered as `7zip/*: 7zip/system`.
            "7zip/*" = "7zip/system";
            # Rendered as `cmake/*: cmake/3.25.2`.
            "cmake/*" = "cmake/3.25.2";
          };

          platformRequiresEx.platformRequires = {
            # Rendered as `dlib/1.3.22`.
            dlib = "1.3.22";
          };

          platformToolRequiresEx.platformToolRequires = {
            # Rendered as `cmake/3.24.2`.
            cmake = "3.24.2";
          };
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
    final.profiles = mapAttrs (name: profile: {
      settings = filterNulls profile.settings;
      options = filterNulls profile.options;
      toolRequires = filterNulls profile.toolRequires;
      conf = filterNulls profile.conf;
      replaceRequires = filterNulls profile.replaceRequires;
      replaceToolRequires = filterNulls profile.replaceToolRequires;
      platformRequires = filterNulls profile.platformRequires;
      platformToolRequires = filterNulls profile.platformToolRequires;
      buildEnv = mergeDefaultsEnv resolvedDefaults.buildEnv ownCfg.${name}.buildEnv;
      runEnv = mergeDefaultsEnv resolvedDefaults.runEnv ownCfg.${name}.runEnv;
    }) cfg;

    # multiple-profiles.PROFILES.3-1
    wrappers.preConfigInstallHook = ''
      #
      mkdir -p "$CONAN_FLAKE_CONFIG/profiles"
      ${concatMapStrings (name: ''
        ln -sf ${escapeShellArg "${configuration.config.outputs.packages.configuration}/config/profiles/${name}"} "$CONAN_FLAKE_CONFIG/profiles/"${escapeShellArg name}
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
