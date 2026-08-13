{
  # Test: use conan-flake without devenv, via the `flake-parts` module only.
  inputs = {
    nixpkgs.url = "github:cachix/devenv-nixpkgs/12866ae2dddbc0ab8b329915f8072bb9c75bde89";
    flake-parts.url = "github:hercules-ci/flake-parts/f7c1a2d347e4c52d5fb8d10cb4d94b5884e546fb";
    conan-flake = { };
    infuse = {
      url = "git+https://codeberg.org/amjoseph/infuse.nix?rev=364ea18b5611b5fd6a6acd7151411b430a70e194";
      flake = false;
    };
  };

  outputs =
    inputs@{
      nixpkgs,
      flake-parts,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } {

      imports = [
        inputs.conan-flake.flakeModule
      ];

      systems = nixpkgs.lib.systems.flakeExposed;

      perSystem =
        {
          pkgs,
          lib,
          config,
          ...
        }:
        let
          inherit (lib) escapeShellArg;

          # Asserts `line` is a line of its own in `file`.
          #
          # No `test -f` guard: a missing `file` makes `grep` exit 2, which is
          # already a failure for a positive assertion. The pattern is still
          # passed with `-e` so that a leading `-` cannot be taken for an
          # option.
          hasLine = file: line: "grep -qxF -e ${escapeShellArg line} -- ${escapeShellArg file}";

          # Asserts `command` is not on `PATH`.
          #
          # Spelled as an `if`, and never as `! <command>`: besides being
          # ignored by `set -e`, running the command asserts "it failed", not
          # "it is absent" (`conan` with no arguments prints its help and
          # succeeds).
          lacksCommand = command: ''
            if command -v ${escapeShellArg command}; then
              echo "unexpected command on PATH:" ${escapeShellArg command} >&2
              exit 1
            fi'';

          configLocal = "CONFIGLOCAL";
          conanHome = "./CONANHOME";
          profiles.default = {
            settings = {
              build_type = "Release";
              "compiler.cppstd" = "14";
              "compiler.libcxx" = "libstdc++11";
            };
            platformToolRequires.cmake = pkgs.cmake.version;
          };
          cfg = config.conan;
        in
        {
          conan = {
            defaults.enable = false;

            inherit configLocal conanHome profiles;

            settings.compiler = {
              "${inputs.conan-flake.lib.pnameFromStdenvCc lib cfg.stdenv}".version.__assign = [
                (inputs.conan-flake.lib.versionFromStdenvCc lib cfg.stdenv)
              ];
            };

            offline = true;

            checks = {
              testConanPackage = {
                enable = true;
                drv =
                  inputs.conan-flake.lib.runCommandWithInSimulatedShell pkgs cfg.stdenv cfg.outputs.devShell
                    cfg.info.configRoot
                    "./config"
                    "flake-parts-no-defaults-test-conan-profile"
                    { }
                    ''
                      (
                      set -x
                      echo "Testing test/flake-parts-no-defaults ..."

                      echo "Checking Conan is not on path..."

                      echo "Package: "${escapeShellArg (baseNameOf (lib.getExe cfg.package))}

                      ${lacksCommand (baseNameOf (lib.getExe cfg.package))}

                      touch $out
                      )
                    '';
              };

              testLocalSetup = {
                enable = true;
                drv =
                  inputs.conan-flake.lib.runCommandWithInSimulatedShell pkgs cfg.stdenv cfg.outputs.devShell
                    cfg.info.configRoot
                    "./config"
                    "flake-parts-no-defaults-test-local-setup"
                    { }
                    ''
                      (
                      set -x
                      echo "Testing test/flake-parts-no-defaults ..."

                      echo "Checking local setup..."

                      cat ${escapeShellArg cfg.configLocal}"/settings_user.yml" \
                        | grep -F ${escapeShellArg (inputs.conan-flake.lib.pnameFromStdenvCc lib cfg.stdenv)}

                      ${hasLine "${cfg.configLocal}/global.conf" "core.graph:compatibility_mode=optimized"}

                      ${hasLine "${cfg.configLocal}/profiles/default" "build_type=${cfg.final.profiles.default.settings.build_type}"}
                      ${hasLine "${cfg.configLocal}/profiles/default" "compiler.cppstd=${
                        cfg.final.profiles.default.settings."compiler.cppstd"
                      }"}
                      ${hasLine "${cfg.configLocal}/profiles/default" "compiler.libcxx=${
                        cfg.final.profiles.default.settings."compiler.libcxx"
                      }"}

                      ${hasLine "${cfg.configLocal}/profiles/default" "[platform_tool_requires]"}
                      ${hasLine "${cfg.configLocal}/profiles/default" "cmake/${cfg.final.profiles.default.platformToolRequires.cmake}"}

                      touch $out
                      )
                    '';
              };
            };
          };

          checks = {
            testConfigurationPackage =
              let
                configuration = cfg.outputs.packages.configuration;
              in
              pkgs.runCommand "flake-parts-no-defaults-test-configuration-package" { } ''
                (
                set -x
                echo "Testing test/flake-parts-no-defaults ..."

                echo "Checking configuration package..."

                cat "${configuration}/config/settings_user.yml" \
                  | grep -F ${escapeShellArg (inputs.conan-flake.lib.pnameFromStdenvCc lib cfg.stdenv)}

                ${hasLine "${configuration}/config/global.conf" "core.graph:compatibility_mode=optimized"}

                ${hasLine "${configuration}/config/profiles/default" "build_type=${profiles.default.settings.build_type}"}
                ${hasLine "${configuration}/config/profiles/default" "compiler.cppstd=${
                  profiles.default.settings."compiler.cppstd"
                }"}
                ${hasLine "${configuration}/config/profiles/default" "compiler.libcxx=${
                  profiles.default.settings."compiler.libcxx"
                }"}

                ${hasLine "${configuration}/config/profiles/default" "[platform_tool_requires]"}
                ${hasLine "${configuration}/config/profiles/default" "cmake/${cfg.final.profiles.default.platformToolRequires.cmake}"}

                touch $out
                )
              '';
          };
        };
    };
}
