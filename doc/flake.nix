{
  inputs = {
    cfp.url = "github:flake-parts/community.flake.parts";
    nixpkgs.follows = "cfp/nixpkgs";
    flake-parts.follows = "cfp/flake-parts";

    flake-parts-website.url = "github:hercules-ci/flake.parts-website";
    flake-parts-website.inputs.conan-flake.follows = "conan-flake";
    flake-parts-website.inputs.flake-parts.follows = "flake-parts";

    conan-flake.url = "github:tarc/conan-flake";
  };

  outputs =
    inputs@{ self, ... }:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = inputs.nixpkgs.lib.systems.flakeExposed;
      imports = [
        inputs.cfp.flakeModules.default
      ];
      perSystem =
        { self'
        , inputs'
        , pkgs
        , ...
        }:
        {
          flake-parts-docs = {
            enable = true;
            modules."conan-flake" = {
              path = self;
              pathString = ".";
            };
          };
          formatter = pkgs.nixpkgs-fmt;
          checks.linkcheck = inputs'.flake-parts-website.checks.linkcheck;
          packages.flake-parts = inputs'.flake-parts-website.packages.default;
          apps.flake-parts.program = pkgs.writeShellApplication {
            name = "docs-flake-parts";
            meta.description = "Open flake.parts docs, previewing local conan-flake version";
            text = ''
              DOCSHTML="${self'.packages.flake-parts}/options/conan-flake.html"

              if [ "$(uname)" == "Darwin" ]; then
                open $DOCSHTML
              else 
                if type xdg-open &>/dev/null; then
                  xdg-open $DOCSHTML
                fi
              fi
            '';
          };
        };
    };
}
