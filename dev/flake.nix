{
  inputs = {
    devenv-root = {
      url = "file+file:///dev/null";
      flake = false;
    };
    # Nixpkgs
    nixpkgs.url = "github:cachix/devenv-nixpkgs/rolling";
    # Inputs
    flake-parts.url = "github:hercules-ci/flake-parts";
    git-hooks.url = "github:cachix/git-hooks.nix";
    devenv.url = "github:cachix/devenv";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    nix2container.url = "github:nlewo/nix2container";
    mk-shell-bin.url = "github:rrbutani/nix-mk-shell-bin";
    conan-flake.url = "git+https://codeberg.org:tarcisio/conan-flake";
    infuse = {
      url = "git+https://codeberg.org/amjoseph/infuse.nix?rev=e837ece1b9de6ebcb7abd261f54a09bad3a2f820";
      flake = false;
    };
    # Minimize duplicate instances of inputs
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";
    git-hooks.inputs.nixpkgs.follows = "nixpkgs";
    devenv.inputs.nixpkgs.follows = "nixpkgs";
    devenv.inputs.flake-parts.follows = "flake-parts";
    devenv.inputs.git-hooks.follows = "git-hooks";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
    nix2container.inputs.nixpkgs.follows = "nixpkgs";
  };

  nixConfig = {
    extra-trusted-public-keys = "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw=";
    extra-substituters = "https://devenv.cachix.org";
  };

  outputs = inputs@{ self, nixpkgs, flake-parts, devenv-root, conan-flake, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      debug = true;

      imports = [
        inputs.devenv.flakeModule
        inputs.conan-flake.flakeModule
      ];

      systems = nixpkgs.lib.systems.flakeExposed;

      perSystem = { pkgs, lib, config, ... }: {
        conan = {
          settings.base = { };
          devShell.packages = [
            pkgs.cmake
          ];
          platformToolRequires = {
            cmake = pkgs.cmake.version;
          };
          remotes.local = {
            url = "./repo";
            local = true;
            allowedPackages = [
              "hello/0.1"
            ];
          };
          offline = true;
        };

        devenv = {
          shells.default = {
            name = "conan-flake-dev";
            inputsFrom = [
              config.devShells.configuration
            ];
            packages = [ pkgs.just ];
            treefmt = {
              enable = true;
              config = {
                projectRootFile = "README.md";
                programs = {
                  nixpkgs-fmt.enable = true;
                  cmake-format.enable = true;
                };
              };
            };
          };
        };
      };
    };
}
