# Definition of the `conan` submodule's `config`
{
  config,
  lib,
  ...
}:
let
  inherit (lib)
    mkOption
    types
    ;

  infoSubmodule = types.submodule (
    { ... }:
    {
      options = {
        configRoot = mkOption {
          type = types.path;
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
  };

  config = {
    info = {
      configRoot = config.configRoot;
    };
  };
}
