# A pure Nix library that handles the Conan configuration.
{
  conanFlakeLib,
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
  # Utility functions:
  contains = k: builtins.any (x: x == k);

  # Nested namespaces:
  parsing = import ./parsing.nix { inherit conanFlakeLib; };
  types = import ./types.nix { inherit conanFlakeLib; };
  external = import ./external.nix { inherit conanFlakeLib; };
  packages = import ./packages.nix { inherit conanFlakeLib; };

  defaultSpecialArgs =
    {
      lib,
      infuse ? conanFlakeLib.external.infuse { inherit lib; },
      relativePathType ? conanFlakeLib.types.relativePathType lib,
      parseSystemArch ? conanFlakeLib.parsing.parseSystemArch,
      parseSystemOs ? conanFlakeLib.parsing.parseSystemOs,
      envSubmodule ? conanFlakeLib.types.envSubmodule lib,
      listOfGeneratorType ? conanFlakeLib.types.listOfGeneratorType lib,
      outputType ? conanFlakeLib.types.outputType lib,
      listOfOutputType ? conanFlakeLib.types.listOfOutputType lib,
      anyOutput ? conanFlakeLib.types.anyOutput lib,
      mergeSelected ? conanFlakeLib.mergeSelected lib,
      pnameFromStdenvCc ? conanFlakeLib.pnameFromStdenvCc lib,
      versionFromStdenvCc ? conanFlakeLib.versionFromStdenvCc lib,
      conanPackage ? conanFlakeLib.packages.conan,
      embedmdPackage ? conanFlakeLib.packages.embedmd,
      mdshPackage ? conanFlakeLib.packages.mdsh_0_9_3,
    }:
    {
      inherit (conanFlakeLib) contains;
      inherit
        infuse
        relativePathType
        parseSystemArch
        parseSystemOs
        envSubmodule
        listOfGeneratorType
        outputType
        listOfOutputType
        anyOutput
        mergeSelected
        pnameFromStdenvCc
        versionFromStdenvCc
        conanPackage
        embedmdPackage
        mdshPackage
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
      specialArgs = conanFlakeLib.defaultSpecialArgs { inherit (nixpkgs) lib; };
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
      modules = conanFlakeLib.submodule-modules ++ modules;
      specialArgs = (conanFlakeLib.defaultSpecialArgs { inherit lib; }) // specialArgs;
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

  mergeSelected =
    lib: f: select: attrs:
    lib.mkMerge (lib.mapAttrsToList select (lib.filterAttrs f attrs));

  pnameFromStdenvCc =
    lib: stdenv:
    let
      cc = stdenv.cc;
      name = cc.meta.name;
      components = lib.splitString "-" name;
      length = builtins.length components;
      pnameLength = if length >= 1 then length - 1 else 0;
      pnameComponents = lib.lists.take pnameLength components;
    in
    builtins.concatStringsSep "" pnameComponents;

  versionFromStdenvCc =
    lib: stdenv:
    let
      cc = stdenv.cc;
      name = cc.meta.name;
      components = lib.splitString "-" name;
      length = builtins.length components;
      pnameLength = if length >= 1 then length - 1 else 0;
      versionLength = length - pnameLength;
    in
    if versionLength > 0 then builtins.elemAt components (length - 1) else "";
}
