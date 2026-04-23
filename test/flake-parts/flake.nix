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

      perSystem = { pkgs, lib, config, ... }: {

        conan = {
          settings.base = { };

          conanHome = "CONANHOME";

          compilerCppStd = "101";
          compilerLibCxx = "libstdc++665";

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

              cat "${config.packages.configuration}/.conanrc" \
                | grep "conan_home=CONANHOME"

              cat "${config.packages.configuration}/config/settings_user.yml" \
                | grep "${pkgs.stdenv.cc.version}"
              cat "${config.packages.configuration}/config/settings_user.yml" \
                | grep "${pkgs.cudaPackages.backendStdenv.cc.version}"
              cat "${config.packages.configuration}/config/settings_user.yml" \
                | grep "${pkgs.llvmPackages.stdenv.cc.version}"

              cat "${config.packages.configuration}/config/profiles/default" \
                | grep "compiler.cppstd=101"
              cat "${config.packages.configuration}/config/profiles/default" \
                | grep "compiler.libcxx=libstdc++665"

              cat "${config.packages.configuration}/config/profiles/default" \
                | grep "[platform_tool_requires]"
              cat "${config.packages.configuration}/config/profiles/default" \
                | grep "cmake/${pkgs.cmake.version}"

              touch $out
              )
            '';
      };

    };
}
