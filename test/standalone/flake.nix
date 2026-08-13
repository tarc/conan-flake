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
          inherit (nixpkgs.lib) escapeShellArg;

          # Asserts `line` is a line of its own in `file`.
          #
          # No `test -f` guard: a missing `file` makes `grep` exit 2, which is
          # already a failure for a positive assertion. The pattern is still
          # passed with `-e` so that a leading `-` cannot be taken for an
          # option.
          hasLine = file: line: "grep -qxF -e ${escapeShellArg line} -- ${escapeShellArg file}";

          configLocal = "CONFIGLOCAL";
          conanHome = "./CONANHOME";
          profiles.default = {
            settings = {
              build_type = "Release";
              "compiler.cppstd" = "14";
              "compiler.libcxx" = "libstdc++11";
            };
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

                        ${hasLine "${configLocal}/global.conf" "core.graph:compatibility_mode=optimized"}

                        ${hasLine "${configLocal}/profiles/default" "build_type=${profiles.default.settings.build_type}"}
                        ${hasLine "${configLocal}/profiles/default" "compiler.cppstd=${
                          profiles.default.settings."compiler.cppstd"
                        }"}
                        ${hasLine "${configLocal}/profiles/default" "compiler.libcxx=${
                          profiles.default.settings."compiler.libcxx"
                        }"}

                        ${hasLine "${configLocal}/profiles/default" "[platform_tool_requires]"}
                        ${hasLine "${configLocal}/profiles/default" "cmake/${pkgs.cmake.version}"}

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

                      # Output of the single `conan profile show` run, kept so
                      # that every assertion below observes the very same run.
                      profileLog = "conan-profile.log";
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

                        conan profile show > ${escapeShellArg profileLog}
                        test -s ${escapeShellArg profileLog}

                        ${hasLine profileLog "arch=${parseSystemArch stdenv.system}"}
                        ${hasLine profileLog "build_type=${profiles.default.settings.build_type}"}
                        ${hasLine profileLog "compiler=${conan-flake.lib.pnameFromStdenvCc lib stdenv}"}
                        ${hasLine profileLog "compiler.cppstd=${profiles.default.settings."compiler.cppstd"}"}
                        ${hasLine profileLog "compiler.libcxx=${profiles.default.settings."compiler.libcxx"}"}
                        ${hasLine profileLog "compiler.version=${conan-flake.lib.versionFromStdenvCc lib stdenv}"}
                        ${hasLine profileLog "os=${parseSystemOs stdenv.system}"}
                        ${hasLine profileLog "cmake/${pkgs.cmake.version}"}

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

                ${hasLine "${configuration}/config/global.conf" "core.graph:compatibility_mode=optimized"}

                ${hasLine "${configuration}/config/profiles/default" "build_type=${profiles.default.settings.build_type}"}
                ${hasLine "${configuration}/config/profiles/default" "compiler.cppstd=${
                  profiles.default.settings."compiler.cppstd"
                }"}
                ${hasLine "${configuration}/config/profiles/default" "compiler.libcxx=${
                  profiles.default.settings."compiler.libcxx"
                }"}

                ${hasLine "${configuration}/config/profiles/default" "[platform_tool_requires]"}
                ${hasLine "${configuration}/config/profiles/default" "cmake/${pkgs.cmake.version}"}

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
