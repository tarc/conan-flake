# conan.outputs module.
{ config, lib, pkgs, ... }:
let
  inherit (lib)
    mkOption
    types;

  relativePath = types.pathWith {
    inStore = false;
    absolute = false;
  };

  packageInfoSubmodule = types.submodule {
    options = {
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
}
