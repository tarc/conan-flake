# file: examples/standalone-submodule-with/infuse.nix
{
  lib,
  config,
  ...
}:
let
  inherit
    ((import (fetchGit {
      url = "https://codeberg.org/amjoseph/infuse.nix";
      name = "infuse.nix";
      ref = "refs/tags/v2.6";
      rev = "364ea18b5611b5fd6a6acd7151411b430a70e194";
      shallow = true;
    }) { inherit lib; }).v1
    )
    infuse
    ;

  test.infuse.input.__append = "echo TEST appended";

  testing = infuse (config.testing) test;
in
{
  options = {
    testing.infuse.input = lib.mkOption {
      type = lib.types.lines;
    };
    testing.infuse.output = lib.mkOption {
      type = lib.types.lines;
    };
  };

  config = {
    testing.infuse.input = "echo TESTING infuse";
    testing.infuse.output = testing.infuse.input;
  };
}
