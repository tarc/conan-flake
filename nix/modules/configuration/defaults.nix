# A module representing the default values used internally by conan-flake.
{ lib, pkgs, config, infuse, ... }:
let
  inherit (lib)
    mkDefault
    mkOption
    types;
in
{
  options.defaults = {
    enable = mkOption {
      type = types.bool;
      description = ''
        Whether to enable conan-flake's default settings for this configuration.
      '';
      default = true;
    };

    devShell.tools = mkOption {
      type = types.lazyAttrsOf (types.nullOr types.package);
      description = ''
        Default build tools always included in devShell.
      '';
      defaultText = lib.literalExpression ''
        lib.optionalAttrs defaults.enable {
          conan = package;
          cmake = pkgs.cmake;
          "''${stdenv.cc.cc.pname}" = stdenv.cc;
        }'';
    };

    profiles.platformToolRequires = mkOption {
      type = types.lazyAttrsOf (types.nullOr types.str);
      description = ''
        Default profile platform tool requires.
      '';
      defaultText = lib.literalExpression ''
        lib.optionalAttrs defaults.enable { }
          // lib.optionalAttrs ((final.devShell.tools.cmake or null) != null) {
          cmake = final.devShell.tools.cmake.version;
        }'';
    };

    settings.compiler = mkOption {
      type = types.attrs;
      description = ''
        Default Conan user settings compiler properties (compiler section in `settings_user.yml`).
      '';
      defaultText = lib.literalExpression ''
        lib.optionalAttrs defaults.enable infuse
          (infuse
            {
              "''${stdenv.cc.cc.pname}".version = [ stdenv.cc.cc.version ];
            }
            {
              "''${pkgs.gccStdenv.cc.cc.pname}".version.__append = [ pkgs.gccStdenv.cc.version ];
              "''${pkgs.llvmPackages.libcxxStdenv.cc.cc.pname}".version.__append = [
                pkgs.llvmPackages.libcxxStdenv.cc.version
              ];
            })
          {
            "''${pkgs.cudaPackages.backendStdenv.cc.cc.pname}".version.__append = [
              pkgs.cudaPackages.backendStdenv.cc.cc.version
            ];
          }'';
    };
  };

  config.defaults = {
    devShell.tools = mkDefault (lib.optionalAttrs config.defaults.enable {
      conan = config.package;
      cmake = pkgs.cmake;
      "${config.stdenv.cc.cc.pname}" = config.stdenv.cc;
    });

    profiles.platformToolRequires = mkDefault (lib.optionalAttrs config.defaults.enable { }
      // lib.optionalAttrs ((config.final.devShell.tools.cmake or null) != null) {
      cmake = config.final.devShell.tools.cmake.version;
    });

    settings.compiler = mkDefault (lib.optionalAttrs config.defaults.enable infuse
      (infuse
        {
          "${config.stdenv.cc.cc.pname}".version = [ config.stdenv.cc.cc.version ];
        }
        {
          "${pkgs.gccStdenv.cc.cc.pname}".version.__append = [ pkgs.gccStdenv.cc.version ];
          "${pkgs.llvmPackages.libcxxStdenv.cc.cc.pname}".version.__append = [
            pkgs.llvmPackages.libcxxStdenv.cc.version
          ];
        })
      {
        "${pkgs.cudaPackages.backendStdenv.cc.cc.pname}".version.__append = [
          pkgs.cudaPackages.backendStdenv.cc.cc.version
        ];
      });
  };
}
