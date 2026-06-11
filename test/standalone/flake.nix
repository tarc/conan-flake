{
  # Test: use conan-flake without devenv and `flake-parts`, via the standalone nix module.
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
          conan = conan-flake.lib.evalConanConfig pkgs {
            configRoot = self;
            modules = [
              ({ pkgs, config, ... }: {
                inherit configLocal conanHome buildType compilerCppStd compilerLibCxx;

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
                stdenv = pkgs.gccStdenv;
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

                  cat "${configuration}/.conanrc" | grep -F "conan_home="${escapeShellArg conanHome}

                  cat "${configuration}/config/settings_user.yml" | grep -F ${escapeShellArg stdenv.cc.version}
                  cat "${configuration}/config/settings_user.yml" | grep -F ${escapeShellArg backendStdenv.cc.version}
                  cat "${configuration}/config/settings_user.yml" | grep -F ${escapeShellArg llvmPackages.libcxxStdenv.cc.version}

                  cat "${configuration}/config/profiles/default" | grep -F "build_type="${escapeShellArg buildType}
                  cat "${configuration}/config/profiles/default" | grep -F "compiler.cppstd="${escapeShellArg compilerCppStd}
                  cat "${configuration}/config/profiles/default" | grep -F "compiler.libcxx="${escapeShellArg compilerLibCxx}

                  cat "${configuration}/config/profiles/default" | grep -F "[platform_tool_requires]"
                  cat "${configuration}/config/profiles/default" | grep -F "cmake/"${escapeShellArg pkgs.cmake.version}

                  touch $out
                  )
                '';

            testLocalSetup =
              let
                inherit (pkgs.lib) escapeShellArg;
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

                  ${conan.devShell.shellHook}

                  cat ".conanrc" | grep -F "conan_home="${escapeShellArg conanHome}

                  cat ${escapeShellArg configLocal}"/settings_user.yml" | grep -F ${escapeShellArg pkgs.gccStdenv.cc.version}
                  cat ${escapeShellArg configLocal}"/settings_user.yml" | grep -F ${escapeShellArg backendStdenv.cc.version}
                  cat ${escapeShellArg configLocal}"/settings_user.yml" | grep -F ${escapeShellArg llvmPackages.libcxxStdenv.cc.version}

                  cat ${escapeShellArg configLocal}"/profiles/default" | grep -F "build_type="${escapeShellArg buildType}
                  cat ${escapeShellArg configLocal}"/profiles/default" | grep -F "compiler.cppstd="${escapeShellArg compilerCppStd}
                  cat ${escapeShellArg configLocal}"/profiles/default" | grep -F "compiler.libcxx="${escapeShellArg compilerLibCxx}

                  cat ${escapeShellArg configLocal}"/profiles/default" | grep -F "[platform_tool_requires]"
                  cat ${escapeShellArg configLocal}"/profiles/default" | grep -F "cmake/"${escapeShellArg pkgs.cmake.version}

                  touch $out
                  )
                '';

            testConanInstall =
              let
                inherit (pkgs) stdenv;
                inherit (pkgs.lib) escapeShellArg;
                parseSystemArch = conan-flake.lib.parseSystemArch { };
                parseSystemOs = conan-flake.lib.parseSystemOs { };
              in
              pkgs.runCommandWith
                {
                  name = "standalone-test-conan-profile";
                  inherit stdenv;
                  derivationArgs = { inherit (conan.devShell) buildInputs nativeBuildInputs; };
                }
                ''
                  (
                  set -x
                  echo "Testing test/standalone ..."

                  echo "Checking Conan profile..."

                  ${conan.devShell.shellHook}

                  conan config home | grep ${escapeShellArg conanHome}
                  conan remote list | grep "conancenter.*Verify SSL: True, Enabled: False"

                  conan profile show | grep -F "arch="${escapeShellArg (parseSystemArch stdenv.system)}
                  conan profile show | grep -F "build_type="${escapeShellArg buildType}
                  conan profile show | grep -F "compiler="${escapeShellArg stdenv.cc.cc.pname}
                  conan profile show | grep -F "compiler.cppstd="${escapeShellArg compilerCppStd}
                  conan profile show | grep -F "compiler.libcxx="${escapeShellArg compilerLibCxx}
                  conan profile show | grep -F "compiler.version="${escapeShellArg stdenv.cc.version}
                  conan profile show | grep -F "os="${escapeShellArg (parseSystemOs stdenv.system)}
                  conan profile show | grep -F "cmake/"${escapeShellArg pkgs.cmake.version}

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
