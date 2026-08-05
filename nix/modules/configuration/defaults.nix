# A module representing the default values used internally by conan-flake.
{
  lib,
  pkgs,
  config,
  infuse,
  parseSystemArch,
  parseSystemOs,
  contains,
  pnameFromStdenvCc,
  versionFromStdenvCc,
  embedmdPackage,
  mdshPackage,
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
          "''${pnameFromStdenvCc stdenv}" = stdenv.cc;
          inherit (outputs.packages) infoWrapper;
          inherit (outputs.packages) configHomeWrapper;
          inherit (outputs.packages) runPreConfigInstallHookWrapper;
          inherit (outputs.packages) configInstallWrapper;
          inherit (outputs.packages) profileShowWrapper;
          inherit (outputs.packages) conanWrapper;
          inherit (outputs.packages) lockCreateWrapper;
          inherit (outputs.packages) lockExtendWrapper;
          inherit (outputs.packages) createLockInstallWrapper;
          inherit (outputs.packages) buildWrapper;
          inherit (outputs.packages) allWrapper;
        }'';
    };

    # These defaults are a single, global set, merged into every profile
    # declared in `profiles`.
    profiles = {
      settings.compiler = mkOption {
        type = types.lazyAttrsOf (types.nullOr types.str);
        description = ''
          Default profile settings section compiler properties, merged into
          every profile.
        '';
        defaultText = lib.literalExpression ''
          lib.optionalAttrs defaults.enable {
            "compiler" = pnameFromStdenvCc stdenv;
            "compiler.cppstd" = "20";
            "compiler.libcxx" =
              if (stdenv.cc.isClang && stdenv.cc.libcxx.isLLVM or false)
              then "libc++"
              else "libstdc++11";
            "compiler.version" = versionFromStdenvCc stdenv;
          }'';
      };

      settings._ = mkOption {
        type = types.lazyAttrsOf (types.nullOr types.str);
        description = ''
          Default profile settings section properties (other than compiler),
          merged into every profile.
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
          Default profile conf section properties, merged into every profile.
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
          Default profile platform tool requires, merged into every profile.
        '';
        defaultText = lib.literalExpression ''
          lib.optionalAttrs defaults.enable { }
            // lib.optionalAttrs ((final.devShell.tools.cmake or null) != null) {
            cmake = final.devShell.tools.cmake.version;
          }'';
      };
    };

    settings = {
      compiler = mkOption {
        type = types.attrs;
        description = ''
          Default Conan user settings compiler properties (compiler section in `settings_user.yml`).
        '';
        defaultText = lib.literalExpression ''
          lib.optionalAttrs defaults.enable infuse
            (infuse
              {
                "''${pnameFromStdenvCc stdenv}".version = [
                  (versionFromStdenvCc stdenv)
                ];
              }
              {
                "''${pnameFromStdenvCc pkgs.gccStdenv}".version.__append = [
                  (versionFromStdenvCc pkgs.gccStdenv)
                ];
                "''${pnameFromStdenvCc pkgs.llvmPackages.libcxxStdenv}".version.__append = [
                  (versionFromStdenvCc pkgs.llvmPackages.libcxxStdenv)
                ];
              })
            {
              "''${pnameFromStdenvCc pkgs.cudaPackages.backendStdenv}".version.__append = [
                (versionFromStdenvCc pkgs.cudaPackages.backendStdenv)
              ];
            }'';
      };

      core = mkOption {
        type = types.attrs;
        description = ''
          Default Conan `global.conf` core properties (configuration variables
          matching the "core.*" pattern).
        '';
        default = {
          "graph:compatibility_mode" = "optimized";
        };
      };

      tools = mkOption {
        type = types.attrs;
        description = ''
          Default Conan `global.conf` tools properties (configuration variables
          matching the "tools.*" pattern).
        '';
        default = { };
      };

      user = mkOption {
        type = types.attrs;
        description = ''
          Default Conan `global.conf` user properties (configuration variables
          matching the "user.*" pattern).
        '';
        default = { };
      };
    };
  };

  config = {
    defaults = {
      devShell.tools = mkDefault (
        lib.optionalAttrs config.defaults.enable {
          conan = config.package;
          cmake = pkgs.cmake;
          embedmd = embedmdPackage pkgs;
          mdsh = mdshPackage pkgs;
          "${pnameFromStdenvCc config.stdenv}" = config.stdenv.cc;
          inherit (config.outputs.packages) infoWrapper;
          inherit (config.outputs.packages) configHomeWrapper;
          inherit (config.outputs.packages) runPreConfigInstallHookWrapper;
          inherit (config.outputs.packages) configInstallWrapper;
          inherit (config.outputs.packages) profileShowWrapper;
          inherit (config.outputs.packages) conanWrapper;
          inherit (config.outputs.packages) lockCreateWrapper;
          inherit (config.outputs.packages) lockExtendWrapper;
          inherit (config.outputs.packages) createLockInstallWrapper;
          inherit (config.outputs.packages) buildWrapper;
          inherit (config.outputs.packages) allWrapper;
        }
      );

      profiles = {
        settings.compiler = mkDefault (
          lib.optionalAttrs config.defaults.enable {
            "compiler" = pnameFromStdenvCc config.stdenv;
            "compiler.cppstd" = "20";
            "compiler.libcxx" = if isClangLibcxxLLVM then "libc++" else "libstdc++11";
            "compiler.version" = versionFromStdenvCc config.stdenv;
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
                "${pnameFromStdenvCc config.stdenv}".version = [
                  (versionFromStdenvCc config.stdenv)
                ];
              }
              {
                "${pnameFromStdenvCc pkgs.gccStdenv}".version.__append = [
                  (versionFromStdenvCc pkgs.gccStdenv)
                ];
                "${pnameFromStdenvCc pkgs.llvmPackages.libcxxStdenv}".version.__append = [
                  (versionFromStdenvCc pkgs.llvmPackages.libcxxStdenv)
                ];
              }
            )
            {
              "${pnameFromStdenvCc pkgs.cudaPackages.backendStdenv}".version.__append = [
                (versionFromStdenvCc pkgs.cudaPackages.backendStdenv)
              ];
            }
        )
      );
    };
  };
}
