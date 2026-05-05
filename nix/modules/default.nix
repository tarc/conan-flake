# A pure Nix library that handles the Conan configuration.
let
  pkgs = import <nixpkgs> { };
  conan = self: (import ../lib).evalConanConfig pkgs {
    configRoot = self;
  };
in
{
  conan = pkgs.lib.fix conan;
}
