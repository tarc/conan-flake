{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    conan-flake.url = "github:tarc/conan-flake";
    flake-root.url = "github:srid/flake-root";
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
            devShell.tools = ps: { inherit (ps) just; };
          };
        };
    };
}
