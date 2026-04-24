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
          compilerCppStd = "14";
          compilerLibCxx = "libstdc++11";
        in
        {
          conan = {
            settings.base = { };

            inherit configLocal conanHome compilerCppStd compilerLibCxx;

            platformToolRequires = {
              cmake = pkgs.cmake.version;
            };

            offline = true;
          };

          checks.test =
            let
              configuration = config.packages.configuration;
              stdenv = pkgs.stdenv;
              backendStdenv = pkgs.cudaPackages.backendStdenv;
              llvmPackages = pkgs.llvmPackages;
            in
            pkgs.runCommandWith
              {
                name = "flake-parts-test";
                inherit (config.conan) stdenv;
              }
              ''
                (
                set -x
                echo "Testing test/flake-parts ..."

                echo "Checking packages..."

                cat ${configuration}"/.conanrc" | grep "conan_home="${escapeShellArg conanHome}

                cat "${configuration}/config/settings_user.yml" | grep ${escapeShellArg stdenv.cc.version}
                cat "${configuration}/config/settings_user.yml" | grep ${escapeShellArg backendStdenv.cc.version}
                cat "${configuration}/config/settings_user.yml" | grep ${escapeShellArg llvmPackages.stdenv.cc.version}

                cat "${configuration}/config/profiles/default" | grep "compiler.cppstd="${escapeShellArg compilerCppStd}
                cat "${configuration}/config/profiles/default" | grep "compiler.libcxx="${escapeShellArg compilerLibCxx}

                cat "${configuration}/config/profiles/default" | grep "[platform_tool_requires]"
                cat "${configuration}/config/profiles/default" | grep "cmake/"${escapeShellArg pkgs.cmake.version}

                ${config.devShells.configuration.shellHook}

                echo "Checking local..."

                cat ".conanrc" | grep "conan_home="${escapeShellArg conanHome}

                cat "${configLocal}/settings_user.yml" | grep ${escapeShellArg stdenv.cc.version}
                cat "${configLocal}/settings_user.yml" | grep ${escapeShellArg backendStdenv.cc.version}
                cat "${configLocal}/settings_user.yml" | grep ${escapeShellArg llvmPackages.stdenv.cc.version}

                cat "${configLocal}/profiles/default" | grep "compiler.cppstd="${escapeShellArg compilerCppStd}
                cat "${configLocal}/profiles/default" | grep "compiler.libcxx="${escapeShellArg compilerLibCxx}

                cat "${configLocal}/profiles/default" | grep "[platform_tool_requires]"
                cat "${configLocal}/profiles/default" | grep "cmake/"${escapeShellArg pkgs.cmake.version}

                ${lib.getExe config.conan.package} config home | grep ${escapeShellArg conanHome}
                ${lib.getExe config.conan.package} remote list | grep "conancenter.*Verify SSL: True, Enabled: False"
                ${lib.getExe config.conan.package} profile show

                touch $out
                )
              '';
        };
    };
}
