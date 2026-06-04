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
  parseSystemArch = import ../lib/parse-system-arch.nix;
  parseSystemOs = import ../lib/parse-system-os.nix;
in
{
  options.perSystem = mkPerSystemOption ({ config, self', pkgs, ... }: {
    options = {
      conan = mkOption {
        description = "Conan configuration";
        type = (types.submoduleWith {
          specialArgs = { inherit pkgs infuse relativePathType parseSystemArch parseSystemOs; };
          modules = [
            ./configuration
            {
              configRoot = lib.mkDefault self;
            }
          ];
        });
        default = { };
      };
    };

    config =
      let
        contains = k: lib.any (x: x == k);
      in
      {
        devShells = { }
          // lib.optionalAttrs (contains "devShells" config.conan.autoWire) {
          configuration = config.conan.outputs.devShell;
        };
      };
  });
}
