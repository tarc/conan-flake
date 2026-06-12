# A module representing the default values used internally by conan-flake.
{ lib, pkgs, config, infuse, parseSystemArch, parseSystemOs, ... }:
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

    profiles = {
      settings.compiler = mkOption {
        type = types.lazyAttrsOf (types.nullOr types.str);
        description = ''
          Default profile settings section compiler properties.
        '';
        defaultText = lib.literalExpression ''
          lib.optionalAttrs defaults.enable { }
            // lib.optionalAttrs (final.profiles.settings.rest."compiler" or null != null) {
            "compiler" = final.profiles.settings.rest."compiler";
          }
            // lib.optionalAttrs (final.profiles.settings.rest."compiler.cppstd" or null != null) {
            "compiler.cppstd" = final.profiles.settings.rest."compiler.cppstd";
          }
            // lib.optionalAttrs (final.profiles.settings.rest."compiler.libcxx" or null != null) {
            "compiler.libcxx" = final.profiles.settings.rest."compiler.libcxx";
          }
            // lib.optionalAttrs (final.profiles.settings.rest."compiler.version" or null != null) {
            "compiler.version" = final.profiles.settings.rest."compiler.version";
          }'';
      };

      settings.rest = mkOption {
        type = types.lazyAttrsOf (types.nullOr types.str);
        description = ''
          Default profile settings section properties.
        '';
        defaultText = lib.literalExpression ''
          lib.optionalAttrs defaults.enable {
            arch = parseSystemArch { throw = (_: null); } stdenv.system;
            build_type = "Release";
            os = parseSystemOs { throw = (_: null); } stdenv.system;
          }'';
      };

      platformToolRequires = mkOption {
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

  config = {
    defaults = {
      devShell.tools = mkDefault (lib.optionalAttrs config.defaults.enable {
        conan = config.package;
        cmake = pkgs.cmake;
        "${config.stdenv.cc.cc.pname}" = config.stdenv.cc;
      });

      profiles = {
        settings.compiler = mkDefault (lib.optionalAttrs config.defaults.enable { }
          // lib.optionalAttrs (config.final.profiles.settings.rest."compiler" or null != null) {
          "compiler" = config.final.profiles.settings.rest."compiler";
        }
          // lib.optionalAttrs (config.final.profiles.settings.rest."compiler.cppstd" or null != null) {
          "compiler.cppstd" = config.final.profiles.settings.rest."compiler.cppstd";
        }
          // lib.optionalAttrs (config.final.profiles.settings.rest."compiler.libcxx" or null != null) {
          "compiler.libcxx" = config.final.profiles.settings.rest."compiler.libcxx";
        }
          // lib.optionalAttrs (config.final.profiles.settings.rest."compiler.version" or null != null) {
          "compiler.version" = config.final.profiles.settings.rest."compiler.version";
        });

        settings.rest = mkDefault (lib.optionalAttrs config.defaults.enable {
          arch = parseSystemArch { throw = (_: null); } config.stdenv.system;
          build_type = "Release";
          os = parseSystemOs { throw = (_: null); } config.stdenv.system;
        });

        platformToolRequires = mkDefault (lib.optionalAttrs config.defaults.enable { }
          // lib.optionalAttrs ((config.final.devShell.tools.cmake or null) != null) {
          cmake = config.final.devShell.tools.cmake.version;
        });
      };

      settings.compiler = mkDefault (lib.optionalAttrs config.defaults.enable
        (infuse
          (infuse
            {
              "${config.stdenv.cc.cc.pname}".version = [
                config.stdenv.cc.cc.version
              ];
            }
            {
              "${pkgs.gccStdenv.cc.cc.pname}".version.__append = [
                pkgs.gccStdenv.cc.version
              ];
              "${pkgs.llvmPackages.libcxxStdenv.cc.cc.pname}".version.__append = [
                pkgs.llvmPackages.libcxxStdenv.cc.version
              ];
            })
          {
            "${pkgs.cudaPackages.backendStdenv.cc.cc.pname}".version.__append = [
              pkgs.cudaPackages.backendStdenv.cc.cc.version
            ];
          }));
    };
  };
}
