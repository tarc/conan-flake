# file: examples/flake-parts/flake.nix
{
  inputs = {
    nixpkgs.url = "github:cachix/devenv-nixpkgs/rolling";
    flake-parts.url = "github:hercules-ci/flake-parts";
    treefmt-nix.url = "github:numtide/treefmt-nix";
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
        inputs.conan-flake.flakeModule
        inputs.treefmt-nix.flakeModule
      ];

      # `flake-parts` options to enable debug inspecting.
      # debug = true;

      perSystem = { self', pkgs, config, ... }: {

        treefmt.config = {
          projectRoot = self;
          projectRootFile = "README.md";
          programs = {
            nixpkgs-fmt.enable = true;
            cmake-format.enable = true;
          };
        };

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
            tools = {
              inherit (pkgs) cmake;
            };
          };

          # It's possible to specify Conan remotes explicitly, including
          # local-recipe-index remotes -- in which case the `url` is taken as a
          # relative path to the root of the configuration.
          # remotes.local = {
          #   url = "./repo";
          #   local = true;
          #   allowedPackages = [
          #     "hello-world/0.0.1.cci.20260428"
          #   ];
          # };

          # Enable only local remotes (i.e. only of local-recipe-index type):
          # offline = true;
        };

        devShells.default = pkgs.mkShell {
          inputsFrom = [
            # conan-flake exposes a `configuration` devShell by default that
            # can be used directly, or passed in the inputsFrom option as a
            # means to compose with other devShell modules.
            config.devShells.configuration # == `config.conan.outputs.devShell`
            config.treefmt.build.devShell
          ];

          packages = [ pkgs.just ];
        };

        # conan-flake doesn't set the default package, but you can do it here.
        # packages.default = self'.packages.example;
      };
    };
}
