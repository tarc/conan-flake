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

          # Asserts `line` is a line of its own in `file`.
          #
          # No `test -f` guard, unlike `lacksString` below: a missing `file`
          # makes `grep` exit 2, which is already a failure for a positive
          # assertion. The pattern is still passed with `-e` so that a leading
          # `-` cannot be taken for an option.
          hasLine = file: line: "grep -qxF -e ${escapeShellArg line} -- ${escapeShellArg file}";

          # Asserts no line of `file` contains the fixed string `string`.
          #
          # Spelled as an `if`, and never as `! grep ...`, because `set -e` is
          # specified to ignore the exit status of a pipeline negated by `!`,
          # which would turn the assertion into a no-op. `file` is asserted to
          # exist first, because `grep` exits 2 on a missing file, which the
          # `if` would read as "no match", and the pattern is passed with `-e`
          # so that a leading `-` cannot be taken for an option.
          lacksString = file: string: ''
            test -f ${escapeShellArg file}
            if grep -nF -e ${escapeShellArg string} -- ${escapeShellArg file}; then
              echo "unexpected match:" ${escapeShellArg string} ${escapeShellArg file} >&2
              exit 1
            fi'';

          configLocal = "CONFIGLOCAL";
          conanHome = "./CONANHOME";
          profiles.default = {
            settings = {
              build_type = "Release";
              "compiler.cppstd" = "14";
              "compiler.libcxx" = "libstdc++11";
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

                      ${lacksString "${cfg.configLocal}/profiles/default" "os="}

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
                stdenv = pkgs.gccStdenv;
                backendStdenv = pkgs.cudaPackages.backendStdenv;
                llvmPackages = pkgs.llvmPackages;
              in
              pkgs.runCommand "flake-parts-override-default-cmd-test-configuration-package" { } ''
                (
                set -euo pipefail
                set -x
                echo "Testing test/flake-parts-override-default-cmd ..."

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

                ${lacksString "${configuration}/config/profiles/default" "os="}

                ${hasLine "${configuration}/config/profiles/default" "[platform_tool_requires]"}
                ${hasLine "${configuration}/config/profiles/default" "cmake/${cfg.final.profiles.default.platformToolRequires.cmake}"}

                touch $out
                )
              '';
          };
        };
    };
}
