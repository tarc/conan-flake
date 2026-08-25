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
    # defaults.PROFILE.2-1
    profiles = mkOption {
      type = types.deferredModule;

      description = ''
        Default configuration for every profile's `settings`, `options`,
        `toolRequires`, `buildEnv`, `runEnv`, `conf`, `replaceRequires`,
        `replaceToolRequires` and `platformRequires`/`platformToolRequires`
        sections (see `./profile.nix`, whose own option declarations describe
        each section's shape and rendering in detail).

        For every section except `buildEnv`/`runEnv`, each entry must be
        wrapped in `lib.mkDefault` (defaults.PROFILE.2): this option is merged
        into each profile's own configuration via the module system's native
        option priority, not by a deterministic "the profile always wins"
        rule, so an entry assigned without `lib.mkDefault` is indistinguishable
        in priority from a profile's own entry, and conflicts with (rather
        than yields to) a profile assigning that same entry -- including to
        remove it with `null`. `buildEnv`/`runEnv` are exempt
        (defaults.PROFILE.2-1): being lists, they are merged the same way a
        profile's own entries are merged against them (profile.PROFILE.2),
        independently of `lib.mkDefault`.

        Like `profiles.<name>` (profile.PROFILE.1-1), `options` is a reserved
        top-level attribute name for a Nix module: since this option is one
        flat definition, not one named entry per profile, setting `options`
        alongside any other section means the *entire* definition must nest
        under `config` (`defaults.profiles.config = { options = ...; <other
        section> = ...; };`), not just `options` on its own -- nesting only
        `options` while leaving sibling sections at the top level is itself
        invalid. If `options` is the only section a definition sets, writing
        it directly (`defaults.profiles.options = ...;`) does not error: it
        silently renders an empty `[options]` section instead of the declared
        entries, so `config.options` should always be used regardless.
      '';

      # The whole example nests under `config`, not just `settings`'s sibling
      # `options`: `defaults.profiles` is one flat definition, not one named
      # entry per profile (contrast `profiles`' own example, where each
      # section gets its own named profile, so only `optionsEx` ever needs
      # `config.options`). Nesting only `options` here, with the remaining
      # sections left at the top level, is itself invalid -- see
      # `profile.PROFILE.1-1`.
      example = lib.literalExpression ''
        {
          config = {
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

            options = {
              "mylib/*:shared" = mkDefault "True";
            };

            toolRequires = {
              tool1 = mkDefault "0.1@user/channel";
            };

            # buildEnv/runEnv are exempt from the `lib.mkDefault` requirement
            # (defaults.PROFILE.2-1): being lists, they are merged against a
            # profile's own entries the same way regardless of `lib.mkDefault`.
            buildEnv = [
              {
                name = "CFLAGS";
                value = "-O2";
              }
            ];

            runEnv = [
              {
                name = "LD_LIBRARY_PATH";
                op = "+=(path)";
                value = "/opt/lib";
              }
            ];

            replaceRequires = {
              "zlib/1.2.12" = mkDefault "zlib/[*]";
            };

            replaceToolRequires = {
              "7zip/*" = mkDefault "7zip/system";
            };

            platformRequires = {
              dlib = mkDefault "1.3.22";
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
          };
        }
      '';

      # This option's own `default` is deliberately unset: this is the
      # general rule of every `mkOption`, for any type, not something specific
      # to `deferredModule` -- `default` is only ever used when there is no
      # definition anywhere in the module tree at all (see `mergeDefinitions`
      # in nixpkgs' `lib/modules.nix`), it is never merged alongside a
      # definition that does exist. What makes it easy to miss here is that
      # merging multiple definitions together is the very point of a
      # `deferredModule`-typed option, which makes a `default` silently
      # losing to the first real definition more surprising than usual. The
      # actual conan-flake defaults live in `config.defaults.profiles` below
      # instead, so they are just another contributing definition -- like any
      # profile-, test-, or user-provided one -- and so survive regardless of
      # what else defines this option.
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

      # conan-flake's own opinionated profile defaults, gated on
      # `defaults.enable` here rather than in `defaults.profiles`' own
      # `apply` (dropped): gating the whole option would discard a user's own
      # `defaults.profiles` contribution too, not just this one. Every entry
      # is individually wrapped in `mkDefault` (defaults.PROFILE.2), so that
      # any profile-, test-, or user-provided contribution to
      # `defaults.profiles` -- itself required to use `mkDefault` too, for the
      # same reason -- correctly takes precedence entry by entry, without the
      # two ever conflicting.
      profiles = lib.optionalAttrs config.defaults.enable {
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
