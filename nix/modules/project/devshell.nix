{ config
, lib
, pkgs
, ...
}:
let
  inherit (lib)
    mkOption
    types
    ;
  inherit (types)
    functionTo
    ;

  devShellSubmodule = types.submodule {
    options = {
      enable = mkOption {
        type = types.bool;
        description = ''
          Whether to enable a development shell for the project.
        '';
        default = true;
      };

      tools = mkOption {
        type = functionTo (types.lazyAttrsOf (types.nullOr types.package));
        description = ''
          Build tools for developing.

          These tools are merged with the conan-flake defaults defined in the
          `defaults.devShell.tools` option. Set the value to `null` to remove
          that default tool.
        '';
        default = ps: { };
      };

      mkShellArgs = mkOption {
        type = types.lazyAttrsOf types.raw;
        description = ''
          Extra arguments to pass to `pkgs.mkShell`.
        '';
        default = { };
        example = ''
          {
            # Set project-local `CONAN_HOME`
            inputsFrom = [
              config.flake-root.devShell
            ];
            shellHook = \'\'
              CONAN_HOME="$FLAKE_ROOT/.conan2"
              export CONAN_HOME
              conan profile detect -e
              conan install . -pr:b ${config.profileFile}
              cmake --preset conan-release
            \'\';
          };
        '';
      };
    };
  };
in
{
  options = {
    devShell = mkOption {
      type = devShellSubmodule;
      description = ''
        Development shell configuration
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
  config =
    let

      nativeBuildInputs = lib.attrValues (
        config.defaults.devShell.tools pkgs // config.devShell.tools pkgs
      );

      mkShellArgs =
        config.defaults.devShell.mkShellArgs
        // config.devShell.mkShellArgs
        // {
          nativeBuildInputs =
            (config.defaults.devShell.mkShellArgs.nativeBuildInputs or [ ])
            ++ (config.devShell.mkShellArgs.nativeBuildInputs or [ ])
            ++ nativeBuildInputs;
        };

      devShell =
        lib.addMetaAttrs
          {
            description = "${config.ref}";
          }
          (
            pkgs.mkShell (
              mkShellArgs
              // {
                inherit (config) name;
              }
            )
          );

    in
    {
      outputs = {
        inherit devShell;
      };
    };
}
