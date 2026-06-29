{
  # Test: use conan-flake without devenv, via the `flake-parts` module only.
  inputs = {
    nixpkgs.url = "github:cachix/devenv-nixpkgs/ec3063523dcd911aeadb50faa589f237cdab5853";
    flake-parts.url = "github:hercules-ci/flake-parts/3107b77cd68437b9a76194f0f7f9c55f2329ca5b";
    conan-flake = { };
    infuse = {
      url = "git+https://codeberg.org/amjoseph/infuse.nix?rev=364ea18b5611b5fd6a6acd7151411b430a70e194";
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
          getCommand = package: baseNameOf (lib.getExe package);
          inherit (pkgs.lib) escapeShellArg;
          configLocal = "CONFIGLOCAL";
          conanHome = "./CONANHOME";
          profiles = {
            settings.compiler = {
              "compiler.cppstd" = "14";
              "compiler.libcxx" = "libstdc++11";
            };
            settings.rest = {
              build_type = "Release";
              os = null;
            };
          };
          overridingCmd = pkgs.writeShellApplication {
            name = "overriding-cmd";

            runtimeInputs = [ ];

            text = ''
              echo overridingCmd "$@"
            '';
          };
          cfg = config.conan;
        in
        {
          conan = {
            defaults.enable = true;

            inherit configLocal conanHome profiles;

            package = overridingCmd;

            devShell = {
              tools = {
                conan = overridingCmd;
              };
            };

            offline = true;

            checks = {
              testConanPackage = {
                enable = true;
                drv =
                  inputs.conan-flake.lib.runCommandWithInSimulatedShell pkgs cfg.stdenv cfg.outputs.devShell
                    cfg.info.configRoot
                    "./config"
                    "flake-parts-override-default-cmd-test-conan-profile"
                    { }
                    ''
                      (
                      set -x
                      echo "Testing test/flake-parts-override-default-cmd ..."

                      echo "Checking Conan is not on path..."

                      echo "Package: "${getCommand cfg.package}

                      ${getCommand cfg.package} | grep -F "overridingCmd"

                      touch $out
                      )
                    '';
              };

              testLocalSetup = {
                enable = true;
                drv =
                  let
                    stdenv = pkgs.gccStdenv;
                    backendStdenv = pkgs.cudaPackages.backendStdenv;
                    llvmPackages = pkgs.llvmPackages;
                  in
                  inputs.conan-flake.lib.runCommandWithInSimulatedShell pkgs cfg.stdenv cfg.outputs.devShell
                    cfg.info.configRoot
                    "./config"
                    "flake-parts-override-default-cmd-test-local-setup"
                    { }
                    ''
                      (
                      set -x
                      echo "Testing test/flake-parts-override-default-cmd ..."

                      echo "Checking local setup..."

                      cat ${escapeShellArg cfg.configLocal}"/settings_user.yml" \
                        | grep -F ${escapeShellArg stdenv.cc.version}
                      cat ${escapeShellArg cfg.configLocal}"/settings_user.yml" \
                        | grep -F ${escapeShellArg backendStdenv.cc.version}
                      cat ${escapeShellArg cfg.configLocal}"/settings_user.yml" \
                        | grep -F ${escapeShellArg llvmPackages.libcxxStdenv.cc.version}

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

                      ! cat ${escapeShellArg cfg.configLocal}"/profiles/default" \
                        | grep -F "os="

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
                stdenv = pkgs.gccStdenv;
                backendStdenv = pkgs.cudaPackages.backendStdenv;
                llvmPackages = pkgs.llvmPackages;
              in
              pkgs.runCommand "flake-parts-override-default-cmd-test-configuration-package" { } ''
                (
                set -x
                echo "Testing test/flake-parts-override-default-cmd ..."

                echo "Checking configuration package..."

                cat "${configuration}/config/settings_user.yml" \
                  | grep -F ${escapeShellArg stdenv.cc.version}
                cat "${configuration}/config/settings_user.yml" \
                  | grep -F ${escapeShellArg backendStdenv.cc.version}
                cat "${configuration}/config/settings_user.yml" \
                  | grep -F ${escapeShellArg llvmPackages.libcxxStdenv.cc.version}

                cat "${configuration}/config/profiles/default" \
                  | grep -F "build_type="${escapeShellArg profiles.settings.rest.build_type}
                cat "${configuration}/config/profiles/default" \
                  | grep -F "compiler.cppstd="${escapeShellArg profiles.settings.compiler."compiler.cppstd"}
                cat "${configuration}/config/profiles/default" \
                  | grep -F "compiler.libcxx="${escapeShellArg profiles.settings.compiler."compiler.libcxx"}

                ! cat "${configuration}/config/profiles/default" \
                  | grep -F "os="

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
