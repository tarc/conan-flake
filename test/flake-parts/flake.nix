{
  # Test: use conan-flake without devenv, via the flake-parts module only.
  inputs = {
    nixpkgs.url = "github:cachix/devenv-nixpkgs/3a3d4ac6ea3dbf2534ef988086348b7e140b92ad";
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
          buildType = "Release";
          compilerCppStd = "14";
          compilerLibCxx = "libstdc++11";
        in
        {
          conan = {
            settings.base = { };

            inherit configLocal conanHome buildType compilerCppStd compilerLibCxx;

            platformToolRequires = {
              cmake = pkgs.cmake.version;
            };

            offline = true;
          };

          checks = {
            testConfigurationPackage =
              let
                configuration = config.packages.configuration;
                stdenv = pkgs.stdenv;
                backendStdenv = pkgs.cudaPackages.backendStdenv;
                llvmPackages = pkgs.llvmPackages;
              in
              pkgs.runCommand "flake-parts-test-configuration-package"
                { }
                ''
                  (
                  set -x
                  echo "Testing test/flake-parts ..."

                  echo "Checking configuration package..."

                  cat ${configuration}"/.conanrc" | grep "conan_home="${escapeShellArg conanHome}

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
                  name = "flake-parts-test-local-setup";
                  inherit (cfg) stdenv;
                }
                ''
                  (
                  set -x
                  echo "Testing test/flake-parts ..."

                  echo "Checking local setup..."

                  ${config.devShells.configuration.shellHook}

                  cat ".conanrc" | grep "conan_home="${escapeShellArg cfg.conanHome}

                  cat "${cfg.configLocal}/settings_user.yml" | grep ${escapeShellArg stdenv.cc.version}
                  cat "${cfg.configLocal}/settings_user.yml" | grep ${escapeShellArg backendStdenv.cc.version}
                  cat "${cfg.configLocal}/settings_user.yml" | grep ${escapeShellArg llvmPackages.stdenv.cc.version}

                  cat "${cfg.configLocal}/profiles/default" | grep "build_type="${escapeShellArg cfg.buildType}
                  cat "${cfg.configLocal}/profiles/default" | grep "compiler.cppstd="${escapeShellArg cfg.compilerCppStd}
                  cat "${cfg.configLocal}/profiles/default" | grep "compiler.libcxx="${escapeShellArg cfg.compilerLibCxx}

                  cat "${cfg.configLocal}/profiles/default" | grep "[platform_tool_requires]"
                  cat "${cfg.configLocal}/profiles/default" | grep "cmake/"${escapeShellArg pkgs.cmake.version}

                  touch $out
                  )
                '';

            testConanProfile =
              let
                cfg = config.conan;
              in
              pkgs.runCommandWith
                {
                  name = "flake-parts-test-conan-profile";
                  inherit (cfg) stdenv;
                }
                ''
                  (
                  set -x
                  echo "Testing test/flake-parts ..."

                  echo "Checking Conan profile..."

                  ${config.devShells.configuration.shellHook}

                  ${lib.getExe cfg.package} config home | grep ${escapeShellArg cfg.conanHome}
                  ${lib.getExe cfg.package} remote list | grep "conancenter.*Verify SSL: True, Enabled: False"

                  ${lib.getExe cfg.package} profile show | grep "arch="${escapeShellArg cfg.arch}
                  ${lib.getExe cfg.package} profile show | grep "build_type="${escapeShellArg cfg.buildType}
                  ${lib.getExe cfg.package} profile show | grep "compiler="${escapeShellArg cfg.compiler}
                  ${lib.getExe cfg.package} profile show | grep "compiler.cppstd="${escapeShellArg cfg.compilerCppStd}
                  ${lib.getExe cfg.package} profile show | grep "compiler.libcxx="${escapeShellArg cfg.compilerLibCxx}
                  ${lib.getExe cfg.package} profile show | grep "compiler.version="${escapeShellArg cfg.compilerVersion}
                  ${lib.getExe cfg.package} profile show | grep "os="${escapeShellArg cfg.os}
                  ${lib.getExe cfg.package} profile show | grep "cmake/"${escapeShellArg cfg.platformToolRequires.cmake}

                  touch $out
                  )
                '';

            testConanInstall =
              let
                cfg = config.conan;
              in
              pkgs.runCommandWith
                {
                  name = "flake-parts-test-conan-profile";
                  inherit (cfg) stdenv;
                }
                ''
                  (
                  set -x
                  echo "Testing test/flake-parts ..."

                  echo "Checking Conan profile..."

                  ${config.devShells.configuration.shellHook}

                  ${lib.getExe cfg.package} config home | grep ${escapeShellArg cfg.conanHome}
                  ${lib.getExe cfg.package} remote list | grep "conancenter.*Verify SSL: True, Enabled: False"

                  ${lib.getExe cfg.package} profile show | grep "arch="${escapeShellArg cfg.arch}
                  ${lib.getExe cfg.package} profile show | grep "build_type="${escapeShellArg cfg.buildType}
                  ${lib.getExe cfg.package} profile show | grep "compiler="${escapeShellArg cfg.compiler}
                  ${lib.getExe cfg.package} profile show | grep "compiler.cppstd="${escapeShellArg cfg.compilerCppStd}
                  ${lib.getExe cfg.package} profile show | grep "compiler.libcxx="${escapeShellArg cfg.compilerLibCxx}
                  ${lib.getExe cfg.package} profile show | grep "compiler.version="${escapeShellArg cfg.compilerVersion}
                  ${lib.getExe cfg.package} profile show | grep "os="${escapeShellArg cfg.os}
                  ${lib.getExe cfg.package} profile show | grep "cmake/"${escapeShellArg cfg.platformToolRequires.cmake}

                  touch $out
                  )
                '';
          };
        };
    };
}
