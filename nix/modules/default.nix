# A pure Nix library that handles the Conan configuration.
let
  pkgs = import <nixpkgs> { };

  lib = import <nixpkgs/lib>;

  infuse =
    (import
      (pkgs.fetchgit {
        url  = "https://codeberg.org/amjoseph/infuse.nix";
        rev  = "786657a2cf262c3cdce08f64dd4857655f18f166";
        sha256 = "sha256-4XPDTUvV8dfuf9GzKg2/r7j7lMELRAwKKFx3ecQObeg=";
        deepClone = false;
      }) { inherit lib; }).v1.infuse;

  conan = self: pkgs.lib.evalModules {
    modules = [ ./config ];
    specialArgs = { inherit pkgs self infuse; };
  };

in
{
  conan = pkgs.lib.fix conan;
}
