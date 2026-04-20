# A pure Nix library that handles the Conan configuration.
let
  pkgs = import <nixpkgs> { };

  infuse =
    (import
      (pkgs.fetchgit {
        url  = "https://codeberg.org/amjoseph/infuse.nix";
        rev  = "e837ece1b9de6ebcb7abd261f54a09bad3a2f820";
        sha256 = "sha256-GW7S5dsFiQChSbGESrkFyNSzDLKGNH3H0EMeY+NLefY=";
        deepClone = false;
      }) { inherit (pkgs) lib; }).v1.infuse;

  relativePathType = pkgs.lib.types.pathWith {
    inStore = false;
    absolute = false;
  };

  conan = self: pkgs.lib.evalModules {
    specialArgs = { inherit pkgs infuse relativePathType; };
    modules = [
      ./config
      { configRoot = pkgs.lib.mkDefault self; }
    ];
  };

in
{
  conan = pkgs.lib.fix conan;
}
