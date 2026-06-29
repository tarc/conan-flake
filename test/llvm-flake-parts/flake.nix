{
  # Test: use conan-flake without devenv, via the `flake-parts` module only.
  inputs = {
    nixpkgs.url = "github:cachix/devenv-nixpkgs/ec3063523dcd911aeadb50faa589f237cdab5853";
    flake-parts.url = "github:hercules-ci/flake-parts/3107b77cd68437b9a76194f0f7f9c55f2329ca5b";
    conan-flake = { };
    infuse = {
      url = "git+https://codeberg.org/amjoseph/infuse.nix?rev=364ea18b5611b5fd6a6acd7151411b430a70e194";
      flake = false;
    };
  };
  outputs =
    inputs@{
      self,
      nixpkgs,
      flake-parts,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = nixpkgs.lib.systems.flakeExposed;
      imports = [
        inputs.conan-flake.flakeModule
      ];
      perSystem =
        {
          pkgs,
          config,
          ...
        }:
        {
          conan = {
            profiles.settings = {
              compiler = {
                "compiler.cppstd" = "23";
              };
              rest.build_type = "Release";
            };
            stdenv = pkgs.overrideCC (pkgs.llvmPackages.libcxxStdenv.override {
              targetPlatform.useLLVM = true;
              targetPlatform.linker = "lld";
            }) pkgs.llvmPackages.clangUseLLVM;
            remotes.local = {
              url = "./repo";
              local = true;
              allowedPackages = [ "hello-world/0.0.1.cci.20260428" ];
            };
            offline = true;
            checks.test = {
              enable = true;
              drv =
                inputs.conan-flake.lib.runCommandWithInSimulatedShell pkgs config.conan.stdenv
                  config.conan.outputs.devShell
                  config.conan.info.configRoot
                  "./config"
                  "llvm-flake-parts-test-conan-create"
                  { }
                  ''
                    (
                    set -x
                    ! conan create ${config.conan.info.configRoot} -tf="" --build=missing 2>&1 \
                      | grep -F "_GLIBCXX_USE_CXX11_ABI 1"
                    touch $out
                    )
                  '';
            };
          };
          devShells.default = pkgs.mkShell {
            inputsFrom = [
              config.conan.outputs.devShell
            ];
          };
        };
    };
}
