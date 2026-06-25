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
          config,
          ...
        }:
        let
          inherit (pkgs.lib) escapeShellArg;
          configLocal = "CONFIGLOCAL";
          conanHome = "./CONANHOME";
          buildEnvKey = "BUILD_FLAG";
          buildEnvValue = "--IBF=Value";
          runEnvKey = "LD_RUN_PATH";
          runEnvValue = "/my/path";
          confKey = "tools.path.to.something:some_property";
          confValue = "some_value";
          cfg = config.conan;
        in
        {
          conan = {
            inherit configLocal conanHome;

            profiles = {
              settings = {
                compiler = {
                  "compiler.cppstd" = "20";
                  "compiler.libcxx" = "libstdc++11";
                };
                rest.build_type = "Debug";
              };

              buildEnv = [
                {
                  name = buildEnvKey;
                  op = "=+";
                  value = buildEnvValue;
                }
              ];

              runEnv = [
                {
                  name = runEnvKey;
                  op = "+=(path)";
                  value = runEnvValue;
                }
              ];

              conf = {
                "${confKey}" = confValue;
              };
            };

            offline = true;

            checks.testLocalSetup = {
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
                  "flake-parts-profiles-test-local-setup"
                  { }
                  ''
                    (
                    set -x
                    echo "Testing test/flake-parts-profiles ..."

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

                    cat ${escapeShellArg cfg.configLocal}"/profiles/default" \
                      | grep -F "[platform_tool_requires]"
                    cat ${escapeShellArg cfg.configLocal}"/profiles/default" \
                      | grep -F "cmake/"${escapeShellArg cfg.final.profiles.platformToolRequires.cmake}

                    cat ${escapeShellArg cfg.configLocal}"/profiles/default" \
                      | grep -F "[buildenv]"
                    cat ${escapeShellArg cfg.configLocal}"/profiles/default" \
                      | grep -F ${escapeShellArg buildEnvKey}"=+"${escapeShellArg buildEnvValue}

                    cat ${escapeShellArg cfg.configLocal}"/profiles/default" \
                      | grep -F "[runenv]"
                    cat ${escapeShellArg cfg.configLocal}"/profiles/default" \
                      | grep -F ${escapeShellArg runEnvKey}"+=(path)"${escapeShellArg runEnvValue}

                    cat ${escapeShellArg cfg.configLocal}"/profiles/default" \
                      | grep -F "[conf]"
                    cat ${escapeShellArg cfg.configLocal}"/profiles/default" \
                      | grep -F ${escapeShellArg confKey}"="${escapeShellArg confValue}

                    touch $out
                    )
                  '';
            };
          };
        };
    };
}
