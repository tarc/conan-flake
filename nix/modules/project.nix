{ self
, lib
, flake-parts-lib
, inputs
, ...
}:

let
  inherit (flake-parts-lib)
    mkPerSystemOption
    ;
  inherit (lib)
    mkOption
    types
    ;
in
{
  imports = [
    inputs.flake-root.flakeModule
  ];

  options.perSystem = mkPerSystemOption (
    { config
    , self'
    , pkgs
    , ...
    }:
    let
      cfg = config.conanProject;
    in
    {
      options = {
        conanProject = mkOption {
          description = "Conan project";
          type = (
            types.submoduleWith {
              specialArgs = {
                inherit pkgs self;
              };
              modules = [
                ./project
              ];
            }
          );
        };
      };

      config =
        let
          contains = k: lib.any (x: x == k);
        in
        {
          # packages = lib.optionalAttrs (contains "packages" cfg.autoWire) lib.mapAttrs'
          #   (_: p: {
          #     name = p.name;
          #     value = p.package;
          #   })
          #   cfg.outputs.packages;

          conanProject.rootDevShell = config.flake-root.devShell;

          devShells = lib.optionalAttrs (contains "devShells" cfg.autoWire && cfg.devShell.enable) {
            default = cfg.outputs.devShell;
          };

          # checks = cfg.outputs.checks;
          # apps = cfg.outputs.apps;
        };
    }
  );
}
