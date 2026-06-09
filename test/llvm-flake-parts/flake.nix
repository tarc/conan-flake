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
      systems = nixpkgs.lib.systems.flakeExposed;
      imports = [
        inputs.conan-flake.flakeModule
      ];
      perSystem = { self', pkgs, config, ... }: {
        conan = {
          buildType = "Release";
          compilerCppStd = "23";
          stdenv = pkgs.overrideCC
            (
              pkgs.llvmPackages.libcxxStdenv.override {
                targetPlatform.useLLVM = true;
              }
            )
            pkgs.llvmPackages.clangUseLLVM;
          compilerLibCxx = null;
          remotes.local = {
            url = "./repo";
            local = true;
            allowedPackages = [ "hello-world/0.0.1.cci.20260428" ];
          };
          offline = true;
        };
        devShells.default = pkgs.mkShell {
          inputsFrom = [
            config.conan.outputs.devShell
          ];
        };
        checks.test = pkgs.runCommandWith
          {
            name = "llvm-flake-parts-test-conan-create";
            inherit (config.conan) stdenv;
            derivationArgs = { inherit (config.conan.outputs.devShell) buildInputs nativeBuildInputs; };
          }
          ''
            (
            set -x
            ${config.conan.outputs.devShell.shellHook}
            conan create ${config.conan.info.configRoot} -tf="" --build=missing 2>&1 | grep "example/0.0.1"
            touch $out
            )
          '';
      };
    };
}
