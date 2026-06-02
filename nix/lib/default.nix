# A pure Nix library that handles the Conan configuration.
let
  parseSystemArch = import ./parse-system-arch.nix;
  parseSystemOs = import ./parse-system-os.nix;
  #
  defaultSpecialArgs =
    { nixpkgs
    , infuse ? (import
        (nixpkgs.fetchgit {
          url = "https://codeberg.org/amjoseph/infuse.nix";
          rev = "e837ece1b9de6ebcb7abd261f54a09bad3a2f820";
          sha256 = "sha256-GW7S5dsFiQChSbGESrkFyNSzDLKGNH3H0EMeY+NLefY=";
          deepClone = false;
        })
        { inherit (nixpkgs) lib; }).v1.infuse
    , relativePathType ? (nixpkgs.lib.types.pathWith {
        inStore = false;
        absolute = false;
      })
    , parseSystemArch ? import ./parse-system-arch.nix
    , parseSystemOs ? import ./parse-system-os.nix
    }:
    {
      inherit infuse relativePathType parseSystemArch parseSystemOs; pkgs = nixpkgs;
    };

  # In a flake:
  #   let
  #     configuration = conan-flake.lib.evalConanConfig pkgs {
  #       configRoot = self;
  #     };
  #   in configuration.devShell
  #
  # Without flakes:
  #   let
  #     configuration = (import /path/to/conan-flake/nix/lib).evalConanConfig pkgs {
  #       configRoot = ./.;
  #     };
  #   in configuration.devShell
  #
  # Evaluate a conan-flake configuration and return its outputs.
  #
  # Returns: { packages, commands, links, devShell }
  evalConanConfig =
    nixpkgs:
    { configRoot
    , modules ? [ ]
    }:
    (nixpkgs.lib.evalModules {
      specialArgs = defaultSpecialArgs { inherit nixpkgs; };
      modules = [
        ../modules/configuration
        { inherit configRoot; }
      ] ++ modules;
    }).config.outputs;

  # Invoke conan-flake as a submodule, integrating this into a larger
  # configuration management system.
  submoduleWith =
    nixpkgs:
    { configRoot
    , modules ? [ ]
    , specialArgs ? { }
    }:
    # NOTE: keep in sync with evalConanConfig
    nixpkgs.lib.types.submoduleWith {
      specialArgs = (defaultSpecialArgs { inherit nixpkgs; }) // specialArgs;
      modules = [
        ../modules/configuration
        { inherit configRoot; }
      ] ++ modules;
    };
in
{
  inherit
    parseSystemArch
    parseSystemOs
    evalConanConfig
    submoduleWith
    ;
}
