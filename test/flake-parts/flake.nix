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

          # Asserts `line` is a line of its own in `file`.
          #
          # No `test -f` guard: a missing `file` makes `grep` exit 2, which is
          # already a failure for a positive assertion. The pattern is still
          # passed with `-e` so that a leading `-` cannot be taken for an
          # option.
          hasLine = file: line: "grep -qxF -e ${escapeShellArg line} -- ${escapeShellArg file}";

          # Output of the single `profile show` run in each block below, kept
          # so that every assertion in that block observes the very same run.
          profileLog = "conan-profile.log";
          configLocal = "CONFIGLOCAL";
          conanHome = "./CONANHOME";
          profiles.default.settings = {
            build_type = "Release";
            "compiler.cppstd" = "14";
            "compiler.libcxx" = "libstdc++11";
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

                        ${getCommand cfg.package} profile show > ${escapeShellArg profileLog}
                        test -s ${escapeShellArg profileLog}

                        ${hasLine profileLog "arch=${cfg.final.profiles.default.settings.arch}"}
                        ${hasLine profileLog "build_type=${cfg.final.profiles.default.settings.build_type}"}
                        ${hasLine profileLog "compiler=${cfg.final.profiles.default.settings."compiler"}"}
                        ${hasLine profileLog "compiler.cppstd=${cfg.final.profiles.default.settings."compiler.cppstd"}"}
                        ${hasLine profileLog "compiler.libcxx=${cfg.final.profiles.default.settings."compiler.libcxx"}"}
                        ${hasLine profileLog "compiler.version=${cfg.final.profiles.default.settings."compiler.version"}"}
                        ${hasLine profileLog "os=${cfg.final.profiles.default.settings.os}"}
                        ${hasLine profileLog "cmake/${cfg.final.profiles.default.platformToolRequires.cmake}"}

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

                        ${getCommand cfg.package} profile show > ${escapeShellArg profileLog}
                        test -s ${escapeShellArg profileLog}

                        ${hasLine profileLog "arch=${cfg.final.profiles.default.settings.arch}"}
                        ${hasLine profileLog "build_type=${cfg.final.profiles.default.settings.build_type}"}
                        ${hasLine profileLog "compiler=${cfg.final.profiles.default.settings."compiler"}"}
                        ${hasLine profileLog "compiler.cppstd=${cfg.final.profiles.default.settings."compiler.cppstd"}"}
                        ${hasLine profileLog "compiler.libcxx=${cfg.final.profiles.default.settings."compiler.libcxx"}"}
                        ${hasLine profileLog "compiler.version=${cfg.final.profiles.default.settings."compiler.version"}"}
                        ${hasLine profileLog "os=${cfg.final.profiles.default.settings.os}"}
                        ${hasLine profileLog "cmake/${cfg.final.profiles.default.platformToolRequires.cmake}"}

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

                ${hasLine "${configuration}/config/global.conf" "core.graph:compatibility_mode=optimized"}

                ${hasLine "${configuration}/config/profiles/default" "build_type=${profiles.default.settings.build_type}"}
                ${hasLine "${configuration}/config/profiles/default" "compiler.cppstd=${
                  profiles.default.settings."compiler.cppstd"
                }"}
                ${hasLine "${configuration}/config/profiles/default" "compiler.libcxx=${
                  profiles.default.settings."compiler.libcxx"
                }"}

                ${hasLine "${configuration}/config/profiles/default" "[platform_tool_requires]"}
                ${hasLine "${configuration}/config/profiles/default" "cmake/${config.conan.final.profiles.default.platformToolRequires.cmake}"}

                touch $out
                )
              '';
          };
        };
    };
}
