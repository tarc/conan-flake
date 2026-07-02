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
  defaultSpecialArgs = (import ../lib/lib.nix { inherit inputs; }).conanFlake.defaultSpecialArgs {
    inherit lib;
    infuse = (import inputs.infuse { inherit lib; }).v1.infuse;
  };
in
{
  options = {
    perSystem = mkPerSystemOption (
      {
        config,
        pkgs,
        ...
      }:
      {
        options.conan = mkOption {
          description = ''
            Project-level Conan configuration

            Use `config.treefmt.build.wrapper` to get access to the resulting treefmt
            package based on this configuration.

            By default treefmt-nix will set the `formatter.<system>` attribute of the flake,
            used by the `nix fmt` command.
          '';
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
                  listOfGeneratorType
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
  };
}
