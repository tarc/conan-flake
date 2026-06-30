# conan.outputs module.
{
  config,
  lib,
  pkgs,
  relativePathType,
  ...
}:
let
  inherit (lib)
    mkOption
    types
    ;
  inherit (lib.attrsets)
    filterAttrs
    ;
  inherit (pkgs)
    runCommand
    ;
  inherit (pkgs.lib)
    escapeShellArg
    mapAttrs
    mapAttrsToList
    mkMerge
    ;
  inherit (pkgs.lib.strings)
    concatStringsSep
    ;

  kindType = types.enum [
    "configuration"
    "package"
    "enterShell"
    "info"
  ];

  configurationInfoSubmodule = types.submodule {
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

  linksInfoSubmodule = types.submodule {
    options = {
      kind = mkOption {
        type = kindType;
        description = ''
          The kind of links, used to determine how to group them together.
        '';
      };
      relativePaths = mkOption {
        type = types.listOf relativePathType;
        description = ''
          List of relative paths to link.
        '';
      };
    };
  };

  outputsSubmodule = types.submodule {
    options = {
      configuration = mkOption {
        type = types.lazyAttrsOf configurationInfoSubmodule;
        description = ''
          The generated Conan configuration.
        '';
      };
      commands = mkOption {
        type = types.lazyAttrsOf commandsInfoSubmodule;
        description = ''
          Commands to install the generated configuration.
        '';
      };
      links = mkOption {
        type = types.lazyAttrsOf linksInfoSubmodule;
        description = ''
          Paths to link after the configuration is generated.
        '';
      };
      packages = mkOption {
        type = types.lazyAttrsOf types.package;
        description = ''
          Package set containing the generated Conan configuration.
        '';
      };
    };
  };

  cfg = config.outputs;

  formatCommand = name: info: ''
    cd $out
    mkdir -p ${escapeShellArg (dirOf info.manifest)}
    cd ${escapeShellArg (dirOf info.manifest)}
    cp "''$${name}" ${escapeShellArg (baseNameOf info.manifest)}
  '';

  mapToCommands =
    kind:
    mapAttrsToList formatCommand (filterAttrs (name: value: value.kind == kind) cfg.configuration);

  packages =
    kind:
    mapAttrs (_: info: info.package) (filterAttrs (name: value: value.kind == kind) cfg.configuration);

  manifests =
    kind:
    mapAttrsToList (_: info: info.manifest) (
      filterAttrs (name: value: value.kind == kind) cfg.configuration
    );

  copyFromPackageInfo = kind: sep: (concatStringsSep sep (mapToCommands kind));

  mergeCommands =
    kind:
    mkMerge (
      mapAttrsToList (_: info: info.enterShell) (
        filterAttrs (name: value: value.kind == kind) cfg.commands
      )
    );

  mergeLinks =
    kind:
    mkMerge (
      mapAttrsToList (_: info: info.relativePaths) (
        filterAttrs (name: value: value.kind == kind) cfg.links
      )
    );
in
{
  options = {
    outputs = mkOption {
      type = outputsSubmodule;
      description = ''
        The outputs generated for this configuration.

        This is an internal option, not meant to be set by the user.
      '';
    };
  };

  config = {
    outputs = {
      configuration.setup = {
        package = runCommand "copy-configuration" (packages "configuration") ''
          mkdir -p $out
          ${copyFromPackageInfo "configuration" "\n"}
        '';
        manifest = manifests "configuration";
        kind = "package";
      };
      commands.configuration = {
        enterShell = mergeCommands "configuration";
        kind = "enterShell";
      };
      links.configuration = {
        relativePaths = mergeLinks "configuration";
        kind = "info";
      };
      packages.configuration = cfg.configuration.setup.package;
    };

    devShell = {
      # Dispatch all commnads that has been collected in the `configuration`
      # command output to the `enterShell` hook of the `devShell` module.
      enterShell = cfg.commands.configuration.enterShell;
    };
  };
}
