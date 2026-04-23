# conan.remotes.<name> module.
{ configuration, lib, pkgs, ... }:
let
  inherit (lib)
    mkOption
    types;
in
{ name, config, ... }: {
  options = {
    enable = mkOption {
      type = types.bool;
      description = ''
        Enable this remote.
      '';
      default = true;
    };

    name = mkOption {
      type = types.str;
      description = ''
        Name of the remote.
      '';
      default = name;
      defaultText = lib.literalMD "remote's name";
    };

    url = mkOption {
      type = types.either configuration.relativePathType types.str;
      description = ''
        Remote's URL.
      '';
    };

    local = mkOption {
      type = types.bool;
      description = ''
        Whether this remote is of `local-recipes-index` type.
      '';
      default = false;
    };

    verifySsl = mkOption {
      type = types.bool;
      description = ''
        Whether to verify SSL.
      '';
      default = true;
    };

    allowedPackages = mkOption {
      type = types.nullOr (types.listOf types.str);
      description = ''
        Allowed packages.
      '';
      default = null;
    };
  };
}
