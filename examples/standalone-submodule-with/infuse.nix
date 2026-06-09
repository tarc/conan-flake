# file: examples/standalone-submodule-with/infuse.nix
{ lib, pkgs, config, ... }:
let
  infuse = (import
    (builtins.fetchGit {
      url = "https://codeberg.org/amjoseph/infuse.nix";
      name = "infuse.nix";
      ref = "refs/tags/v2.4";
      rev = "786657a2cf262c3cdce08f64dd4857655f18f166";
      shallow = true;
    })
    { inherit lib; }).v1.infuse;

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
