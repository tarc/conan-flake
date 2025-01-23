# A module representing the default values used internally by conan-flake.
{ name
, lib
, pkgs
, config
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
in
{
  options.defaults = {
    package = mkOption {
      type = types.attrs;
      description = ''Definitions scanned from the `conanfile.py` in `projectRoot`'';
      readOnly = true;
      default =
        let
          conan-interpreter = import ../../conan-interpreter {
            inherit pkgs lib;
          };
        in
        conan-interpreter.inspect config.projectRoot;
    };

    profile = mkOption {
      type = types.attrs;
      description = ''Profile detected'';
      readOnly = true;
      default =
        let
          conan-interpreter = import ../../conan-interpreter {
            inherit pkgs lib;
          };
        in
        conan-interpreter.profile config.projectRoot;
    };

    graph = mkOption {
      type = types.attrs;
      description = ''Graph'';
      readOnly = true;
      default =
        let
          conan-interpreter = import ../../conan-interpreter {
            inherit pkgs lib;
          };
        in
        conan-interpreter.graph config.projectRoot config.profiles.build.toToml config.profiles.host.toToml;
    };

    devShell.tools = mkOption {
      type = functionTo (types.lazyAttrsOf (types.nullOr types.package));
      description = ''Build tools always included in devShell'';
      readOnly = true;
      default =
        ps: with ps; {
          inherit
            conan
            cmake
            ;
        };
    };

    devShell.mkShellArgs = mkOption {
      type = types.lazyAttrsOf types.raw;
      description = ''
        Extra arguments always passed to `pkgs.mkShell`.
      '';
      readOnly = true;
      default = {
        inputsFrom = [
          config.rootDevShell
        ];
        shellHook = ''
          CONAN_HOME="$FLAKE_ROOT/.conan2"
          export CONAN_HOME
          CONAN_BUILD_PROFILE="${config.profiles.build.toToml}"
          CONAN_HOST_PROFILE="${config.profiles.host.toToml}"
          CONAN_GRAPH="${config.graph}"
          export CONAN_BUILD_PROFILE
          export CONAN_HOST_PROFILE
          export CONAN_GRAPH
          conan editable add .
        '';
      };
    };

    projectModules.output = mkOption {
      type = types.deferredModule;
      description = ''
        A conan-flake project module that exports the `packages` options
        to the consuming flake. This enables the use of this
        flake's C++ package as a dependency, re-using its overrides.
      '';
      default = lib.optionalAttrs config.defaults.enable {
        inherit (config)
          packages
          ;
      };
      defaultText = lib.literalMD ''a generated module'';
    };
  };
}
