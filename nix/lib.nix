# Standalone API for using conan-flake without flake-parts.
#
# In a flake:
#   let
#     configuration = (conan-flake.lib { inherit pkgs; }).evalConanConfig {
#       configRoot = self;
#     };
#   in configuration.devShell
#
# Without flakes:
#   let
#     configuration = (import /path/to/conan-flake/nix/lib.nix { inherit pkgs; }).evalConanConfig {
#       configRoot = ./.;
#     };
#   in configuration.devShell
{ pkgs
, lib ? pkgs.lib
, infuse ? (import
    (pkgs.fetchgit {
      url = "https://codeberg.org/amjoseph/infuse.nix";
      rev = "e837ece1b9de6ebcb7abd261f54a09bad3a2f820";
      sha256 = "sha256-GW7S5dsFiQChSbGESrkFyNSzDLKGNH3H0EMeY+NLefY=";
      deepClone = false;
    })
    { inherit lib; }).v1.infuse
, relativePathType ? (lib.types.pathWith {
    inStore = false;
    absolute = false;
  })
, parseSystemArch ? (import ./parse-system-arch.nix)
, parseSystemOs ? (import ./parse-system-os.nix)
}:
{
  # Evaluate a conan-flake configuration and return its outputs.
  #
  # Returns: { packages, commands, links, devShell }
  evalConanConfig =
    { configRoot
    , modules ? [ ]
    }:
    (lib.evalModules {
      specialArgs = { inherit pkgs infuse relativePathType parseSystemArch parseSystemOs; };
      modules = [
        ./modules/configuration
        { inherit configRoot; }
      ] ++ modules;
    }).config.outputs;

  inherit parseSystemArch parseSystemOs;
}
