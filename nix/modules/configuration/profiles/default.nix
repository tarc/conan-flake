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

  # The conan-flake defaults are a single, global set of profile defaults
  # merged into every profile. Entries set to `null` in the profile remove the
  # corresponding default.
  #
  # profile.PROFILE.2
  # profile.FINAL.2
  filterNulls = profileAttrs: filterAttrs (_: v: v != null) profileAttrs;

  # `[buildenv]`/`[runenv]` entries are a list, not an attribute set, so
  # importing `defaults.profiles` and a profile's own value into the same
  # `evalModules` call only concatenates their entries (defaults first, since
  # `evalProfile` lists `defaults.profiles` before the profile's own `deferred`
  # value) -- it does not, by itself, let an entry replace the default entry
  # carrying the same `name`, or let a `null` value remove it. Reduce the
  # concatenated list by keeping only the last entry seen per `name` (moving
  # it to that later position), so a profile's own entry always displaces the
  # default entry it shares a name with, then drop whatever is left with a
  # `null` value.
  #
  # profile.PROFILE.2
  # profile.FINAL.2
  # profile.BUILDENV.3
  # profile.BUILDENV.4
  # profile.RUNENV.3
  # profile.RUNENV.4
  dedupeEnv =
    entries:
    builtins.filter (entry: entry.value != null) (
      builtins.foldl' (
        acc: entry: (builtins.filter (e: e.name != entry.name) acc) ++ [ entry ]
      ) [ ] entries
    );

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

  cfg = mapAttrs evalProfile configuration.config.profiles;
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
    final.profiles = mapAttrs (_: profile: {
      settings = filterNulls profile.settings;
      options = filterNulls profile.options;
      toolRequires = filterNulls profile.toolRequires;
      conf = filterNulls profile.conf;
      replaceRequires = filterNulls profile.replaceRequires;
      replaceToolRequires = filterNulls profile.replaceToolRequires;
      platformRequires = filterNulls profile.platformRequires;
      platformToolRequires = filterNulls profile.platformToolRequires;
      buildEnv = dedupeEnv profile.buildEnv;
      runEnv = dedupeEnv profile.runEnv;
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
