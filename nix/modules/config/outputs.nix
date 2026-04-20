# conan.outputs module.
{ config, lib, pkgs, relativePathType, ... }:
let
  inherit (lib)
    mkOption
    types;
  inherit (lib.attrsets)
    filterAttrs;
  inherit (pkgs)
    runCommand;
  inherit (pkgs.lib)
    escapeShellArg
    mapAttrs
    mapAttrsToList
    mkMerge;
  inherit (pkgs.lib.strings)
    concatStringsSep;

  kindType = types.enum [ "configuration" "package" "enterShell" ];

  packageInfoSubmodule = types.submodule {
    options = {
      kind = mkOption {
        type = kindType;
        description = ''
          The kind of package, used to determine how to group packages
          together.
        '';
      };
      package = mkOption {
        type = types.package;
        description = ''
          The configuration-outputing derivation generated.
        '';
      };
      manifest = mkOption {
        type = types.nullOr (types.either relativePathType (types.listOf relativePathType));
        description = ''
          For configuration packages, the intended relative path for the
          configuration file, in the case `package` is a file. Otherwise, a
          list of relative paths to the package's output configuration files.
        '';
      };
    };
  };

  commandsInfoSubmodule = types.submodule {
    options = {
      kind = mkOption {
        type = kindType;
        description = ''
          The kind of commands, used to determine how to group them together.
        '';
      };
      enterShell = mkOption {
        type = types.lines;
        description = ''
          List of commands required to run in shell hooks according to `lines`
          merging logic.
        '';
      };
    };
  };

  outputsSubmodule = types.submodule {
    options = {
      packages = mkOption {
        type = types.lazyAttrsOf packageInfoSubmodule;
        description = ''
          Package set containing the generated Conan configuration.
        '';
      };
      commands = mkOption {
        type = types.lazyAttrsOf commandsInfoSubmodule;
        description = ''
          Commands to install the generated configuration.
        '';
      };
    };
  };

  cfg = config.outputs;

  formatCommand = name: info: ''
    cd $out
    mkdir -p ${escapeShellArg (builtins.dirOf info.manifest)}
    cd ${escapeShellArg (builtins.dirOf info.manifest)}
    cp "''$${name}" ${escapeShellArg (builtins.baseNameOf info.manifest)}
  '';

  mapToCommands = kind:
    mapAttrsToList
      formatCommand
      (filterAttrs (name: value: value.kind == kind) cfg.packages);

  packages = kind:
    mapAttrs
      (_: info: info.package)
      (filterAttrs (name: value: value.kind == kind) cfg.packages);

  copyFromPackageInfo = kind: sep:
    (concatStringsSep
      sep
      (mapToCommands kind));

  mergeCommands = kind:
    mkMerge (mapAttrsToList
      (_: info: info.enterShell)
      (filterAttrs
        (name: value: value.kind == kind)
        cfg.commands));

in
{
  options = {
    outputs = mkOption {
      type = outputsSubmodule;
      description = ''
        The flake outputs generated for this configuration.

        This is an internal option, not meant to be set by the user.
      '';
    };
  };

  config = {
    outputs = {
      packages.configuration = {
        package = runCommand "copy-configuration"
        (packages "configuration")
        ''
          mkdir -p $out
          export __CONAN_CONFIGURATION_COMMANDS=${escapeShellArg (copyFromPackageInfo "configuration" " && ")}
          ${copyFromPackageInfo "configuration" "\n"}
        '';
        kind = "package";
      };
      commands.configuration = {
        enterShell = mergeCommands "configuration";
        kind = "enterShell";
      };
    };
  };
}
