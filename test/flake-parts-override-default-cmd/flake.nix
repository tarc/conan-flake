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
          getCommand = package: builtins.baseNameOf (lib.getExe package);
          inherit (pkgs.lib) escapeShellArg;
          configLocal = "CONFIGLOCAL";
          conanHome = "./CONANHOME";
          profiles = {
            settings.rest = {
              build_type = "Release";
              os = null;
            };
          };
          compilerCppStd = "14";
          compilerLibCxx = "libstdc++11";
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

            inherit configLocal conanHome profiles compilerCppStd compilerLibCxx;

            package = overridingCmd;

            devShell = {
              tools = {
                conan = overridingCmd;
              };
            };

            offline = true;
          };

          checks = {
            testConfigurationPackage =
              let
                configuration = cfg.outputs.packages.configuration;
                stdenv = pkgs.gccStdenv;
                backendStdenv = pkgs.cudaPackages.backendStdenv;
                llvmPackages = pkgs.llvmPackages;
              in
              pkgs.runCommand "flake-parts-override-default-cmd-test-configuration-package"
                { }
                ''
                  (
                  set -x
                  echo "Testing test/flake-parts-override-default-cmd ..."

                  echo "Checking configuration package..."

                  cat "${configuration}/.conanrc" | grep -F "conan_home="${escapeShellArg conanHome}

                  cat "${configuration}/config/settings_user.yml" \
                    | grep -F ${escapeShellArg stdenv.cc.version}
                  cat "${configuration}/config/settings_user.yml" \
                    | grep -F ${escapeShellArg backendStdenv.cc.version}
                  cat "${configuration}/config/settings_user.yml" \
                    | grep -F ${escapeShellArg llvmPackages.libcxxStdenv.cc.version}

                  cat "${configuration}/config/profiles/default" \
                    | grep -F "build_type="${escapeShellArg profiles.settings.rest.build_type}
                  cat "${configuration}/config/profiles/default" \
                    | grep -F "compiler.cppstd="${escapeShellArg compilerCppStd}
                  cat "${configuration}/config/profiles/default" \
                    | grep -F "compiler.libcxx="${escapeShellArg compilerLibCxx}

                  ! cat "${configuration}/config/profiles/default" \
                    | grep -F "os="

                  cat "${configuration}/config/profiles/default" \
                    | grep -F "[platform_tool_requires]"
                  cat "${configuration}/config/profiles/default" \
                    | grep -F "cmake/"${escapeShellArg cfg.final.profiles.platformToolRequires.cmake}

                  touch $out
                  )
                '';

            testLocalSetup =
              let
                stdenv = pkgs.gccStdenv;
                backendStdenv = pkgs.cudaPackages.backendStdenv;
                llvmPackages = pkgs.llvmPackages;
              in
              pkgs.runCommandWith
                {
                  name = "flake-parts-override-default-cmd-test-local-setup";
                  inherit (cfg) stdenv;
                  derivationArgs = { inherit (cfg.outputs.devShell) buildInputs nativeBuildInputs; };
                }
                ''
                  (
                  set -x
                  echo "Testing test/flake-parts-override-default-cmd ..."

                  echo "Checking local setup..."

                  ${cfg.outputs.devShell.shellHook}

                  cat ".conanrc" | grep -F "conan_home="${escapeShellArg cfg.conanHome}

                  cat ${escapeShellArg cfg.configLocal}"/settings_user.yml" \
                    | grep -F ${escapeShellArg stdenv.cc.version}
                  cat ${escapeShellArg cfg.configLocal}"/settings_user.yml" \
                    | grep -F ${escapeShellArg backendStdenv.cc.version}
                  cat ${escapeShellArg cfg.configLocal}"/settings_user.yml" \
                    | grep -F ${escapeShellArg llvmPackages.libcxxStdenv.cc.version}

                  cat ${escapeShellArg cfg.configLocal}"/profiles/default" \
                    | grep -F "build_type="${escapeShellArg cfg.final.profiles.settings.rest.build_type}
                  cat ${escapeShellArg cfg.configLocal}"/profiles/default" \
                    | grep -F "compiler.cppstd="${escapeShellArg cfg.compilerCppStd}
                  cat ${escapeShellArg cfg.configLocal}"/profiles/default" \
                    | grep -F "compiler.libcxx="${escapeShellArg cfg.compilerLibCxx}

                  ! cat ${escapeShellArg cfg.configLocal}"/profiles/default" \
                    | grep -F "os="

                  cat ${escapeShellArg cfg.configLocal}"/profiles/default" \
                    | grep -F "[platform_tool_requires]"
                  cat ${escapeShellArg cfg.configLocal}"/profiles/default" \
                    | grep -F "cmake/"${escapeShellArg cfg.final.profiles.platformToolRequires.cmake}

                  touch $out
                  )
                '';

            testConanPackage =
              pkgs.runCommandWith
                {
                  name = "flake-parts-override-default-cmd-test-conan-profile";
                  inherit (cfg) stdenv;
                  derivationArgs = { inherit (cfg.outputs.devShell) buildInputs nativeBuildInputs; };
                }
                ''
                  (
                  set -x
                  echo "Testing test/flake-parts-override-default-cmd ..."

                  echo "Checking Conan is not on path..."

                  ${cfg.outputs.devShell.shellHook}

                  echo "Package: "${getCommand cfg.package}

                  ${getCommand cfg.package} | grep -F "overridingCmd"

                  touch $out
                  )
                '';
          };
        };
    };
}
