# Assertions over the built documentation site, one derivation per ACID.
#
# `dev/flake.nix` wires them into `nix flake check ./dev`, which is what makes
# the site's build, its sub-path behaviour, its publishing and the `README.md`
# pointing at it a CI failure when they regress. The checks themselves live one
# per feature next door, with what they share in `checks/common.nix`.
#
# site.BUILD.3
{
  lib,
  runCommand,
  embedmd,
  git,
  yq-go,
  site,
}:
let
  common = import ./checks/common.nix { inherit lib runCommand site; };

  args = common // {
    inherit
      lib
      embedmd
      git
      yq-go
      ;
  };
in
import ./checks/site.nix args
// import ./checks/publishing.nix args
// import ./checks/readme.nix args
