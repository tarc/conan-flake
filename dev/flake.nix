{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nixpkgs-lib.url = "github:NixOS/nixpkgs/nixpkgs-unstable?dir=lib";
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs-lib";
    flake-root.url = "github:srid/flake-root";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
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
      imports = [
        inputs.flake-root.flakeModule
        inputs.treefmt-nix.flakeModule
      ];
      perSystem =
        { pkgs
        , lib
        , config
        , ...
        }:
        {
          treefmt.config = {
            projectRoot = inputs.conan-flake;
            projectRootFile = "README.md";
            programs = {
              clang-format.enable = true;
              cmake-format.enable = true;
              nixpkgs-fmt.enable = true;
              alejandra.enable = false;
              nixfmt.enable = true;
              deadnix = {
                enable = true;
                no-lambda-pattern-names = true;
                no-lambda-arg = true;
              };
              mdformat.enable = true;
              just.enable = true;
            };
          };
          devShells.default = pkgs.mkShell {
            # cf. https://community.flake.parts/haskell-flake/devshell#composing-devshells
            inputsFrom = [
              config.treefmt.build.devShell
            ];
            packages = with pkgs; [
              just
            ];
            TREEFMT_CONFIG_FILE = config.treefmt.build.configFile;
            shellHook = ''
              echo
              echo "🍎🍎 Run 'just <recipe>' to get started"
              just
            '';
          };
        };
    };
}
