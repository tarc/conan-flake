{ self, lib, flake-parts-lib, ... }:

let
  inherit (flake-parts-lib)
    mkPerSystemOption;
  inherit (lib)
    filterAttrs
    mapAttrs
    mkOption
    types;
  relativePathType = types.pathWith {
    inStore = false;
    absolute = false;
  };
  infuse = (import self.inputs.infuse { inherit lib; }).v1.infuse;
in
{
  options.perSystem = mkPerSystemOption ({ config, self', pkgs, ... }: {
    options = {
      conan = mkOption {
        description = "Conan configuration";
        type = (types.submoduleWith {
          specialArgs = { inherit pkgs infuse relativePathType; };
          modules = [
            ./config
            { configRoot = lib.mkDefault self; }
          ];
        });
        default = { };
      };
    };

    config = {
      packages = mapAttrs
        (_: info: info.package)
        (filterAttrs
          (name: value: value.kind == "package")
          config.conan.outputs.packages);
    };
  });
}
