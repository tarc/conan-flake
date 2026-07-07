{
  self,
  inputs,
  lib,
  flake-parts-lib,
  ...
}:
let
  inherit (flake-parts-lib)
    mkPerSystemOption
    ;
  inherit (lib)
    mkOption
    ;
  conan-flake-lib = (import ../lib/lib.nix { inherit inputs; }).conanFlakeLib;
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

            A wrapper based on this configuration is exposed in
            `conan.outputs.package.wrapper`.
          '';
          type = conan-flake-lib.submoduleWith lib {
            modules = [
              {
                options.pkgs = lib.mkOption {
                  default = pkgs;
                  defaultText = lib.literalMD "`pkgs` (module argument of `perSystem`)";
                };

                config.configRoot = lib.mkDefault self;
              }
            ];
          };
          default = { };
        };
        config = {
          devShells = lib.optionalAttrs (conan-flake-lib.contains "devShells" config.conan.autoWire) {
            configuration = config.conan.outputs.devShell;
          };
          checks = lib.optionalAttrs (conan-flake-lib.contains "checks" config.conan.autoWire) config.conan.outputs.checks;
          packages = lib.optionalAttrs (conan-flake-lib.contains "checks" config.conan.autoWire) config.conan.outputs.packages;
        };
      }
    );
  };
}
