{
  # Since there is no flake.lock file (to avoid incongruent conan-flake
  # pinning), we must specify revisions for *all* inputs to ensure
  # reproducibility.
  # TODO: Remove hardcoded homedir.
  inputs = {
    devenv-root = {
      url = "file+file:///home/tarci/projects/conan-flake/.devenv/root";
      flake = false;
    };
    nixpkgs.url = "github:cachix/devenv-nixpkgs/ec3063523dcd911aeadb50faa589f237cdab5853";
    flake-parts.url = "github:hercules-ci/flake-parts/3107b77cd68437b9a76194f0f7f9c55f2329ca5b";
    devenv.url = "github:cachix/devenv/28668b6851e4e649aadd329527059344d14561cf";
    nix2container.url = "github:nlewo/nix2container/76be9608a7f4d6c985d28b0e7be903ae2547df3e";
    mk-shell-bin.url = "github:rrbutani/nix-mk-shell-bin/ff5d8bd4d68a347be5042e2f16caee391cd75887";
    conan-flake = { };
    infuse = {
      url = "git+https://codeberg.org/amjoseph/infuse.nix?rev=e837ece1b9de6ebcb7abd261f54a09bad3a2f820";
      flake = false;
    };
  };

  outputs = inputs@{ self, nixpkgs, flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {

      imports = [
        inputs.devenv.flakeModule
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

          devenv = {
            shells.default = {
              name = "conan-flake-dev";

              inputsFrom = [
                config.devShells.configuration
              ];

              packages = [ pkgs.hello ];
            };
          };

          checks = {
            testConfigurationPackage =
              let
                configuration = config.packages.configuration;
                stdenv = pkgs.stdenv;
                backendStdenv = pkgs.cudaPackages.backendStdenv;
                llvmPackages = pkgs.llvmPackages;
              in
              pkgs.runCommand "devenv-test-configuration-package"
                { }
                ''
                  (
                  set -x
                  echo "Testing test/devenv ..."

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
                  name = "devenv-test-local-setup";
                  inherit (cfg) stdenv;
                }
                ''
                  (
                  set -x
                  echo "Testing test/devenv ..."

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
