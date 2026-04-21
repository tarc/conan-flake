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

        devShells.default = pkgs.mkShell {
          name = "test-flake-parts";

          packages = [ pkgs.just ];

          # files."config/settings_user.yml".source = "${config.packages.configuration}/config/settings_user.yml";
          # files."config/profiles/default".source = "${config.packages.configuration}/config/profiles/default";
        };
      };
    };
}
