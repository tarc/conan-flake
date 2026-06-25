{
  # Test: use conan-flake without devenv, via the `flake-parts` module only.
  inputs = {
    nixpkgs.url = "github:cachix/devenv-nixpkgs/ec3063523dcd911aeadb50faa589f237cdab5853";
    flake-parts.url = "github:hercules-ci/flake-parts/3107b77cd68437b9a76194f0f7f9c55f2329ca5b";
    conan-flake = { };
    infuse = {
      url = "git+https://codeberg.org/amjoseph/infuse.nix?rev=e837ece1b9de6ebcb7abd261f54a09bad3a2f820";
      flake = false;
    };
  };

  outputs =
    inputs@{
      self,
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
          inherit (pkgs.lib) escapeShellArg;
          configLocal = "CONFIGLOCAL";
          conanHome = "./CONANHOME";
          profiles = {
            settings.compiler = {
              "compiler.cppstd" = "14";
              "compiler.libcxx" = "libstdc++11";
            };
            settings.rest.build_type = "Release";
            platformToolRequires.cmake = pkgs.cmake.version;
          };
          cfg = config.conan;
        in
        {
          conan = {
            defaults.enable = false;

            inherit configLocal conanHome profiles;

            settings.compiler = {
              "${cfg.stdenv.cc.cc.pname}".version.__assign = [ cfg.stdenv.cc.version ];
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

                      ! ${baseNameOf (lib.getExe cfg.package)}

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
                        | grep -F ${escapeShellArg cfg.stdenv.cc.version}

                      cat ${escapeShellArg cfg.configLocal}"/profiles/default" \
                        | grep -F "build_type="${escapeShellArg cfg.final.profiles.settings.rest.build_type}
                      cat ${escapeShellArg cfg.configLocal}"/profiles/default" \
                        | grep -F "compiler.cppstd="${
                          escapeShellArg cfg.final.profiles.settings.compiler."compiler.cppstd"
                        }
                      cat ${escapeShellArg cfg.configLocal}"/profiles/default" \
                        | grep -F "compiler.libcxx="${
                          escapeShellArg cfg.final.profiles.settings.compiler."compiler.libcxx"
                        }

                      cat ${escapeShellArg cfg.configLocal}"/profiles/default" \
                        | grep -F "[platform_tool_requires]"
                      cat ${escapeShellArg cfg.configLocal}"/profiles/default" \
                        | grep -F "cmake/"${escapeShellArg cfg.final.profiles.platformToolRequires.cmake}

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
                  | grep -F ${escapeShellArg cfg.stdenv.cc.version}

                cat "${configuration}/config/profiles/default" \
                  | grep -F "build_type="${escapeShellArg profiles.settings.rest.build_type}
                cat "${configuration}/config/profiles/default" \
                  | grep -F "compiler.cppstd="${escapeShellArg profiles.settings.compiler."compiler.cppstd"}
                cat "${configuration}/config/profiles/default" \
                  | grep -F "compiler.libcxx="${escapeShellArg profiles.settings.compiler."compiler.libcxx"}

                cat "${configuration}/config/profiles/default" \
                  | grep -F "[platform_tool_requires]"
                cat "${configuration}/config/profiles/default" \
                  | grep -F "cmake/"${escapeShellArg cfg.final.profiles.platformToolRequires.cmake}

                touch $out
                )
              '';
          };
        };
    };
}
