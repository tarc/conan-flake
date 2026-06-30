# Definition of the `conan` submodule's `config`
{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkOption types;

  checkSubmodule = types.submodule {
    options = {
      enable = mkOption {
        type = types.bool;
        description = ''
          Whether to enable this check.
        '';
        default = false;
      };
      drv = mkOption {
        type = types.package;
        description = ''
          The check derivation.
        '';
      };
    };
  };

in
{
  options = {
    checks = mkOption {
      default = { };
      type = types.lazyAttrsOf checkSubmodule;
      description = ''
        Use this to define checks for the configuration.
      '';
    };

    outputs.checks = mkOption {
      type = types.lazyAttrsOf types.package;
      readOnly = true;
      description = ''
        The collected (enabled) checks for this configuration.
      '';
    };
  };

  config = {
    outputs = {
      checks = lib.filterAttrs (_: v: v != null) (
        lib.mapAttrs (_: v: if v.enable then v.drv else null) config.checks
      );
    };
  };
}
