{ self, lib, flake-parts-lib, ... }:

let
  inherit (flake-parts-lib)
    mkPerSystemOption;
  inherit (lib)
    mkOption
    types;
in
{
  options.perSystem = mkPerSystemOption ({ config, self', pkgs, ... }: {
    options = {
      conan = mkOption {
        description = "Conan configuration";
        type = (types.submoduleWith {
          specialArgs = { inherit pkgs self; };
          modules = [
            ./config
          ];
        });
        default = { };
      };
    };

    config = {
      packages = {
        inherit (config.conan) configuration;
      };
    };
  });
}
