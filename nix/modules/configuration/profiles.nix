# Definition of the `conan` submodule's `config`
{ config, lib, pkgs, envSubmodule, ... }:
let
  inherit (lib)
    filterAttrs
    mkOption
    types;

  profilesSubmodule = types.submodule (
    { name, config, ... }:
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
              ) profiles.settings}

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
              ) profiles.conf}

              [platform_tool_requires]
              ''${lib.strings.concatMapAttrsStringSep "\n" (
                name: value: "''${name}/''${value}"
              ) final.profiles.platformToolRequires}
            '''
          '';
          readOnly = true;
        };
      };
    }
  );

  data = ''
    [settings]
    ${lib.strings.concatMapAttrsStringSep "\n" (
      name: value: "${name}=${value}"
    ) config.profiles.settings}

    [buildenv]
    ${lib.concatMapStringsSep "\n" (
      x: "${x.name}${x.op}${x.value}"
    ) config.profiles.buildEnv}

    [runenv]
    ${lib.concatMapStringsSep "\n" (
      x: "${x.name}${x.op}${x.value}"
    ) config.profiles.runEnv}

    [conf]
    ${lib.strings.concatMapAttrsStringSep "\n" (
      name: value: "${name}=${value}"
    ) config.profiles.conf}

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
      settings = { }
        // lib.optionalAttrs (config.arch != null) {
        "arch" = config.arch;
      }
        // lib.optionalAttrs (config.buildType != null) {
        "build_type" = config.buildType;
      }
        // lib.optionalAttrs (config.compiler != null) {
        "compiler" = config.compiler;
      }
        // lib.optionalAttrs (config.compilerCppStd != null) {
        "compiler.cppstd" = config.compilerCppStd;
      }
        // lib.optionalAttrs (config.compilerLibCxx != null) {
        "compiler.libcxx" = config.compilerLibCxx;
      }
        // lib.optionalAttrs (config.compilerVersion != null) {
        "compiler.version" = config.compilerVersion;
      }
        // lib.optionalAttrs (config.os != null) {
        "os" = config.os;
      };

      buildEnv = config.buildEnv;
      runEnv = config.runEnv;
      conf = config.conf;
      text = pkgs.writeText "profile" data;
    };

    final.profiles.platformToolRequires = filterAttrs (_: v: v != null)
      (config.defaults.profiles.platformToolRequires // cfg.platformToolRequires);

    outputs = {
      configuration.profile = {
        package = cfg.text;
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
