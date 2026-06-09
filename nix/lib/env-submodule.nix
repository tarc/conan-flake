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
          type = lib.types.enum [
            "="
            "+=" # appends values at the end of the existing value
            "=+" # puts values at the beginning of the existing value
            "=!" # gets rid of any variable value
            "=(path)" # defines a PATH variable
            "=+(path)" # prepends another PATH to variable
            "+=(path)" # appends another PATH to variable
          ];
          description = ''Operation'';
          default = "=";
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
