# Definition of the `conan` submodule's `config`
{
  lib,
  pkgs,
  listOfGeneratorType,
  listOfOutputType,
  anyOutput,
  ...
}:
let
  inherit (lib)
    mkOption
    types
    ;
in
{
  imports = [
    ./defaults.nix
    ./root.nix
    ./home.nix
    ./wrappers.nix
    ./settings.nix
    ./profiles.nix
    ./remotes
    ./checks.nix
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

    generators = mkOption {
      type = listOfGeneratorType;
      description = ''
        List of generators observed by the conan-flake configuration.
      '';
      default = [ "CMakeDeps" ];
    };

    autoWire = mkOption {
      type = listOfOutputType;
      description = ''
        List of configuration output types to autowire.

        Using an empty list will disable autowiring entirely, enabling you to
        manually refer to them with `config.conan.outputs`.
      '';
      default = anyOutput;
    };
  };
}
