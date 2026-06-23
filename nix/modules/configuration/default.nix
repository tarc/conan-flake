# Definition of the `conan` submodule's `config`
{ config, lib, pkgs, relativePathType, envSubmodule, ... }:
let
  inherit (lib)
    mkDefault
    mkOption
    types;
  inherit (types)
    raw;
in
{
  imports = [
    ./defaults.nix
    ./root.nix
    ./settings.nix
    ./profiles.nix
    ./remotes
    ./devshell.nix
    ./outputs.nix
    ./info.nix
  ];

  options = {
    debug = mkOption {
      type = types.bool;
      description = ''
        Enable debug mode for `devShell.enterShell`.
      '';
      example = true;
      default = false;
    };

    stdenv = mkOption {
      type = types.package;
      description = ''
        The stdenv derivation to use for the Conan environment.
      '';
      example = lib.literalExpression ''
        pkgs.llvmPackages.libcxxStdenv
        pkgs.cudaPackages.backendStdenv'';
      default = pkgs.stdenv;
      defaultText = lib.literalExpression "pkgs.stdenv";
    };

    package = mkOption {
      type = lib.types.package;
      description = ''
        The Conan package to use.
      '';
      default = pkgs.conan;
      defaultText = lib.literalExpression "pkgs.conan";
    };

    configLocal = mkOption {
      type = relativePathType;
      description = ''
        Relative path for local configuration files.
      '';
      default = "./config";
    };

    conanHome = mkOption {
      type = relativePathType;
      description = ''
        Relative path to the local Conan home.
      '';
      default = "./.conan2";
    };

    offline = mkOption {
      type = types.bool;
      description = ''
        Whether to enable only local remotes.
      '';
      default = false;
    };

    hasImplicitConancenterRemote = mkOption {
      type = types.bool;
      description = ''
        Whether to consider the implicit conancenter remote
        (https://center2.conan.io) during the initial Conan setup or not.
      '';
      default = true;
    };

    autoWire =
      let
        outputTypes = [ "devShells" ];
      in
      mkOption {
        type = types.listOf (types.enum outputTypes);
        description = ''
          List of configuration output types to autowire.

          Using an empty list will disable autowiring entirely, enabling you to
          manually refer to them with `config.conan.outputs`.
        '';
        default = outputTypes;
      };
  };

  config = {
    outputs = {
      configuration.default = {
        package = pkgs.writeText "profile" ''
          conan_home=${config.conanHome}
        '';
        manifest = ".conanrc";
        kind = "configuration";
      };

      commands.default = {
        enterShell = lib.mkBefore ''
          #
          ln -sf ${config.outputs.packages.configuration}/.conanrc .conanrc
        '';
        kind = "configuration";
      };
    };
  };
}
