# A pure Nix library that handles the Conan configuration.
{
  conanFlake,
  ...
}:
let
  module-options = ../modules/configuration;

  all-modules = nixpkgs: [
    {
      _module.args = {
        pkgs = nixpkgs;
        lib = nixpkgs.lib;
      };
    }
    module-options
  ];
in
{
  parsing = import ./parsing.nix { inherit conanFlake; };

  types = import ./types.nix { inherit conanFlake; };

  external = import ./external.nix { inherit conanFlake; };

  defaultSpecialArgs =
    {
      lib,
      infuse ? conanFlake.external.infuse { inherit lib; },
      relativePathType ? conanFlake.types.relativePathType lib,
      parseSystemArch ? conanFlake.parsing.parseSystemArch,
      parseSystemOs ? conanFlake.parsing.parseSystemOs,
      envSubmodule ? conanFlake.types.envSubmodule lib,
      outputType ? conanFlake.types.outputType lib,
      listOfOutputType ? conanFlake.types.listOfOutputType lib,
      anyOutput ? conanFlake.types.anyOutput lib,
    }:
    {
      inherit
        infuse
        relativePathType
        parseSystemArch
        parseSystemOs
        envSubmodule
        outputType
        listOfOutputType
        anyOutput
        ;
    };

  # conan-flake can be loaded into a submodule.
  submodule-modules = [
    (
      { config, lib, ... }:
      let
        inherit (lib) mkOption types;
      in
      {
        options.pkgs = mkOption {
          type = types.uniq (types.lazyAttrsOf (types.raw or types.unspecified));
          description = ''
            Nixpkgs to use in conan-flake.
          '';
        };
        config._module.args = {
          pkgs = config.pkgs;
        };
      }
    )
    module-options
  ];

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
    nixpkgs: configuration:
    # NOTE: keep in sync with submoduleWith
    nixpkgs.lib.evalModules {
      modules = all-modules nixpkgs ++ [ configuration ];
      specialArgs = conanFlake.defaultSpecialArgs { inherit (nixpkgs) lib; };
    };

  # Invoke conan-flake as a submodule, integrating this into a larger
  # configuration management system.
  submoduleWith =
    lib:
    {
      modules ? [ ],
      specialArgs ? { },
    }:
    # NOTE: keep in sync with evalConanConfig
    lib.types.submoduleWith {
      modules = conanFlake.submodule-modules ++ modules;
      specialArgs = (conanFlake.defaultSpecialArgs { inherit lib; }) // specialArgs;
    };

  # Like pkgs.runCommandWith but runs inside nix-shell with a mutable config directory.
  runCommandWithInSimulatedShell =
    nixpkgs: stdenv: devShell: configRoot: homeRoot: name: attrs: command:
    nixpkgs.runCommandWith
      {
        inherit name;
        inherit stdenv;
        derivationArgs = attrs // {
          inherit (devShell) buildInputs nativeBuildInputs;
        };
      }

      ''
        set -euo pipefail

        # Copy configuration to a mutable area:
        export HOME=$TMP
        mkdir -p $HOME
        cd $HOME
        TARGET="$(realpath -m "$HOME/${nixpkgs.lib.escapeShellArg homeRoot}/..")"
        rootChd="."
        if [[ "$HOME" == "$TARGET"* ]]; then
          # If the current dir is a child path of TARGET:
          if ! [[ "$HOME" == "$TARGET" ]]; then
            rootChd="$(basename ${configRoot})"
          fi
        elif [[ ! -d "$TARGET" ]]; then
          mkdir -p "$TARGET"
        fi
        TARGET="$(realpath -m "$HOME/"${nixpkgs.lib.escapeShellArg homeRoot})"
        cp -R ${configRoot} "$TARGET"
        chmod -R a+w "$TARGET"
        cd "$TARGET"
        cd "$rootChd"
        ${devShell.shellHook}

        cd "$CONAN_FLAKE_HOME"
        ${command}
        touch $out
      '';
}
