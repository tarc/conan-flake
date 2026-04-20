# Definition of the `conan` submodule's configuration
{ config, lib, pkgs, ... }:
let
  inherit (lib)
    mkOption
    types;
  inherit (types)
    raw;
in
{
  imports = [
    ./settings.nix
    ./profiles.nix
    # ./remotes.nix
    # ./devshell.nix
    ./outputs.nix
  ];

  options = {
    configRoot = mkOption {
      type = types.path;
      description = ''
        Path to the root of the project directory.

        Changing this affects certain functionality, like where to look for the
        'conanfile.py' file or the directory structure related to the local
        recipes index remotes.
      '';
    };
    stdenv = mkOption {
      type = types.package;
      description = ''
        The stdenv to use for the development environment.
      '';
      example = ["pkgs.llvmPackages.stdenv" "pkgs.cudaPackages.backendStdenv"];
      default = pkgs.stdenv;
      defaultText = lib.literalExpression "pkgs.stdenv";
    };
  };

  config = {
    settings.base = {
      "${config.stdenv.cc.cc.pname}".version = [ config.stdenv.cc.cc.version ];
    };

    profiles = { };
  };
}
