# Definition of the `conan` submodule's `config`
{ config, lib, pkgs, relativePathType, ... }:
let
  inherit (lib)
    mkOption
    types;

  infoSubmodule = types.submodule (
    { config, ... }:
    {
      options = {
        configRoot = mkOption {
          type = types.nullOr types.str;
          description = ''
            Information on the path to the root of the project directory.
          '';
          default = null;
        };
      };
    }
  );
in
{
  options.info = mkOption {
    type = infoSubmodule;
    description = ''
      Overall information on the configuration.
    '';
    default = { };
  };

  config = {
    outputs = {
      commands.info = {
        enterShell = lib.mkAfter ''
          #
        '';
        kind = "configuration";
      };
    };
  };
}
