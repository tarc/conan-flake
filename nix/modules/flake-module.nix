{ self, lib, flake-parts-lib, ... }:

let
  inherit (flake-parts-lib)
    mkPerSystemOption;

  inherit (lib)
    mkOption
    types;

  infuse = (import self.inputs.infuse { inherit lib; }).v1.infuse;

in
{
  options.perSystem = mkPerSystemOption ({ config, self', pkgs, ... }: {
    options = {
      conan = pkgs.lib.mkOption {
        description = "Conan configuration";
        type = (pkgs.lib.types.submoduleWith {
          specialArgs = { inherit pkgs self infuse; };
          modules = [
            ./config
          ];
        });
        default = { };
      };
    };

    config = {
      packages = pkgs.lib.mapAttrs (_: info: info.package) config.conan.outputs.packages;
    };
  });
}
