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
      flake-parts,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } {

      imports = [
        inputs.conan-flake.flakeModule
      ];

      systems = [ "x86_64-linux" ];

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
          profiles.settings = {
            compiler = {
              "compiler.cppstd" = "14";
              "compiler.libcxx" = "libstdc++11";
            };
            _.build_type = "Release";
          };
        in
        {
          conan = {
            inherit configLocal conanHome profiles;

            checks = {
              test = {
                enable = true;
                drv =
                  inputs.conan-flake.lib.runCommandWithInSimulatedShell pkgs config.conan.stdenv
                    config.conan.outputs.devShell
                    config.conan.info.configRoot
                    "./config"
                    "flake-parts-test-mutable-home"
                    { }
                    ''
                      (
                      set -x
                      echo "Testing test/flake-parts ..."

                      echo "Checking local development pipeline..."

                      conan profile show

                      touch $out
                      )
                    '';
              };

              testLocalSetup =
                let
                  cfg = config.conan;
                  stdenv = pkgs.gccStdenv;
                  backendStdenv = pkgs.cudaPackages.backendStdenv;
                  llvmPackages = pkgs.llvmPackages;
                in
                {
                  enable = true;
                  drv =
                    inputs.conan-flake.lib.runCommandWithInSimulatedShell pkgs config.conan.stdenv
                      config.conan.outputs.devShell
                      config.conan.info.configRoot
                      "./config"
                      "flake-parts-test-local-setup"
                      { }
                      ''
                        (
                        set -x
                        echo "Testing test/flake-parts ..."

                        echo "Checking local setup..."

                        cat ${escapeShellArg cfg.configLocal}"/settings_user.yml" \
                          | grep -F ${escapeShellArg (inputs.conan-flake.lib.versionFromStdenvCc lib stdenv)}
                        cat ${escapeShellArg cfg.configLocal}"/settings_user.yml" \
                          | grep -F ${escapeShellArg (inputs.conan-flake.lib.versionFromStdenvCc lib backendStdenv)}
                        cat ${escapeShellArg cfg.configLocal}"/settings_user.yml" \
                          | grep -F ${escapeShellArg (inputs.conan-flake.lib.versionFromStdenvCc lib llvmPackages.libcxxStdenv)}

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

              testConanProfile =
                let
                  cfg = config.conan;
                in
                {
                  enable = true;
                  drv =
                    inputs.conan-flake.lib.runCommandWithInSimulatedShell pkgs config.conan.stdenv
                      config.conan.outputs.devShell
                      config.conan.info.configRoot
                      "./config"
                      "flake-parts-test-conan-profile"
                      { }
                      ''
                        (
                        set -x
                        echo "Testing test/flake-parts ..."

                        echo "Checking Conan profile 1..."

                        echo "Package: "${getCommand cfg.package}

                        ${getCommand cfg.package} config home \
                          | grep ${escapeShellArg cfg.conanHome}
                        ${getCommand cfg.package} remote list \
                          | grep "conancenter.*Verify SSL: True, Enabled: False"

                        ${getCommand cfg.package} profile show \
                          | grep -F "arch="${escapeShellArg cfg.final.profiles.settings._.arch}
                        ${getCommand cfg.package} profile show \
                          | grep -F "build_type="${escapeShellArg cfg.final.profiles.settings._.build_type}
                        ${getCommand cfg.package} profile show \
                          | grep -F "compiler="${escapeShellArg cfg.final.profiles.settings.compiler."compiler"}
                        ${getCommand cfg.package} profile show \
                          | grep -F "compiler.cppstd="${
                            escapeShellArg cfg.final.profiles.settings.compiler."compiler.cppstd"
                          }
                        ${getCommand cfg.package} profile show \
                          | grep -F "compiler.libcxx="${
                            escapeShellArg cfg.final.profiles.settings.compiler."compiler.libcxx"
                          }
                        ${getCommand cfg.package} profile show \
                          | grep -F "compiler.version="${
                            escapeShellArg cfg.final.profiles.settings.compiler."compiler.version"
                          }
                        ${getCommand cfg.package} profile show \
                          | grep -F "os="${escapeShellArg cfg.final.profiles.settings._.os}
                        ${getCommand cfg.package} profile show \
                          | grep -F "cmake/"${escapeShellArg cfg.final.profiles.platformToolRequires.cmake}

                        touch $out
                        )
                      '';
                };

              testConanInstall =
                let
                  cfg = config.conan;
                in
                {
                  enable = true;
                  drv =
                    inputs.conan-flake.lib.runCommandWithInSimulatedShell pkgs config.conan.stdenv
                      config.conan.outputs.devShell
                      config.conan.info.configRoot
                      "./config"
                      "flake-parts-test-conan-profile"
                      { }
                      ''
                        (
                        set -x
                        echo "Testing test/flake-parts ..."

                        echo "Checking Conan profile 2..."

                        echo "Package: "${getCommand cfg.package}

                        ${getCommand cfg.package} config home \
                          | grep ${escapeShellArg cfg.conanHome}
                        ${getCommand cfg.package} remote list \
                          | grep "conancenter.*Verify SSL: True, Enabled: False"

                        ${getCommand cfg.package} profile show \
                          | grep -F "arch="${escapeShellArg cfg.final.profiles.settings._.arch}
                        ${getCommand cfg.package} profile show \
                          | grep -F "build_type="${escapeShellArg cfg.final.profiles.settings._.build_type}
                        ${getCommand cfg.package} profile show \
                          | grep -F "compiler="${escapeShellArg cfg.final.profiles.settings.compiler."compiler"}
                        ${getCommand cfg.package} profile show \
                          | grep -F "compiler.cppstd="${
                            escapeShellArg cfg.final.profiles.settings.compiler."compiler.cppstd"
                          }
                        ${getCommand cfg.package} profile show \
                          | grep -F "compiler.libcxx="${
                            escapeShellArg cfg.final.profiles.settings.compiler."compiler.libcxx"
                          }
                        ${getCommand cfg.package} profile show \
                          | grep -F "compiler.version="${
                            escapeShellArg cfg.final.profiles.settings.compiler."compiler.version"
                          }
                        ${getCommand cfg.package} profile show \
                          | grep -F "os="${escapeShellArg cfg.final.profiles.settings._.os}
                        ${getCommand cfg.package} profile show \
                          | grep -F "cmake/"${escapeShellArg cfg.final.profiles.platformToolRequires.cmake}

                        touch $out
                        )
                      '';
                };
            };

            offline = true;
          };

          checks = {
            testConfigurationPackage =
              let
                configuration = config.conan.outputs.packages.configuration;
                stdenv = pkgs.gccStdenv;
                backendStdenv = pkgs.cudaPackages.backendStdenv;
                llvmPackages = pkgs.llvmPackages;
              in
              pkgs.runCommand "flake-parts-test-configuration-package" { } ''
                (
                set -x
                echo "Testing test/flake-parts ..."

                echo "Checking configuration package..."

                cat "${configuration}/config/settings_user.yml" \
                  | grep -F ${escapeShellArg (inputs.conan-flake.lib.versionFromStdenvCc lib stdenv)}
                cat "${configuration}/config/settings_user.yml" \
                  | grep -F ${escapeShellArg (inputs.conan-flake.lib.versionFromStdenvCc lib backendStdenv)}
                cat "${configuration}/config/settings_user.yml" \
                  | grep -F ${escapeShellArg (inputs.conan-flake.lib.versionFromStdenvCc lib llvmPackages.libcxxStdenv)}

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
                  | grep -F "cmake/"${escapeShellArg config.conan.final.profiles.platformToolRequires.cmake}

                touch $out
                )
              '';
          };
        };
    };
}
