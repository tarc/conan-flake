# A module representing the default values used internally by conan-flake.
{
  lib,
  pkgs,
  config,
  infuse,
  parseSystemArch,
  parseSystemOs,
  contains,
  ...
}:
let
  inherit (lib)
    getExe
    mkDefault
    mkOption
    types
    ;

  isClangLibcxxLLVM = config.stdenv.cc.isClang && config.stdenv.cc.libcxx.isLLVM or false;
  c = "'c': '${getExe config.stdenv.cc}'";
  cpp = "'cpp': '${dirOf (getExe config.stdenv.cc)}/clang++'";
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
          inherit (outputs.packages) infoWrapper;
          inherit (outputs.packages) configHomeWrapper;
          inherit (outputs.packages) runPreConfigInstallHookWrapper;
          inherit (outputs.packages) configInstallWrapper;
          inherit (outputs.packages) conanWrapper;
          inherit (outputs.packages) lockCreateWrapper;
          inherit (outputs.packages) lockExtendWrapper;
          inherit (outputs.packages) installBuildMissingWrapper;
          inherit (outputs.packages) allWrapper;
        }'';
    };

    profiles = {
      settings.compiler = mkOption {
        type = types.lazyAttrsOf (types.nullOr types.str);
        description = ''
          Default profile settings section compiler properties.
        '';
        defaultText = lib.literalExpression ''
          lib.optionalAttrs defaults.enable {
            "compiler" = stdenv.cc.cc.pname;
            "compiler.cppstd" = "20";
            "compiler.libcxx" =
              if (stdenv.cc.isClang && stdenv.cc.libcxx.isLLVM or false)
              then "libc++"
              else "libstdc++11";
            "compiler.version" = stdenv.cc.version;
          }'';
      };

      settings._ = mkOption {
        type = types.lazyAttrsOf (types.nullOr types.str);
        description = ''
          Default profile settings section properties (other than compiler).
        '';
        defaultText = lib.literalExpression ''
          lib.optionalAttrs defaults.enable {
            arch = parseSystemArch { throwImpl = (_: null); } stdenv.system;
            build_type = "Release";
            os = parseSystemOs { throwImpl = (_: null); } stdenv.system;
          }'';
      };

      conf = mkOption {
        type = types.lazyAttrsOf (types.nullOr types.str);
        description = ''
          Default profile conf section properties.
        '';
        defaultText = lib.literalExpression ''
          lib.optionalAttrs defaults.enable { }
            // lib.optionalAttrs (stdenv.cc.isClang && stdenv.cc.libcxx.isLLVM or false) {
            "tools.build:compiler_executables" = "{'c': ''\'''${getExe stdenv.cc}', 'cpp': ''\'''${dirOf (getExe stdenv.cc)}/clang++'}";
          }
            // lib.optionalAttrs (contains "CMakeUserPresets" generators) {
            "tools.cmake.cmaketoolchain:user_presets" =
              "{{ os.path.join(os.getenv(\"CONAN_FLAKE_HOME\"), \"CMakeUserPresets.json\") }}";
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
              "''${stdenv.cc.cc.pname}".version = [
                stdenv.cc.cc.version
              ];
            }
            {
              "''${pkgs.gccStdenv.cc.cc.pname}".version.__append = [
                pkgs.gccStdenv.cc.version
              ];
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
      devShell.tools = mkDefault (
        lib.optionalAttrs config.defaults.enable {
          conan = config.package;
          cmake = pkgs.cmake;
          "${config.stdenv.cc.cc.pname}" = config.stdenv.cc;
          inherit (config.outputs.packages) infoWrapper;
          inherit (config.outputs.packages) configHomeWrapper;
          inherit (config.outputs.packages) runPreConfigInstallHookWrapper;
          inherit (config.outputs.packages) configInstallWrapper;
          inherit (config.outputs.packages) conanWrapper;
          inherit (config.outputs.packages) lockCreateWrapper;
          inherit (config.outputs.packages) lockExtendWrapper;
          inherit (config.outputs.packages) installBuildMissingWrapper;
          inherit (config.outputs.packages) allWrapper;
        }
      );

      profiles = {
        settings.compiler = mkDefault (
          lib.optionalAttrs config.defaults.enable {
            "compiler" = config.stdenv.cc.cc.pname;
            "compiler.cppstd" = "20";
            "compiler.libcxx" = if isClangLibcxxLLVM then "libc++" else "libstdc++11";
            "compiler.version" = config.stdenv.cc.version;
          }
        );

        settings._ = mkDefault (
          lib.optionalAttrs config.defaults.enable {
            arch = parseSystemArch { throwImpl = (_: null); } config.stdenv.system;
            build_type = "Release";
            os = parseSystemOs { throwImpl = (_: null); } config.stdenv.system;
          }
        );

        conf = mkDefault (
          lib.optionalAttrs config.defaults.enable { }
          // lib.optionalAttrs isClangLibcxxLLVM {
            "tools.build:compiler_executables" = "{${c}, ${cpp}}";
          }

          // lib.optionalAttrs (contains "CMakeUserPresets" config.generators) {
            "tools.cmake.cmaketoolchain:user_presets" =
              "{{ os.path.join(os.getenv(\"CONAN_FLAKE_HOME\"), \"CMakeUserPresets.json\") }}";
          }
        );

        platformToolRequires = mkDefault (
          lib.optionalAttrs config.defaults.enable { }
          // lib.optionalAttrs ((config.final.devShell.tools.cmake or null) != null) {
            cmake = config.final.devShell.tools.cmake.version;
          }
        );
      };

      settings.compiler = mkDefault (
        lib.optionalAttrs config.defaults.enable (
          infuse
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
              }
            )
            {
              "${pkgs.cudaPackages.backendStdenv.cc.cc.pname}".version.__append = [
                pkgs.cudaPackages.backendStdenv.cc.cc.version
              ];
            }
        )
      );
    };
  };
}
