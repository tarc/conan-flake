{
  self,
  inputs,
  lib,
  flake-parts-lib,
  ...
}:

let
  inherit (flake-parts-lib) mkPerSystemOption;
  inherit (lib) mkOption types;
  defaultSpecialArgs = inputs.conan-flake.lib.defaultSpecialArgs {
    inherit lib;
    infuse = (import inputs.infuse { inherit lib; }).v1.infuse;
  };
in
{
  options.perSystem = mkPerSystemOption (
    { config, pkgs, ... }: {
      options = {
        conan = mkOption {
          description = "Conan configuration";
          type = (
            types.submoduleWith {
              specialArgs = {
                inherit pkgs;
                inherit (defaultSpecialArgs)
                  infuse
                  relativePathType
                  parseSystemArch
                  parseSystemOs
                  envSubmodule
                  outputType
                  listOfOutputType
                  anyOutput
                  ;
              };
              modules = [
                ./configuration
                {
                  configRoot = lib.mkDefault self;
                }
              ];
            }
          );
          default = { };
        };
      };

      config =
        let
          contains = k: lib.any (x: x == k);
        in
        {
          devShells = lib.optionalAttrs (contains "devShells" config.conan.autoWire) {
            configuration = config.conan.outputs.devShell;
          };
          checks = lib.optionalAttrs (contains "checks" config.conan.autoWire) config.conan.outputs.checks;
        };
    }
  );
}
