# conan-flake &mdash; Nix module for Conan configuration

A common way to support C and C++ packages in [Nix](https://nixos.org/) is to integrate their build system and expose a specialized `stdenv` derivation responsible to bring in all of the necessary tools required to consistently generate, configure, build and link those packages. The `stdenv` derivation is a special derivation, defined in [Nixpkgs](https://github.com/NixOS/nixpkgs), and can be regarded as a kind of a pattern as well &mdash; see its reference: [The Standard Environment](https://nixos.org/manual/nixpkgs/stable/#chap-stdenv), on the [Nixpkgs Reference Manual](https://nixos.org/manual/nixpkgs/stable/). For an introduction to the `stdenv` as a pattern, see [19. Fundamentals of Stdenv](https://nixos.org/guides/nix-pills/19-fundamentals-of-stdenv.html), from the [Nix Pills](https://nixos.org/guides/nix-pills/) series.

For instance:
- To integrate with the LLVM compiler infrastructure, there is a `pkgs.llvmPackages.stdenv` derivation;
- The `pkgs.cudaPackages.backendStdenv` derivation helps integrate the NVIDIA and the host compilers while making it possible to link against the CUDA libraries available in `pkgs.cudaPackages`.

Therefore, the `conan-flake` module is parameterized by a `stdenv` option (defaulting to `pkgs.stdenv`), driving all this complexity to more suitable places. Also it exposes a _devShell_ output that can be used as an `inputsFrom` option for _devShell_ composition:

```nix
{
  outputs = inputs@{ self, nixpkgs, flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = nixpkgs.lib.systems.flakeExposed;
      imports = [
        inputs.conan-flake.flakeModule
      ];
      perSystem = { self', pkgs, config, ... }: {
        conan = {
          # The `stdenv` module option: 
          stdenv = pkgs.stdenv;
          platformToolRequires = {
            cmake = pkgs.cmake.version;
          };
          devShell = {
            packages = [
              pkgs.cmake
            ];
          };
        };
        devShells.default = pkgs.mkShell {
          inputsFrom = [
            # By default `config.devShells.configuration` is the same value as
            # `config.conan.outputs.devShell`:
            config.devShells.configuration
          ];
        };
      };
    };
}
```

The `conan-flake` module works with plain Nix (no flakes), Nix flakes, [`flake-parts`](https://flake.parts/), or as a [`devenv`](https://devenv.sh/) module.


## Getting started

The example in this session makes use of the [flake-parts](https://flake.parts/) integration &mdash; for other approaches see [below](#integrations).

```nix
# file: flake.nix
{
  inputs = {
    nixpkgs.url = "github:cachix/devenv-nixpkgs/rolling";
    flake-parts.url = "github:hercules-ci/flake-parts";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    conan-flake.url = "git+https://codeberg.org/tarcisio/conan-flake";
    infuse = {
      url = "git+https://codeberg.org/amjoseph/infuse.nix?rev=e837ece1b9de6ebcb7abd261f54a09bad3a2f820";
      flake = false;
    };
  };
  outputs = inputs@{ self, nixpkgs, flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = nixpkgs.lib.systems.flakeExposed;
      imports = [
        inputs.conan-flake.flakeModule
        inputs.treefmt-nix.flakeModule
      ];

      # flake-parts options to enable debug inspecting.
      # debug = true;

      perSystem = { self', pkgs, config, ... }: {

        treefmt.config = {
          projectRoot = inputs.conan-flake;
          projectRootFile = "README.md";
          programs = {
            nixpkgs-fmt.enable = true;
            cmake-format.enable = true;
          };
        };

        # A single Conan configuration is supported.
        conan = {
          # The base developer environment.
          # By default, this is pkgs.stdenv.
          # stdenv = pkgs.cudaPackages.backendStdenv;

          settings.base = {
            # gcc = {
            #   version = [ "15.2.0" ];
            # };
          };

          platformToolRequires = {
            cmake = pkgs.cmake.version;
          };

          devShell = {
            # Programs you want to make available in the shell.
            packages = [
              pkgs.cmake
            ];
          };

          # It's possible to specify Conan remotes explicitly, including
          # local-recipe-index remotes -- in which case the `url` is taken as a
          # relative path to the root of the configuration.
          # remotes.local = {
          #   url = "./repo";
          #   local = true;
          #   allowedPackages = [
          #     "hello-world/0.0.1.cci.20260428"
          #   ];
          # };

          # Enable only local remotes (i.e. only of local-recipe-index type):
          # offline = true;
        };

        devShells.default = pkgs.mkShell {
          inputsFrom = [
            # conan-flake exposes a `configuration` devShell by default that
            # can be used directly, or passed in the inputsFrom option as a
            # means to compose with other devShell modules.
            config.devShells.configuration
            config.treefmt.build.devShell
          ];

          packages = [ pkgs.just ];
        };

        # conan-flake doesn't set the default package, but you can do it here.
        # packages.default = self'.packages.example;
      };
    };
}
```


## Integrations

Integrating with [`devenv`](https://devenv.sh/).


## Templates

### Simple `flake-parts` configuration

```shell
mkdir -p default && cd default
nix flake init -t "git+https://codeberg.org/tarcisio/conan-flake"
```

### C++ `flake-parts` project

```shell
mkdir -p example && cd example
nix flake init -t "git+https://codeberg.org/tarcisio/conan-flake"#templates.example
```

### C++ `devenv` project

```shell
mkdir -p devenv && cd devenv
nix flake init -t "git+https://codeberg.org/tarcisio/conan-flake"#templates.devenv
```

### C++ standalone Nix module project

```shell
mkdir -p standalone && cd standalone
nix flake init -t "git+https://codeberg.org/tarcisio/conan-flake"#templates.standalone
```


## References

This project is heavily based on [`haskell-flake`](https://github.com/srid/haskell-flake), from where it takes its overall structure.

It's also influenced by the following projects in a number of ways:

- [`devenv`](https://devenv.sh/) ([GitHub](https://github.com/cachix/devenv)):
  - The way it handles the Apple SDK in the developer environment on macOS &mdash; see [devshell.nix](nix/modules/configuration/devshell.nix);
- [`treefmt-nix`](https://github.com/numtide/treefmt-nix):
  - Integration with the bare Nix module system &mdash; see [default.nix](nix/modules/default.nix).
