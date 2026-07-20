{
  # Test: use conan-flake without devenv and `flake-parts`, via the standalone nix module.
  inputs = {
    nixpkgs.url = "github:cachix/devenv-nixpkgs/12866ae2dddbc0ab8b329915f8072bb9c75bde89";
    conan-flake = { };
  };
  outputs =
    {
      self,
      nixpkgs,
      conan-flake,
      ...
    }:
    let
      eachSystem = nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed;

      perSystem =
        system:
        let
          configLocal = "CONFIGLOCAL";
          conanHome = "./CONANHOME";
          profiles = {
            settings.compiler = {
              "compiler.cppstd" = "14";
              "compiler.libcxx" = "libstdc++11";
            };
            settings._.build_type = "Release";
          };

          pkgs = nixpkgs.legacyPackages.${system};
          conan = conan-flake.lib.evalConanConfig pkgs (
            {
              pkgs,
              config,
              lib,
              ...
            }:
            let
              inherit (lib) escapeShellArg;
            in
            {
              inherit configLocal conanHome profiles;
              configRoot = self;
              offline = true;
              checks = {
                testLocalSetup = {
                  enable = true;
                  drv =
                    let
                      backendStdenv = pkgs.cudaPackages.backendStdenv;
                      llvmPackages = pkgs.llvmPackages;
                    in
                    conan-flake.lib.runCommandWithInSimulatedShell pkgs config.stdenv config.outputs.devShell
                      config.info.configRoot
                      "./config"
                      "standalone-test-local-setup"
                      { }
                      ''
                        (
                        set -x
                        echo "Testing test/standalone ..."

                        echo "Checking local setup..."

                        cat ${escapeShellArg configLocal}"/settings_user.yml" \
                          | grep -F ${escapeShellArg (conan-flake.lib.versionFromStdenvCc lib pkgs.gccStdenv)}
                        cat ${escapeShellArg configLocal}"/settings_user.yml" \
                          | grep -F ${escapeShellArg (conan-flake.lib.versionFromStdenvCc lib backendStdenv)}
                        cat ${escapeShellArg configLocal}"/settings_user.yml" \
                          | grep -F ${escapeShellArg (conan-flake.lib.versionFromStdenvCc lib llvmPackages.libcxxStdenv)}

                        cat ${escapeShellArg configLocal}"/profiles/default" \
                          | grep -F "build_type="${escapeShellArg profiles.settings._.build_type}
                        cat ${escapeShellArg configLocal}"/profiles/default" \
                          | grep -F "compiler.cppstd="${escapeShellArg profiles.settings.compiler."compiler.cppstd"}
                        cat ${escapeShellArg configLocal}"/profiles/default" \
                          | grep -F "compiler.libcxx="${escapeShellArg profiles.settings.compiler."compiler.libcxx"}

                        cat ${escapeShellArg configLocal}"/profiles/default" \
                          | grep -F "[platform_tool_requires]"
                        cat ${escapeShellArg configLocal}"/profiles/default" \
                          | grep -F "cmake/"${escapeShellArg pkgs.cmake.version}

                        touch $out
                        )
                      '';
                };

                testConanInstall = {
                  enable = true;
                  drv =
                    let
                      inherit (pkgs) stdenv;
                      parseSystemArch = conan-flake.lib.parsing.parseSystemArch { };
                      parseSystemOs = conan-flake.lib.parsing.parseSystemOs { };
                    in
                    conan-flake.lib.runCommandWithInSimulatedShell pkgs config.stdenv config.outputs.devShell
                      config.info.configRoot
                      "./config"
                      "standalone-test-conan-profile"
                      { }
                      ''
                        (
                        set -x
                        echo "Testing test/standalone ..."

                        echo "Checking Conan profile..."

                        conan config home | grep ${escapeShellArg conanHome}
                        conan remote list | grep "conancenter.*Verify SSL: True, Enabled: False"

                        conan profile show | grep -F "arch="${escapeShellArg (parseSystemArch stdenv.system)}
                        conan profile show | grep -F "build_type="${escapeShellArg profiles.settings._.build_type}
                        conan profile show | grep -F "compiler="${escapeShellArg (conan-flake.lib.pnameFromStdenvCc lib stdenv)}
                        conan profile show \
                          | grep -F "compiler.cppstd="${escapeShellArg profiles.settings.compiler."compiler.cppstd"}
                        conan profile show \
                          | grep -F "compiler.libcxx="${escapeShellArg profiles.settings.compiler."compiler.libcxx"}
                        conan profile show | grep -F "compiler.version="${escapeShellArg (conan-flake.lib.versionFromStdenvCc lib stdenv)}
                        conan profile show | grep -F "os="${escapeShellArg (parseSystemOs stdenv.system)}
                        conan profile show | grep -F "cmake/"${escapeShellArg pkgs.cmake.version}

                        touch $out
                        )
                      '';
                };
              };
            }
          );
        in
        {
          packages = conan.config.outputs.packages;
          devShells.default = conan.config.outputs.devShell;
          checks = conan.config.outputs.checks // {
            testConfigurationPackage =
              let
                inherit (pkgs.lib) escapeShellArg;
                configuration = conan.config.outputs.packages.configuration;
                stdenv = pkgs.gccStdenv;
                backendStdenv = pkgs.cudaPackages.backendStdenv;
                llvmPackages = pkgs.llvmPackages;
              in
              pkgs.runCommand "standalone-test-configuration-package" { } ''
                (
                set -x
                echo "Testing test/standalone ..."

                echo "Checking configuration package..."


                cat "${configuration}/config/settings_user.yml" \
                  | grep -F ${escapeShellArg (conan-flake.lib.versionFromStdenvCc pkgs.lib stdenv)}
                cat "${configuration}/config/settings_user.yml" \
                  | grep -F ${escapeShellArg (conan-flake.lib.versionFromStdenvCc pkgs.lib backendStdenv)}
                cat "${configuration}/config/settings_user.yml" \
                  | grep -F ${escapeShellArg (conan-flake.lib.versionFromStdenvCc pkgs.lib llvmPackages.libcxxStdenv)}

                cat "${configuration}/config/profiles/default" \
                  | grep -F "build_type="${escapeShellArg profiles.settings._.build_type}
                cat "${configuration}/config/profiles/default" \
                  | grep -F "compiler.cppstd="${escapeShellArg profiles.settings.compiler."compiler.cppstd"}
                cat "${configuration}/config/profiles/default" \
                  | grep -F "compiler.libcxx="${escapeShellArg profiles.settings.compiler."compiler.libcxx"}

                cat "${configuration}/config/profiles/default" \
                  | grep -F "[platform_tool_requires]"
                cat "${configuration}/config/profiles/default" \
                  | grep -F "cmake/"${escapeShellArg pkgs.cmake.version}

                touch $out
                )
              '';
          };
        };

      systemOutputs = eachSystem perSystem;
    in
    {
      packages = nixpkgs.lib.mapAttrs (_: s: s.packages) systemOutputs;
      devShells = nixpkgs.lib.mapAttrs (_: s: s.devShells) systemOutputs;
      checks = nixpkgs.lib.mapAttrs (_: s: s.checks) systemOutputs;
    };
}
