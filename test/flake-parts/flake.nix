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
        configLocal = "CONFIGLOCAL";
        conanHome = "./CONANHOME";
        compilerCppStd = "101";
        compilerLibCxx = "libstdc++665";
      in
      {

        conan = {
          settings.base = { };

          inherit configLocal conanHome compilerCppStd compilerLibCxx;

          platformToolRequires = {
            cmake = pkgs.cmake.version;
          };
        };

        checks.test =
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

              cat "${config.packages.configuration}/.conanrc" \
                | grep "conan_home=${conanHome}"

              cat "${config.packages.configuration}/config/settings_user.yml" \
                | grep "${pkgs.stdenv.cc.version}"
              cat "${config.packages.configuration}/config/settings_user.yml" \
                | grep "${pkgs.cudaPackages.backendStdenv.cc.version}"
              cat "${config.packages.configuration}/config/settings_user.yml" \
                | grep "${pkgs.llvmPackages.stdenv.cc.version}"

              cat "${config.packages.configuration}/config/profiles/default" \
                | grep "compiler.cppstd=${compilerCppStd}"
              cat "${config.packages.configuration}/config/profiles/default" \
                | grep "compiler.libcxx=${compilerLibCxx}"

              cat "${config.packages.configuration}/config/profiles/default" \
                | grep "[platform_tool_requires]"
              cat "${config.packages.configuration}/config/profiles/default" \
                | grep "cmake/${pkgs.cmake.version}"

              ${config.devShells.configuration.shellHook}

              echo "Checking local..."

              cat ".conanrc" | grep "conan_home=${conanHome}"

              cat "${configLocal}/settings_user.yml" | grep "${pkgs.stdenv.cc.version}"
              cat "${configLocal}/settings_user.yml" | grep "${pkgs.cudaPackages.backendStdenv.cc.version}"
              cat "${configLocal}/settings_user.yml" | grep "${pkgs.llvmPackages.stdenv.cc.version}"

              cat "${configLocal}/profiles/default" | grep "compiler.cppstd=${compilerCppStd}"
              cat "${configLocal}/profiles/default" | grep "compiler.libcxx=${compilerLibCxx}"

              cat "${configLocal}/profiles/default" | grep "[platform_tool_requires]"
              cat "${configLocal}/profiles/default" | grep "cmake/${pkgs.cmake.version}"

              touch $out
              )
            '';
      };

    };
}
