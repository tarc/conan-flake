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
    # declared in `profiles`. Every entry is typed lazily, so that its actual
    # type is only determined when that very entry survives the merge into a
    # profile.
    #
    # defaults.PROFILE.1
    # defaults.PROFILE.2
    profiles = mkOption {
      type = types.deferredModule;

      description = ''
        Default profile settings section properties, merged into every
        profile.

        Every entry must be wrapped in `lib.mkDefault`: this option is merged
        into each profile's own configuration via the module system's native
        option priority, not by a deterministic "the profile always wins"
        rule, so an entry assigned without `lib.mkDefault` is indistinguishable
        in priority from a profile's own entry, and conflicts with (rather
        than yields to) a profile assigning that same entry -- including to
        remove it with `null`.
      '';

      apply =
        profiles:
        if config.defaults.enable then
          {
            imports = [
              profiles
            ];
          }
        else
          { };

      example = lib.literalExpression ''
        {
          settings = {
            arch = mkDefault (parseSystemArch { throwImpl = (_: null); } stdenv.system);
            build_type = mkDefault "Release";
            "compiler" = mkDefault (pnameFromStdenvCc stdenv);
            "compiler.cppstd" = mkDefault "20";
            "compiler.libcxx" = mkDefault (
              if (stdenv.cc.isClang && stdenv.cc.libcxx.isLLVM or false)
              then "libc++"
              else "libstdc++11"
            );
            "compiler.version" = mkDefault (versionFromStdenvCc stdenv);
            os = mkDefault (parseSystemOs { throwImpl = (_: null); } stdenv.system);
          };

          conf = { }
            // lib.optionalAttrs isClangLibcxxLLVM {
              "tools.build:compiler_executables" = mkDefault "{'c': ''\'''${getExe stdenv.cc}', 'cpp': ''\'''${dirOf (getExe stdenv.cc)}/clang++'}";
            }

            // lib.optionalAttrs (contains "CMakeUserPresets" generators) {
              "tools.cmake.cmaketoolchain:user_presets" = mkDefault
                "{{ os.path.join(os.getenv(\"CONAN_FLAKE_HOME\"), \"CMakeUserPresets.json\") }}";
            };

          platformToolRequires = { }
            // lib.optionalAttrs ((final.devShell.tools.cmake or null) != null) {
              cmake = mkDefault final.devShell.tools.cmake.version;
            };
        }
      '';

      # This option's own `default` is deliberately unset: `mkOption`'s
      # `default` is discarded wholesale the moment any *other* module also
      # contributes a definition to a `deferredModule`-typed option, unlike a
      # regular module contribution, which is always merged alongside others
      # (see `deferredModule`'s own `imports`-based merge). The actual
      # conan-flake defaults live in `config.defaults.profiles` below instead,
      # so they are just another contributing definition -- like any profile-
      # or user-provided one -- and so survive regardless of what else
      # defines this option.
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

      # conan-flake's own opinionated profile defaults. Every entry is
      # individually wrapped in `mkDefault` (defaults.PROFILE.2), so that any
      # profile-, test-, or user-provided contribution to `defaults.profiles`
      # -- itself required to use `mkDefault` too, for the same reason --
      # correctly takes precedence entry by entry, without the two ever
      # conflicting.
      profiles = {
        settings = {
          arch = mkDefault (parseSystemArch { throwImpl = (_: null); } config.stdenv.system);
          build_type = mkDefault "Release";
          "compiler" = mkDefault (pnameFromStdenvCc config.stdenv);
          "compiler.cppstd" = mkDefault "20";
          "compiler.libcxx" = mkDefault (if isClangLibcxxLLVM then "libc++" else "libstdc++11");
          "compiler.version" = mkDefault (versionFromStdenvCc config.stdenv);
          os = mkDefault (parseSystemOs { throwImpl = (_: null); } config.stdenv.system);
        };

        conf =
          { }
          // lib.optionalAttrs isClangLibcxxLLVM {
            "tools.build:compiler_executables" = mkDefault "{${c}, ${cpp}}";
          }

          // lib.optionalAttrs (contains "CMakeUserPresets" config.generators) {
            "tools.cmake.cmaketoolchain:user_presets" =
              mkDefault "{{ os.path.join(os.getenv(\"CONAN_FLAKE_HOME\"), \"CMakeUserPresets.json\") }}";
          };

        platformToolRequires =
          { }
          // lib.optionalAttrs ((config.final.devShell.tools.cmake or null) != null) {
            cmake = mkDefault config.final.devShell.tools.cmake.version;
          };
      };
    };
  };
}
