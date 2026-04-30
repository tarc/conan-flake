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
        inputs.conan-flake.flakeModule
      ];

      # flake-parts options to enable debug inspecting.
      debug = true;

      perSystem = { self', pkgs, config, ... }: {

        # A single Conan configuration is supported.
        conan = {
          # The base developer environment.
          # By default, this is pkgs.stdenv.
          # stdenv = pkgs.cudaPackages.backendStdenv;

          settings.base = {
            # gcc = {
            #   version = [ "15.2.0" ];
            # };
          };

          platformToolRequires = {
            cmake = pkgs.cmake.version;
          };

          devShell = {
            # Programs you want to make available in the shell.
            packages = [
              pkgs.cmake
            ];
          };

          remotes.local = {
            url = "./repo";
            local = true;
            allowedPackages = [
              "hello-world/0.0.1.cci.20260428"
            ];
          };

          offline = true;
        };

        devenv = {
          shells.default = {
            name = "conan-flake-dev";

            inputsFrom = [
              # conan-flake exposes a `configuration` devShell by default that
              # can be used directly, or passed in the inputsFrom option as a
              # means to compose with other devShell modules.
              config.devShells.configuration
            ];

            packages = [ pkgs.just ];

            treefmt = {
              enable = true;
              config = {
                programs = {
                  nixpkgs-fmt.enable = true;
                  cmake-format.enable = true;
                };
              };
            };
          };
        };

        # conan-flake doesn't set the default package, but you can do it here.
        # packages.default = self'.packages.example;
      };
    };
}
