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
          type = types.package;
          readOnly = true;
          description = ''
            Information on the path to the root of the configuration directory.
          '';
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
}
