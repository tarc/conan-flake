{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    conan-flake.url = "git+ssh://git@github.com/tarc/conan-flake.git";
  };
  outputs =
    inputs@{ self
    , nixpkgs
    , flake-parts
    , ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = nixpkgs.lib.systems.flakeExposed;
      imports = [ inputs.conan-flake.flakeModule ];

      perSystem =
        { self', pkgs, ... }:
        {

          conanProject = {
            # `name` defaults to the name of the base directory of this
            # flake:
            name = "example-library";
            version = "0.1.0";
          };

          packages.default = self'.packages.example-library;
        };
    };
}
