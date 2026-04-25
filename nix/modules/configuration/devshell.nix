# Definition of the `conan` submodule's `config`
{ config, lib, pkgs, relativePathType, ... }:
let
  inherit (lib)
    escapeShellArg
    mkOption
    types;

  devShellSubmodule = types.submodule {
    options = {
      env = lib.mkOption {
        type = types.submodule {
          freeformType = types.lazyAttrsOf types.anything;
        };
        description = ''
          Environment variables to be exposed inside the developer environment.
        '';
        default = { };
      };

      name = lib.mkOption {
        type = types.nullOr types.str;
        description = ''
          Name of the project.
        '';
        default = "conan-shell";
      };

      enterShell = lib.mkOption {
        type = types.lines;
        description = ''
          Bash code to execute when entering the shell.
        '';
        default = "";
      };

      packages = lib.mkOption {
        type = types.listOf types.package;
        description = ''
          A list of packages to expose inside the developer environment.
        '';
        default = [ ];
      };

      inputsFrom = lib.mkOption {
        type = types.listOf types.package;
        description = ''
          A list of derivations whose build inputs will be merged into the
          shell environment.
        '';
        default = [ ];
        example = lib.literalExpression ''
          [
            pkgs.hello
            (pkgs.python3.withPackages (ps: [ ps.numpy ps.pandas ]))
          ]
        '';
      };

      stdenv = lib.mkOption {
        type = types.package;
        description = ''
          The stdenv to use for the developer environment.
        '';
        default = config.stdenv;
        defaultText = lib.literalExpression "stdenv";

        # Remove the default apple-sdk on macOS.
        # Allow users to specify an optional SDK in `apple.sdk`.
        apply = stdenv:
          if stdenv.isDarwin
          then
            stdenv.override
              (prev: {
                extraBuildInputs =
                  builtins.filter (x: !lib.hasPrefix "apple-sdk" x.pname) prev.extraBuildInputs;
              })
          else stdenv;
      };

      apple = {
        sdk = lib.mkOption {
          type = types.nullOr types.package;
          description = ''
            The Apple SDK to add to the developer environment on macOS.

            If set to `null`, the system SDK can be used if the shell allows
            access to external environment variables.
          '';
          default = if pkgs.stdenv.isDarwin then pkgs.apple-sdk else null;
          defaultText = lib.literalExpression "if pkgs.stdenv.isDarwin then pkgs.apple-sdk else null";
          example = lib.literalExpression "pkgs.apple-sdk_15";
        };
      };
    };
  };

  cfg = config.devShell;
  isAppleSDK = pkg: builtins.match ".*apple-sdk.*" (pkg.pname or "") != null;
  partitionedPkgs = builtins.partition isAppleSDK cfg.packages;
  buildInputs = partitionedPkgs.right;
  nativeBuildInputs = partitionedPkgs.wrong;

in
{
  options = {
    devShell = mkOption {
      type = devShellSubmodule;
      description = ''
        Development shell configuration.
      '';
      default = { };
    };

    outputs.devShell = mkOption {
      type = types.package;
      readOnly = true;
      description = ''
        The development shell derivation generated for this project.
      '';
    };
  };

  config = {
    devShell.packages = [
    ]
    ++ lib.optional (cfg.apple.sdk != null) cfg.apple.sdk;

    outputs.devShell = (
      (pkgs.mkShell.override { stdenv = cfg.stdenv; }) ({
        inherit (cfg) inputsFrom name;
        inherit buildInputs nativeBuildInputs;
        shellHook = ''
          ${cfg.enterShell}
          ${lib.getExe config.package} config install ${escapeShellArg config.configLocal}
        '';
      } // cfg.env)
    );
  };
}
