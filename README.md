[![status-badge](https://ci.codeberg.org/api/badges/17003/status.svg?events=push%2Cpull_request)](https://ci.codeberg.org/repos/17003)[![status-badge](https://ci.codeberg.org/api/badges/17003/status.svg?events=release)](https://ci.codeberg.org/repos/17003)

# conan-flake — Nix module for Conan configuration

The conan-flake module bridges the gap between [Nix](https://nixos.org/) and the [Conan C/C++ Package Manager](https://conan.io/), supporting a declarative configuration style and common development workflows.

For instance, for a user profile configuration like the following:

[embedmd]:# (./examples/devenv-module/devenv.nix ini !/.*Profile properties:/ /cmake\/X\.Y\.Z/ s/# // dedent)
```ini
[settings]
build_type=Debug
compiler.cppstd=14

[platform_tool_requires]
cmake/X.Y.Z
```

There correspond the following options:

[embedmd]:# (./examples/devenv-module/devenv.nix nix !/.*Corresponding options:/ !/# devShell/ dedent s/# {/{/ s/# }/}/)
```nix
{
  buildType = "Debug";
  compilerCppStd = "14";

  platformToolRequires = {
    cmake = pkgs.cmake.version;
  };

  devShell = {
    # Programs you want to make available in the shell.
    tools = {
      inherit (pkgs) cmake;
    };
  };
}
```

The conan-flake module works with plain Nix (no flakes), Nix flakes, [`flake-parts`](https://flake.parts/), or as a [devenv](https://devenv.sh/) module.

> [!NOTE]
> Check the official [conan-flake](https://flake.parts/options/conan-flake.html) docs for a complete list of the available options.

The easiest way to have it going is to couple conan-flake to a developer environment — such as devenv — through the supported integration:

[embedmd]:# (./examples/devenv-module-recipe/devenv.nix nix !/.*devenv languages.cplusplus option:/ !/# languages.cplusplus/ s/# {/{/ s/# }/}/ dedent)
```nix
{
  languages.cplusplus = {
    enable = true;

    conan = {
      enable = true;
      install.enable = true;

      config = {
        buildType = "Release";
        compilerCppStd = "17";

        # It's possible to specify Conan remotes explicitly, including
        # local-recipe-index remotes, in which case the `url` is taken as a
        # relative path to the root of the configuration:
        remotes.local = {
          url = "./repo";
          local = true;
          allowedPackages = [
            "hello-world/0.0.1.cci.20260428"
          ];
        };

        # Enable only local remotes (i.e. only of local-recipe-index type):
        offline = true;
      };
    };
  };
}
```

> [!NOTE]
> See [how to setup Conan](https://devenv.sh/languages/cplusplus/#setting-up-the-conan-package-manager) in devenv, for further details on their integration. Also it automatically takes care of the CMake part by default; it's not necessary to set the `languages.cplusplus.conan.config.platformToolRequires.cmake` and `languages.cplusplus.conan.config.devShell.tools.cmake` options explicitly.

> [!WARNING]
> Depending when you're reading this, devenv integration may still be ongoing and the above link may be missing.

Although this module is presented as a `flake-parts` module, there is a subset of its options that can be imported independently, directly into any Nix code:


## In-depth overview

A common way to support C and C++ packages in [Nix](https://nixos.org/) is to integrate their build system and expose a specialized `stdenv` derivation responsible to bring in all of the necessary tools required to consistently generate, configure, build and link those &mdash; and related &mdash; packages. The `stdenv` derivation is a special derivation, defined in [Nixpkgs](https://github.com/NixOS/nixpkgs), and can be regarded as a kind of a pattern as well — see its reference: [The Standard Environment](https://nixos.org/manual/nixpkgs/stable/#chap-stdenv), on the [Nixpkgs Reference Manual](https://nixos.org/manual/nixpkgs/stable/). For an introduction to the `stdenv` as a pattern, see [19. Fundamentals of Stdenv](https://nixos.org/guides/nix-pills/19-fundamentals-of-stdenv.html), from the [Nix Pills](https://nixos.org/guides/nix-pills/) series.

For instance:

- To integrate with the LLVM compiler infrastructure, there is a `pkgs.llvmPackages.stdenv` derivation; or better yet:

[embedmd]:# (./examples/llvm-flake-parts/flake.nix nix /.*stdenv = pkgs.overrideCC/ /   pkgs.llvmPackages.clangUseLLVM/ dedent)
```nix
stdenv = pkgs.overrideCC
  (
    pkgs.llvmPackages.libcxxStdenv.override {
      targetPlatform.useLLVM = true;
    }
  )
  pkgs.llvmPackages.clangUseLLVM
```

See [this question](https://discourse.nixos.org/t/how-to-create-a-working-llvm-based-stdenv-for-c-development/61581), or [this issue](https://github.com/NixOS/nixpkgs/issues/277564), for further details on how to create a LLVM-based `stdenv` for C++ development.

- The `pkgs.cudaPackages.backendStdenv` derivation helps integrate the [NVIDIA](https://www.nvidia.com/) and the host compilers while making it possible to link against the [CUDA](https://docs.nvidia.com/cuda/) libraries available in `pkgs.cudaPackages`.

Therefore, the conan-flake module is parameterized by a `stdenv` option (defaulting to `pkgs.stdenv`), driving this complexity away from the module. Also it exposes a _devShell_ output that can be used as an `inputsFrom` option for _devShell_ composition:

[embedmd]:# (./examples/simple-flake-parts/flake.nix nix /.*file: examples\/simple-flake-parts\/flake\.nix/ /.*}; # outputs/ dedent)
```nix
# file: examples/simple-flake-parts/flake.nix
outputs = inputs@{ self, nixpkgs, flake-parts, ... }:
  flake-parts.lib.mkFlake { inherit inputs; } {
    systems = nixpkgs.lib.systems.flakeExposed;
    imports = [
      # `flake-parts` module import declaration:
      inputs.conan-flake.flakeModule
    ];
    perSystem = { self', pkgs, config, ... }: {
      conan = {
        # The `stdenv` module option:
        stdenv = pkgs.stdenv;
        # Section [platform_tool_requires]
        platformToolRequires = {
          cmake = pkgs.cmake.version;
        };
        # Further customize devShell options:
        devShell = {
          tools = {
            inherit (pkgs) cmake;
          };
        };
      };
      devShells.default = pkgs.mkShell {
        inputsFrom = [
          # The preferred way to interface with the conan-flake module in a
          # devShell:
          config.devShells.configuration # == `config.conan.outputs.devShell`
        ];
      };
    };
  }; # outputs
```

Another example featuring a more involved `stdenv` setup:

[embedmd]:# (./examples/llvm-flake-parts/flake.nix nix /.*file: examples\/llvm-flake-parts\/flake\.nix/ !/# outputs/ dedent)
```nix
# file: examples/llvm-flake-parts/flake.nix
outputs = inputs@{ self, nixpkgs, flake-parts, ... }:
  flake-parts.lib.mkFlake { inherit inputs; } {
    systems = nixpkgs.lib.systems.flakeExposed;
    imports = [
      # `flake-parts` module import declaration:
      inputs.conan-flake.flakeModule
    ];
    perSystem = { self', pkgs, config, ... }: {
      conan = {
        # The `stdenv` module option:
        stdenv = pkgs.overrideCC
          (
            pkgs.llvmPackages.libcxxStdenv.override {
              targetPlatform.useLLVM = true;
            }
          )
          pkgs.llvmPackages.clangUseLLVM;
        # By default: compiler.libcxx=libstdc++11, so undo it:
        compilerLibCxx = null;
        # Section [platform_tool_requires]
        platformToolRequires = {
          cmake = pkgs.cmake.version;
        };
        # Further customize devShell options:
        devShell = {
          tools = {
            inherit (pkgs) cmake;
          };
        };
      };
      devShells.default = pkgs.mkShell {
        inputsFrom = [
          # The preferred way to interface with the conan-flake module in
          # devShell:
          config.devShells.configuration # == `config.conan.outputs.devShell`
        ];
      };
    };
  };
```


## Getting started

The example in this session makes use of the [`flake-parts`](https://flake.parts/) integration — for other approaches see [below](#devenv-integrations).

[embedmd]:# (./examples/flake-parts/flake.nix nix)
```nix
# file: examples/flake-parts/flake.nix
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

      # `flake-parts` options to enable debug inspecting.
      # debug = true;

      perSystem = { self', pkgs, config, ... }: {

        treefmt.config = {
          projectRoot = self;
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
            tools = {
              inherit (pkgs) cmake;
            };
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
            config.devShells.configuration # == `config.conan.outputs.devShell`
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


## devenv integrations

Using the [conan-flake devenv integration](https://github.com/tarc/devenv/tree/feature/conan-flake):

[embedmd]:# (./examples/devenv-module/devenv.nix nix)
```nix
# file: examples/devenv-module/devenv.nix
{ config
, inputs
, pkgs
, ...
}:
{
  name = "conan-flake-dev";

  languages.cplusplus = {
    enable = true;

    conan = {
      enable = true;
      install.enable = true;

      config = {
        # The base developer environment:
        # stdenv = pkgs.cudaPackages.backendStdenv;
        # by default, this is config.stdenv.

        # Profile properties:
        # [settings]
        # build_type=Debug
        # compiler.cppstd=14

        # [platform_tool_requires]
        # cmake/X.Y.Z

        # Corresponding options:
        # {
          buildType = "Debug";
          compilerCppStd = "14";

          platformToolRequires = {
            cmake = pkgs.cmake.version;
          };

          devShell = {
            # Programs you want to make available in the shell.
            tools = {
              inherit (pkgs) cmake;
            };
          };
        # }
        # devShell
      };
    };
  };
}
```


Using conan-flake in [devenv with `flake-parts`](https://devenv.sh/guides/using-with-flake-parts/):

[embedmd]:# (./examples/devenv/flake.nix nix)
```nix
# file: examples/devenv/flake.nix
{
  inputs = {
    devenv-root = {
      url = "file+file:///dev/null";
      flake = false;
    };
    nixpkgs.url = "github:cachix/devenv-nixpkgs/rolling";
    flake-parts.url = "github:hercules-ci/flake-parts";
    git-hooks.url = "github:cachix/git-hooks.nix";
    devenv.url = "github:cachix/devenv";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    nix2container.url = "github:nlewo/nix2container";
    mk-shell-bin.url = "github:rrbutani/nix-mk-shell-bin";
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
        inputs.devenv.flakeModule
        inputs.conan-flake.flakeModule
      ];

      # `flake-parts` options to enable debug inspecting.
      # debug = true;

      perSystem = { self', pkgs, config, ... }: {

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
            tools = {
              inherit (pkgs) cmake;
            };
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

        devenv = {
          shells.default = {
            name = "conan-flake-dev";

            inputsFrom = [
              # conan-flake exposes a `configuration` devShell by default that
              # can be used directly, or passed in the inputsFrom option as a
              # means to compose with other devShell modules.
              config.devShells.configuration # == `config.conan.outputs.devShell`
            ];

            packages = [ pkgs.just ];

            treefmt = {
              enable = true;
              config = {
                programs = {
                  nixpkgs-fmt.enable = true;
                  cmake-format.enable = true;
                };
              };
            };
          };
        };

        # conan-flake doesn't set the default package, but you can do it here.
        # packages.default = self'.packages.example;
      };
    };
}
```


## Templates

### Simple conan-flake project with only a `flake-parts`-based configuration

This template will get you only the `flake.nix`, `.envrc` and `.gitignore` files.

```shell
mkdir -p default && cd default
nix flake init -t "git+https://codeberg.org/tarcisio/conan-flake"
```

### C++ conan-flake, `flake-parts`-based project

Alongside the files from the previous item, this template will provide you also with a complete sample Conan-based C++ project.

```shell
mkdir -p example && cd example
git init
nix flake init -t "git+https://codeberg.org/tarcisio/conan-flake"#templates.example
direnv allow .
```

After this initial setup is complete, test if everything is working:

```shell
conan create . --build=missing
```

The remaining templates in this section can be initialized and validated in a
similar manner:

### LLVM-based C++ conan-flake project

This template is also `flake-parts`-based.

```shell
nix flake init -t "git+https://codeberg.org/tarcisio/conan-flake"#templates.llvm
```

### C++ conan-flake, "devenv with `flake-parts`"-based project

```shell
nix flake init -t "git+https://codeberg.org/tarcisio/conan-flake"#templates.devenv
```

### C++ conan-flake, devenv-based project

```shell
nix flake init -t "git+https://codeberg.org/tarcisio/conan-flake"#templates.devenv-module
```

### C++ conan-flake standalone Nix module project

```shell
nix flake init -t "git+https://codeberg.org/tarcisio/conan-flake"#templates.standalone
```


## References

This project is heavily based on [`haskell-flake`](https://github.com/srid/haskell-flake), from which it takes its overall structure.

It's also influenced by the following projects in a number of ways:

- [devenv](https://devenv.sh/) ([GitHub](https://github.com/cachix/devenv)):
  - Among other things, the way it handles the Apple SDK in the developer environment on macOS — see [devshell.nix](nix/modules/configuration/devshell.nix);
- [`treefmt-nix`](https://github.com/numtide/treefmt-nix):
  - Integration with the bare Nix module system — see [default.nix](nix/lib/default.nix).
