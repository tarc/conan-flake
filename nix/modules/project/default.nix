{ self
, name
, config
, lib
, pkgs
, ...
}:
let
  inherit (lib)
    mkOption
    types
    ;
  inherit (types)
    raw
    ;
in
{
  imports = [
    ./defaults.nix
    ./package.nix
    ./devshell.nix
    ./outputs.nix
  ];
  options = {
    projectRoot = mkOption {
      type = types.path;
      description = ''
        Path to the root of the project directory.

        Changing this affects certain functionality, like where to
        look for the 'conanfile.py' file.
      '';
      default = self;
      defaultText = "Top-level directory of the flake";
    };
    projectFlakeName = mkOption {
      type = types.nullOr types.str;
      description = ''
        A descriptive name for the flake in which this project resides.

        If unspecified, the Nix store path's basename will be used.
      '';
      default = null;
      apply = cls: if cls == null then builtins.baseNameOf config.projectRoot else cls;
    };
    rootDevShell = mkOption {
      type = types.package;
      description = ''
        Root dev shell.
      '';
    };
    log = mkOption {
      type = types.lazyAttrsOf (types.functionTo types.raw);
      default = import ../../logging.nix {
        name = config.projectFlakeName + "#conanProject." + name;
      };
      internal = true;
      readOnly = true;
      description = ''
        Internal logging module
      '';
    };
    autoWire =
      let
        outputTypes = [
          "packages"
          "checks"
          "apps"
          "devShells"
        ];
      in
      mkOption {
        type = types.listOf (types.enum outputTypes);
        description = ''
          List of flake output types to autowire.

          Using an empty list will disable autowiring entirely,
          enabling you to manually wire them using
          `config.conanProject.outputs`.
        '';
        default = outputTypes;
      };
  };
}
