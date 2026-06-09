# Definition of the `conan` submodule's `config`
{ config, lib, pkgs, relativePathType, parseSystemArch, parseSystemOs, envSubmodule, ... }:
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
    ./settings.nix
    ./profiles.nix
    ./remotes
    ./devshell.nix
    ./outputs.nix
    ./info.nix
  ];

  options = {
    configRoot = mkOption {
      type = types.path;
      description = ''
        Path to the root of the project directory.

        Changing this affects certain functionality, like where to look for
        `conanHome` or the directory structure related to the local recipes
        index remotes.
      '';
    };

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
        pkgs.llvmPackages.stdenv
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

    arch = mkOption {
      type = types.nullOr types.str;
      description = ''
        Architecture.
      '';
      default = parseSystemArch { throw = (_: null); } config.stdenv.system;
      defaultText = lib.literalMD "The architecture of the system.";
    };

    buildType = mkOption {
      type = types.nullOr types.str;
      description = ''
        Build type.
      '';
      default = "Release";
    };

    compiler = mkOption {
      type = types.nullOr types.str;
      description = ''
        Compiler.
      '';
      default = config.stdenv.cc.cc.pname;
      defaultText = lib.literalExpression "stdenv.cc.cc.pname";
    };

    compilerCppStd = mkOption {
      type = types.nullOr types.str;
      description = ''
        Compiler C++ standard.
      '';
      default = "gnu17";
    };

    compilerLibCxx = mkOption {
      type = types.nullOr types.str;
      description = ''
        Compiler C++ standard library.
      '';
      default = "libstdc++11";
    };

    compilerVersion = mkOption {
      type = types.nullOr types.str;
      description = ''
        Compiler version.
      '';
      default = config.stdenv.cc.version;
      defaultText = lib.literalExpression "stdenv.cc.version";
    };

    os = mkOption {
      type = types.nullOr types.str;
      description = ''
        Operating system.
      '';
      default = parseSystemOs { throw = (_: null); } config.stdenv.system;
      defaultText = lib.literalMD "The operating system string.";
    };

    buildEnv = mkOption {
      type = types.listOf envSubmodule;
      description = ''
        Profile [buildenv] section.
      '';
      default = [ ];
    };

    runEnv = mkOption {
      type = types.listOf envSubmodule;
      description = ''
        Profile [runenv] section.
      '';
      default = [ ];
    };

    conf = mkOption {
      type = types.attrsOf types.str;
      description = ''
        Profile [conf] section.
      '';
      default = { };
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
    settings = {
      base = mkDefault {
        "${config.stdenv.cc.cc.pname}".version = [ config.stdenv.cc.cc.version ];
      };
    };

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
