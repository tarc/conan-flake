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
          buildType = "Release";
          compilerCppStd = "14";
          compilerLibCxx = "libstdc++11";
          overridingCmd = pkgs.writeShellApplication {
            name = "overriding-cmd";

            runtimeInputs = [ ];

            text = ''
              echo overridingCmd "$@"
            '';
          };
        in
        {
          conan = {
            defaults.enable = true;

            inherit configLocal conanHome buildType compilerCppStd compilerLibCxx;

            platformToolRequires = {
              cmake = pkgs.cmake.version;
            };

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
                configuration = config.conan.outputs.packages.configuration;
                stdenv = pkgs.stdenv;
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

                  cat "${configuration}/.conanrc" | grep "conan_home="${escapeShellArg conanHome}

                  cat "${configuration}/config/settings_user.yml" | grep ${escapeShellArg stdenv.cc.version}
                  cat "${configuration}/config/settings_user.yml" | grep ${escapeShellArg backendStdenv.cc.version}
                  cat "${configuration}/config/settings_user.yml" | grep ${escapeShellArg llvmPackages.stdenv.cc.version}

                  cat "${configuration}/config/profiles/default" | grep "build_type="${escapeShellArg buildType}
                  cat "${configuration}/config/profiles/default" | grep "compiler.cppstd="${escapeShellArg compilerCppStd}
                  cat "${configuration}/config/profiles/default" | grep "compiler.libcxx="${escapeShellArg compilerLibCxx}

                  cat "${configuration}/config/profiles/default" | grep "[platform_tool_requires]"
                  cat "${configuration}/config/profiles/default" | grep "cmake/"${escapeShellArg pkgs.cmake.version}

                  touch $out
                  )
                '';

            testLocalSetup =
              let
                cfg = config.conan;
                stdenv = pkgs.stdenv;
                backendStdenv = pkgs.cudaPackages.backendStdenv;
                llvmPackages = pkgs.llvmPackages;
              in
              pkgs.runCommandWith
                {
                  name = "flake-parts-override-default-cmd-test-local-setup";
                  inherit (cfg) stdenv;
                }
                ''
                  (
                  set -x
                  echo "Testing test/flake-parts-override-default-cmd ..."

                  echo "Checking local setup..."

                  ${config.devShells.configuration.shellHook}

                  cat ".conanrc" | grep "conan_home="${escapeShellArg cfg.conanHome}

                  cat ${escapeShellArg cfg.configLocal}"/settings_user.yml" | grep ${escapeShellArg stdenv.cc.version}
                  cat ${escapeShellArg cfg.configLocal}"/settings_user.yml" | grep ${escapeShellArg backendStdenv.cc.version}
                  cat ${escapeShellArg cfg.configLocal}"/settings_user.yml" | grep ${escapeShellArg llvmPackages.stdenv.cc.version}

                  cat ${escapeShellArg cfg.configLocal}"/profiles/default" | grep "build_type="${escapeShellArg cfg.buildType}
                  cat ${escapeShellArg cfg.configLocal}"/profiles/default" | grep "compiler.cppstd="${escapeShellArg cfg.compilerCppStd}
                  cat ${escapeShellArg cfg.configLocal}"/profiles/default" | grep "compiler.libcxx="${escapeShellArg cfg.compilerLibCxx}

                  cat ${escapeShellArg cfg.configLocal}"/profiles/default" | grep "[platform_tool_requires]"
                  cat ${escapeShellArg cfg.configLocal}"/profiles/default" | grep "cmake/"${escapeShellArg pkgs.cmake.version}

                  touch $out
                  )
                '';

            testConanPackage =
              let
                cfg = config.conan;
              in
              pkgs.runCommandWith
                {
                  name = "flake-parts-override-default-cmd-test-conan-profile";
                  inherit (cfg) stdenv;
                  derivationArgs = { inherit (config.devShells.configuration) buildInputs nativeBuildInputs; };
                }
                ''
                  (
                  set -x
                  echo "Testing test/flake-parts-override-default-cmd ..."

                  echo "Checking Conan is not on path..."

                  ${config.devShells.configuration.shellHook}

                  echo "Package: "${getCommand cfg.package}

                  ${getCommand cfg.package} | grep "overridingCmd"

                  touch $out
                  )
                '';
          };
        };
    };
}
