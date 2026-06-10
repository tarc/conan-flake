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

  outputs = inputs@{ self, nixpkgs, flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {

      imports = [
        inputs.conan-flake.flakeModule
      ];

      systems = nixpkgs.lib.systems.flakeExposed;

      perSystem = { pkgs, lib, config, ... }:
        let
          inherit (pkgs.lib) escapeShellArg;
          configLocal = "CONFIGLOCAL";
          conanHome = "./CONANHOME";
          buildType = "Debug";
          compilerCppStd = "20";
          compilerLibCxx = "libstdc++11";
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
            inherit configLocal conanHome buildType compilerCppStd compilerLibCxx;

            profiles = {
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
          };

          checks = {
            testLocalSetup =
              let
                stdenv = pkgs.stdenv;
                backendStdenv = pkgs.cudaPackages.backendStdenv;
                llvmPackages = pkgs.llvmPackages;
              in
              pkgs.runCommandWith
                {
                  name = "flake-parts-profiles-test-local-setup";
                  inherit (cfg) stdenv;
                  derivationArgs = { inherit (cfg.outputs.devShell) buildInputs nativeBuildInputs; };
                }
                ''
                  (
                  set -x
                  echo "Testing test/flake-parts-profiles ..."

                  echo "Checking local setup..."

                  ${cfg.outputs.devShell.shellHook}

                  cat ".conanrc" | grep -F "conan_home="${escapeShellArg cfg.conanHome}

                  cat ${escapeShellArg cfg.configLocal}"/settings_user.yml" \
                    | grep -F ${escapeShellArg stdenv.cc.version}
                  cat ${escapeShellArg cfg.configLocal}"/settings_user.yml" \
                    | grep -F ${escapeShellArg backendStdenv.cc.version}
                  cat ${escapeShellArg cfg.configLocal}"/settings_user.yml" \
                    | grep -F ${escapeShellArg llvmPackages.stdenv.cc.version}

                  cat ${escapeShellArg cfg.configLocal}"/profiles/default" \
                    | grep -F "build_type="${escapeShellArg cfg.buildType}
                  cat ${escapeShellArg cfg.configLocal}"/profiles/default" \
                    | grep -F "compiler.cppstd="${escapeShellArg cfg.compilerCppStd}
                  cat ${escapeShellArg cfg.configLocal}"/profiles/default" \
                    | grep -F "compiler.libcxx="${escapeShellArg cfg.compilerLibCxx}

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
}
