{ lib, ... }:
let
  inherit (lib)
    mkOption
    types;
  envSubmodule = types.submodule (
    { name, config, ... }:
    {
      options = {
        name = mkOption {
          type = types.str;
          description = ''Name.'';
          default = "";
        };
        op = mkOption {
          type = types.str;
          description = ''Operation'';
          default = "";
        };
        value = mkOption {
          type = types.str;
          description = ''Value.'';
          default = "";
        };
      };
    }
  );
in
envSubmodule
