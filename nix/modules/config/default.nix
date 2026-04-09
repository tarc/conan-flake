# Definition of the `conan` submodule's configuration
{ self, name, config, lib, pkgs, ... }:
let
  inherit (lib)
    mkOption
    types
    ;
  inherit (types)
    raw
    ;
  inherit (pkgs)
    writeTextDir
    ;
in
{
  options = {
    configRoot = mkOption {
      type = types.path;
      description = ''
        Path to the root of the project directory.

        Changing this affects certain functionality, like where to look for the
        'conanfile.py' file or the local directory structure related to the
        local recipes index remotes.
      '';
      default = self;
      defaultText = "Top-level directory of the flake";
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
    configuration = mkOption {
      type = types.package;
      readOnly = true;
      description = ''
        The Conan configuration package genarated for this project.
      '';
    };
  };
  config = {
    configuration = writeTextDir "config/settings_user.yml" ''
      compiler:
        clang:
          version:
          - 21.1.8
        gcc:
          version:
          - 14.3.0
          - 15.2.0
    '';
  };
}
