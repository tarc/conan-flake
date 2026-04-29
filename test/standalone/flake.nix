{
  # Test: use conan-flake without devenv and flake-parts, via the standalone nix module.
  inputs = {
    nixpkgs.url = "github:cachix/devenv-nixpkgs/ec3063523dcd911aeadb50faa589f237cdab5853";
    conan-flake = { };
  };
  outputs = { self, nixpkgs, conan-flake, ... }:
    let
      eachSystem = nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed;

      perSystem = system:
        let
          configLocal = "CONFIGLOCAL";
          conanHome = "./CONANHOME";
          buildType = "Release";
          compilerCppStd = "14";
          compilerLibCxx = "libstdc++11";

          pkgs = nixpkgs.legacyPackages.${system};
          conan = (conan-flake.lib { inherit pkgs; }).evalConanConfig {
            configRoot = self;
            modules = [
              ({ pkgs, config, ... }: {
                settings.base = { };

                inherit configLocal conanHome buildType compilerCppStd compilerLibCxx;

                platformToolRequires = {
                  cmake = pkgs.cmake.version;
                };

                offline = true;
              })
            ];
          };
        in
        {
          packages = conan.packages;
          devShells.default = conan.devShell;
          checks = {
            testConfigurationPackage =
              let
                inherit (pkgs.lib) escapeShellArg;
                configuration = conan.packages.configuration;
                stdenv = pkgs.stdenv;
                backendStdenv = pkgs.cudaPackages.backendStdenv;
                llvmPackages = pkgs.llvmPackages;
              in
              pkgs.runCommand "standalone-test-configuration-package"
                { }
                ''
                  (
                  set -x
                  echo "Testing test/standalone ..."

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
                inherit (pkgs.lib) escapeShellArg;
                cfg = conan;
                stdenv = pkgs.stdenv;
                backendStdenv = pkgs.cudaPackages.backendStdenv;
                llvmPackages = pkgs.llvmPackages;
              in
              pkgs.runCommandWith
                {
                  name = "standalone-test-local-setup";
                  inherit stdenv;
                }
                ''
                  (
                  set -x
                  echo "Testing test/standalone ..."

                  echo "Checking local setup..."

                  ${cfg.devShell.shellHook}

                  cat ".conanrc" | grep "conan_home="${escapeShellArg conanHome}

                  cat ${escapeShellArg configLocal}"/settings_user.yml" | grep ${escapeShellArg stdenv.cc.version}
                  cat ${escapeShellArg configLocal}"/settings_user.yml" | grep ${escapeShellArg backendStdenv.cc.version}
                  cat ${escapeShellArg configLocal}"/settings_user.yml" | grep ${escapeShellArg llvmPackages.stdenv.cc.version}

                  cat ${escapeShellArg configLocal}"/profiles/default" | grep "build_type="${escapeShellArg buildType}
                  cat ${escapeShellArg configLocal}"/profiles/default" | grep "compiler.cppstd="${escapeShellArg compilerCppStd}
                  cat ${escapeShellArg configLocal}"/profiles/default" | grep "compiler.libcxx="${escapeShellArg compilerLibCxx}

                  cat ${escapeShellArg configLocal}"/profiles/default" | grep "[platform_tool_requires]"
                  cat ${escapeShellArg configLocal}"/profiles/default" | grep "cmake/"${escapeShellArg pkgs.cmake.version}

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
