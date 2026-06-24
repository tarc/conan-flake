# Definition of the `conan` submodule's `config`
{ config
, lib
, pkgs
, ...
}:
let
  inherit (lib) filterAttrs mkOption types;

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

      tools = lib.mkOption {
        type = types.lazyAttrsOf (types.nullOr types.package);
        description = ''
          Build tools to expose inside the developer environment.

          These tools are merged with the conan-flake defaults defined in the
          `defaults.devShell.tools` option. Set the value to `null` to remove
          that default tool.
        '';
        default = { };
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
      };
    };
  };

  cfg = config.devShell;
  isAppleSDK = pkg: builtins.match ".*apple-sdk.*" (pkg.pname or "") != null;
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

    final.devShell.tools = mkOption {
      type = types.lazyAttrsOf types.package;
      readOnly = true;
      description = ''
        Final configuration of the build tools to expose inside the developer
        environment.
      '';
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
    devShell = {
      enterShell = lib.mkBefore ''
        CONAN_FLAKE_ROOT="''$(${lib.getExe config.rootFinding.package})"
        export CONAN_FLAKE_ROOT
        CONAN_FLAKE_HOME="''$(${lib.getExe config.homeFinding.package} ''${CONAN_FLAKE_ROOT} CONAN_FLAKE_HOME)"
        export CONAN_FLAKE_HOME
        CONAN_FLAKE_CONFIG="''$(${lib.getExe config.homeFinding.package} ''${CONAN_FLAKE_ROOT} CONAN_FLAKE_CONFIG)"
        export CONAN_FLAKE_CONFIG
        CONAN_HOME="''$(${lib.getExe config.homeFinding.package} ''${CONAN_FLAKE_ROOT} CONAN_HOME)"
        export CONAN_HOME
      '';
    };

    final.devShell.tools = filterAttrs (_: v: v != null) (config.defaults.devShell.tools // cfg.tools);

    outputs.devShell =
      let
        packages = lib.attrValues config.final.devShell.tools;
        partitionedPkgs = builtins.partition isAppleSDK packages;
        buildInputs = partitionedPkgs.right;
        nativeBuildInputs = partitionedPkgs.wrong;
      in
      ((pkgs.mkShell.override { stdenv = cfg.stdenv; }) (
        {
          inherit (cfg) inputsFrom name;
          inherit buildInputs nativeBuildInputs;
          shellHook = ''
            ${lib.optionalString config.debug "set -x"}
            ${cfg.enterShell}

            # Be sure to install Conan configuration only after executing all
            # collected commands.
            ${lib.getExe config.package} config install "$CONAN_FLAKE_CONFIG"
          '';
        }
        // cfg.env
      ));
  };
}
