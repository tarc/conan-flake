{ ... }:
{
  infuse =
    {
      lib,
      infuse ? import (fetchGit {
        url = "https://codeberg.org/amjoseph/infuse.nix";
        name = "infuse.nix";
        ref = "refs/tags/v2.5";
        rev = "d3f4e49112f9a59e701ac067faec6832149df07c";
        shallow = true;
      }) { inherit lib; },
    }:
    infuse.v1.infuse;
}
