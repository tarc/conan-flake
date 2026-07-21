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
          getCommand = package: baseNameOf (lib.getExe package);
          inherit (lib) escapeShellArg;
          configLocal = "CONFIGLOCAL";
          conanHome = "./CONANHOME";
          profiles = {
            settings.compiler = {
              "compiler.cppstd" = "14";
              "compiler.libcxx" = "libstdc++11";
            };
            settings._.build_type = "Release";
          };
          stdenv = pkgs.gccStdenv;
          backendStdenv = pkgs.cudaPackages.backendStdenv;
          backendStdenv_13_2 = pkgs.cudaPackages_13_2.backendStdenv;
          llvmPackages = pkgs.llvmPackages;
          cfg = config.conan;
        in
        {
          conan = {
            inherit configLocal conanHome profiles;

            devShell = {
              tools = {
                conan = null;
              };
            };

            settings.compiler = {
              "${inputs.conan-flake.lib.pnameFromStdenvCc lib llvmPackages.libcxxStdenv}".__assign = null;
              "${inputs.conan-flake.lib.pnameFromStdenvCc lib backendStdenv_13_2}".version.__append = [
                (inputs.conan-flake.lib.pnameFromStdenvCc lib backendStdenv_13_2)
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
                    "flake-parts-override-default-test-conan-profile"
                    { }
                    ''
                      (
                      set -x
                      echo "Testing test/flake-parts-override-default ..."

                      echo "Checking Conan is not on path..."

                      echo "Package: "${getCommand cfg.package}

                      ! ${getCommand cfg.package}

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
                    "flake-parts-override-default-test-local-setup"
                    { }
                    ''
                      (
                      set -x
                      echo "Testing test/flake-parts-override-default ..."

                      echo "Checking local setup..."

                      cat ${escapeShellArg cfg.configLocal}"/settings_user.yml" \
                        | grep -F ${escapeShellArg (inputs.conan-flake.lib.versionFromStdenvCc lib stdenv)}
                      cat ${escapeShellArg cfg.configLocal}"/settings_user.yml" \
                        | grep -F ${escapeShellArg (inputs.conan-flake.lib.versionFromStdenvCc lib backendStdenv)}

                      ! cat ${escapeShellArg cfg.configLocal}"/settings_user.yml" \
                        | grep -F ${escapeShellArg (inputs.conan-flake.lib.versionFromStdenvCc lib llvmPackages.libcxxStdenv)}

                      cat ${escapeShellArg cfg.configLocal}"/settings_user.yml" \
                        | grep -F ${escapeShellArg (inputs.conan-flake.lib.versionFromStdenvCc lib backendStdenv_13_2)}

                      cat ${escapeShellArg cfg.configLocal}"/global.conf" \
                        | grep -F "core.graph:compatibility_mode" \
                        | grep -F "optimized"

                      cat ${escapeShellArg cfg.configLocal}"/profiles/default" \
                        | grep -F "build_type="${escapeShellArg cfg.final.profiles.settings._.build_type}
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
              pkgs.runCommand "flake-parts-override-default-test-configuration-package" { } ''
                (
                set -x
                echo "Testing test/flake-parts-override-default ..."

                echo "Checking configuration package..."

                cat "${configuration}/config/settings_user.yml" \
                  | grep -F ${escapeShellArg (inputs.conan-flake.lib.versionFromStdenvCc lib stdenv)}
                cat "${configuration}/config/settings_user.yml" \
                  | grep -F ${escapeShellArg (inputs.conan-flake.lib.versionFromStdenvCc lib backendStdenv)}

                ! cat "${configuration}/config/settings_user.yml" \
                  | grep -F ${escapeShellArg (inputs.conan-flake.lib.versionFromStdenvCc lib llvmPackages.libcxxStdenv)}

                cat "${configuration}/config/settings_user.yml" \
                  | grep -F ${escapeShellArg (inputs.conan-flake.lib.versionFromStdenvCc lib backendStdenv_13_2)}

                cat "${configuration}/config/global.conf" \
                  | grep -F "core.graph:compatibility_mode" \
                  | grep -F "optimized"

                cat "${configuration}/config/profiles/default" \
                  | grep -F "build_type="${escapeShellArg profiles.settings._.build_type}
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
