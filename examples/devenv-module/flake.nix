# file: examples/devenv-module/flake.nix
{
  inputs = {
    devenv-root = {
      url = "file+file:///dev/null";
      flake = false;
    };
    nixpkgs.url = "github:cachix/devenv-nixpkgs/rolling";
    flake-parts.url = "github:hercules-ci/flake-parts";
    git-hooks.url = "github:cachix/git-hooks.nix";
    devenv.url = "github:cachix/devenv";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    nix2container.url = "github:nlewo/nix2container";
    mk-shell-bin.url = "github:rrbutani/nix-mk-shell-bin";
    conan-flake.url = "git+https://codeberg.org/tarcisio/conan-flake";
    infuse = {
      url = "git+https://codeberg.org/amjoseph/infuse.nix?rev=e837ece1b9de6ebcb7abd261f54a09bad3a2f820";
      flake = false;
    };
  };
  outputs = inputs@{ self, nixpkgs, flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = nixpkgs.lib.systems.flakeExposed;
      imports = [
        inputs.devenv.flakeModule
      ];

      # flake-parts options to enable debug inspecting.
      # debug = true;

      perSystem = { self', pkgs, config, ... }: {

        devenv = {
          shells.default = {
            imports = [
              inputs.conan-flake.devenv
              ./devenv.nix
            ];
          };
        };

        # conan-flake doesn't set the default package, but you can do it here.
        # packages.default = self'.packages.example;
      };
    };
}
