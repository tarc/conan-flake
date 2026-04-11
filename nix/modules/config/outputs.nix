# conan.outputs module.
{ config, lib, pkgs, ... }:
let
  inherit (lib)
    mkOption
    mkOptionType
    types;
  inherit (lib.attrsets)
    filterAttrs;
  inherit (pkgs)
    runCommand;
  inherit (pkgs.lib)
    escapeShellArg
    mapAttrs
    mapAttrsToList
    attrValues
    attrNames;
  inherit (pkgs.lib.strings)
    concatStringsSep;

  relativePath = types.pathWith {
    inStore = false;
    absolute = false;
  };

  packageInfoSubmodule = types.submodule {
    options = {
      kind = mkOption {
        type = types.enum [ "configuration" "package" ];
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
        type = types.nullOr (types.either relativePath (types.listOf relativePath));
        description = ''
          For configuration packages, the intended relative path for the
          configuration file, in the case `package` is a file. Otherwise, a
          list of relative paths to the package's output configuration files.
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
    };
  };

  cfg = config.outputs;

  formatCommand = name: info: ''
    cd $out
    mkdir -p ${escapeShellArg (builtins.dirOf info.manifest)}
    cd ${escapeShellArg (builtins.dirOf info.manifest)}
    cp "''$${name}" ${escapeShellArg (builtins.baseNameOf info.manifest)}
  '';

  configurations = kind:
    mapAttrsToList
      formatCommand
      (filterAttrs (name: value: value.kind == kind) cfg.packages);

  packages = kind:
    mapAttrs
      (_: info:
        info.package)
      (filterAttrs (name: value: value.kind == kind) cfg.packages);

  commands = kind: sep:
    (concatStringsSep
      sep
      (configurations kind));

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
      packages = {
        configuration = {
          package = runCommand "configuration"
          (packages "configuration")
          ''
            mkdir -p $out
            export __CONAN_CONFIGURATION_COMMANDS=${escapeShellArg (commands "configuration" " && ")}
            ${commands "configuration" "\n"}
          '';
          kind = "package";
        };
      };
    };
  };
}
