{ ... }:
{
  infuse =
    {
      lib,
      infuse ? import (fetchGit {
        url = "https://codeberg.org/amjoseph/infuse.nix";
        name = "infuse.nix";
        ref = "refs/tags/v2.6";
        rev = "364ea18b5611b5fd6a6acd7151411b430a70e194";
        shallow = true;
      }) { inherit lib; },
    }:
    infuse.v1.infuse;
}
