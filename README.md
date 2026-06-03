[![status-badge](https://ci.codeberg.org/api/badges/17003/status.svg?events=push%2Cpull_request)](https://ci.codeberg.org/repos/17003)[![status-badge](https://ci.codeberg.org/api/badges/17003/status.svg?events=release)](https://ci.codeberg.org/repos/17003)

# conan-flake — Nix module for Conan configuration

The conan-flake module bridges the gap between [Nix](https://nixos.org/) and the [Conan C/C++ Package Manager](https://conan.io/), supporting a declarative configuration style and common development workflows.

For a user profile configuration like the following:

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
    # Programs you want to make available in the shell:
    tools = { inherit (pkgs) cmake; };
  };
}
```

The conan-flake module works with plain Nix (no flakes), Nix flakes, [`flake-parts`](https://flake.parts/), or as a [devenv](https://devenv.sh/) module.

> [!NOTE]
> Check the official [conan-flake](https://flake.parts/options/conan-flake.html) docs for a complete list of the available options and for initial setup instructions on `flake-parts` scenarios.

Configure Conan in any devenv shell with the [supported integration](https://devenv.sh/reference/options/#languagescplusplusconanenable):

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

        # Enable only local remotes (i.e., only of local-recipe-index type):
        offline = true;
      };
    };
  };
}
```

> [!NOTE]
> See [how to setup Conan](https://devenv.sh/languages/cplusplus/#setting-up-the-conan-package-manager) in devenv for further details. The devenv integration automatically takes care of the CMake part by default, and the options `platformToolRequires.cmake` and `devShell.tools` are not required to be set explicitly in the `languages.cplusplus.conan.config` namespace.

> [!WARNING]
> Depending when this page is being accessed, devenv integration may still be pending approval upstream and the above links to the devenv docs missing. The devenv samples here can be tested nonetheless, by overriding _devenv itself_ with the version from our [upstream PR](https://github.com/cachix/devenv/pull/2787) &mdash; or with [our other branch](https://github.com/tarc/devenv/tree/feature/conan-flake-2.1.2), with the same implementation, except it's rebased on top of [devenv v2.1.2](https://github.com/cachix/devenv/tree/v2.1.2). See [examples/devenv-module-recipe](examples/devenv-module-recipe) and [devenv.yaml](examples/devenv-module-recipe/devenv.yaml) therein for more details.

The `flake-parts` integration requires conan-flake and `infuse` to be added to the flake inputs:

[embedmd]:# (./examples/flake-parts/flake.nix nix !/.*{ inputs/ !/.*inputs }/ s/#  // dedent)
```nix
{
  inputs = {
    nixpkgs.url = "github:cachix/devenv-nixpkgs/rolling";
    flake-parts.url = "github:hercules-ci/flake-parts";
    treefmt-nix.url = "github:numtide/treefmt-nix";

    # Add these two:
    conan-flake.url = "git+https://codeberg.org/tarcisio/conan-flake";
    infuse = {
      url = "git+https://codeberg.org/amjoseph/infuse.nix?rev=e837ece1b9de6ebcb7abd261f54a09bad3a2f820";
      flake = false;
    };
  };
  # ...
}
```

After importing `inputs.conan-flake.flakeModule`, it's possible to use the options from [`perSystem.conan`](https://flake.parts/options/conan-flake.html#opt-perSystem.conan) to configure a suitable Conan profile:

[embedmd]:# (./examples/flake-parts/flake.nix nix !/.*{ outputs/ !/.*outputs }/ s/#  // dedent)
```nix
{
  # ...
  outputs = inputs@{ self, nixpkgs, flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = nixpkgs.lib.systems.flakeExposed;

      imports = [
        inputs.conan-flake.flakeModule # Import this module
        inputs.treefmt-nix.flakeModule
      ];

      perSystem = { self', pkgs, config, ... }: {

        treefmt.config = {
          projectRoot = self;
          projectRootFile = "README.md";
          programs = {
            cmake-format.enable = true;
          };
        };

        # A suitable Conan profile:
        conan = {
          buildType = "Release";
          compilerCppStd = "23";

          platformToolRequires = {
            cmake = pkgs.cmake.version;
          };

          devShell = {
            tools = { inherit (pkgs) cmake; };
          };
        };

        devShells.default = pkgs.mkShell {
          inputsFrom = [
            # conan-flake exposes a `configuration` devShell by default that
            # can be used directly, or passed in the `inputsFrom` option as a
            # means to compose with other devShell modules:
            config.conan.outputs.devShell
            config.treefmt.build.devShell
          ];
          packages = [ pkgs.just ];
        }; # devShells
      };
    };
}
```

The example above can be found in the [flake-parts](examples/flake-parts) directory:

```shell
cd examples/flake-parts
direnv allow .
```

It can take a while before completing &mdash; after that, the `conan` command should be available in the path, and the required profile and other Conan settings already in place:

```shell
conan profile show
```

A Release, C++23 profile is expected:

```text
Host profile:
[settings]
arch=x86_64
build_type=Release
compiler=gcc
compiler.cppstd=23
compiler.libcxx=libstdc++11
compiler.version=15.2.0
os=Linux
[platform_tool_requires]
cmake/4.1.2

Build profile:
[settings]
arch=x86_64
build_type=Release
compiler=gcc
compiler.cppstd=23
compiler.libcxx=libstdc++11
compiler.version=15.2.0
os=Linux
[platform_tool_requires]
cmake/4.1.2
```

The resulting default _devShell_ defined above is a composition &mdash; it merges `config.conan.outputs.devShell` and `config.treefmt.build.devShell`, and appends `pkgs.just` to the resulting _devShell_'s package list for its _own sake_:

[embedmd]:# (./examples/flake-parts/flake.nix nix /.*devShells.default/ /.*}; # devShells/ dedent)
```nix
devShells.default = pkgs.mkShell {
  inputsFrom = [
    # conan-flake exposes a `configuration` devShell by default that
    # can be used directly, or passed in the `inputsFrom` option as a
    # means to compose with other devShell modules:
    config.conan.outputs.devShell
    config.treefmt.build.devShell
  ];
  packages = [ pkgs.just ];
}; # devShells
```

A possible sanity check could be to find the corresponding commands available in the path:

```shell
cmake --version
conan --version
treefmt --version
echo
just --version
```

Also, CMake's version should match the one listed in the _[platform_tool_requires]_ section of the `conan profile show` command's output above:

```text
cmake version 4.1.2

CMake suite maintained and supported by Kitware (kitware.com/cmake).
Conan version 2.26.2
treefmt v2.5.0
just 1.50.0
```

## Usages

Although `conan-flake` is presented as a `flake-parts` module, there is a subset of its options that can be imported independently, directly into any Nix code. This use case is supported by two helper functions, exposed in the `lib` namespace of the flake defined by this repository: `evalConanConfig` and `submoduleWith`.

To use these functions, add conan-flake to your flake inputs:

[embedmd]:# (./examples/standalone-eval-conan-config/flake.nix nix !/.*{ inputs/ !/.*inputs }/ s/# {/{/ s/# }/}/ dedent)
```nix
{
  inputs = {
    nixpkgs.url = "github:cachix/devenv-nixpkgs/rolling";

    # Add this:
    conan-flake.url = "git+https://codeberg.org/tarcisio/conan-flake";
  };
  # ...
}
```

Now `conan-flake.lib.evalConanConfig` can be used to configure, for each system supported, a Conan configuration and output a _devShell_ and a _check_ command. With this schema in place:

[embedmd]:# (./examples/standalone-eval-conan-config/flake.nix nix !/.*{ outputs/ !/.*outputs }/ s/#  // dedent)
```nix
{
  # ...
  outputs = { self, nixpkgs, conan-flake, ... }:
    let
      eachSystem = nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed;

      # See below for the actual `perSystem` function definition:
      perSystem = system: {
        devShells = {
          # ...
        };
        checks = {
          # ...
        };
      };

      systemOutputs = eachSystem perSystem;
 in
 {
   devShells = nixpkgs.lib.mapAttrs (_: s: s.devShells) systemOutputs;
   checks = nixpkgs.lib.mapAttrs (_: s: s.checks) systemOutputs;
 };
}
```


### Standalone usage with  `conan-flake.lib.evalConanConfig`

This example can be found in the [standalone-eval-conan-config] directory:

```shell
cd examples/standalone-eval-conan-config
```

Where the actual `perSystem` function is used to configure a Release, C++17 profile:

[embedmd]:# (./examples/standalone-eval-conan-config/flake.nix nix !/.*{ perSystem/ !/.*perSystem }/ s/#  // dedent)
```nix
{
  # ...
  perSystem = system:
    let
      pkgs = nixpkgs.legacyPackages.${system};

      configuration = conan-flake.lib.evalConanConfig pkgs {

        configRoot = self;

        modules = [
          ({ pkgs, config, ... }: {
            buildType = "Release";
            compilerCppStd = "17";

            platformToolRequires = {
              cmake = pkgs.cmake.version;
            };

            devShell = {
              tools = { inherit (pkgs) cmake; };
            };

            remotes.local = {
              url = "./repo";
              local = true;
              allowedPackages = [ "hello-world/0.0.1.cci.20260428" ];
            };

            offline = true;
          })
        ];
      };
    in
    {
      devShells.default = configuration.devShell;
      checks.test = pkgs.runCommandWith
        {
          name = "standalone-eval-conan-config-test-conan-create";
          inherit (pkgs) stdenv;
          derivationArgs = { inherit (configuration.devShell) buildInputs nativeBuildInputs; };
        }
        ''
          (
          set -x
          ${configuration.devShell.shellHook}
          conan create ${self} -tf "" --build=missing 2>&1 | grep "example/0.0.1"
          touch $out
          )
        ''; # checks.test
    };
    # ...
}
```

This configuration now can be used to set a developer environment with [`direnv`](https://direnv.net/):

```shell
direnv allow .
```

But even a plain `nix develop` would suffice:

```shell
nix develop .
```

From within this shell, the following command can be used to obtain the resulting profile:

```shell
conan profile show
```

To the `buildType` and `compilerCppStd` conan-flake options correspond, respectively, the _build_type_ and _compiler.cppstd_ entries in its output:

```text
Host profile:
[settings]
arch=x86_64
build_type=Release
compiler=gcc
compiler.cppstd=17
compiler.libcxx=libstdc++11
compiler.version=15.2.0
os=Linux
[platform_tool_requires]
cmake/4.1.2

Build profile:
[settings]
arch=x86_64
build_type=Release
compiler=gcc
compiler.cppstd=17
compiler.libcxx=libstdc++11
compiler.version=15.2.0
os=Linux
[platform_tool_requires]
cmake/4.1.2
```

In the [standalone-eval-conan-config] directory, the [conanfile.py] recipe file defines a C++ package &mdash; _example/0.0.1_ &mdash; it's possible to call `conan create` on it, and export this package into the local Conan cache:

```shell
conan create . --build=missing
```

The above command is going to install the dependencies and then build the _example/0.0.1_ package. Then export it to the local Conan cache and test it afterwards against [standalone-eval-conan-config/test_package]. If everything goes well, the last lines from the previous command would be the test package's output:

```text
hello-world: Hello World Release!
  hello-world: __x86_64__ defined
  hello-world: _GLIBCXX_USE_CXX11_ABI 1
  hello-world: __cplusplus201703
  hello-world: __GNUC__15
  hello-world: __GNUC_MINOR__2
example/0.0.1 test_package
```

> [!WARNING]
> There's still no support for the automatic nixification of `conanfile.py` (or even `conanfile.txt`, for that matter) package definitions; the conan-flake module is about the Conan _configuration_ side of things, that is: profiles, settings, remotes...

There's also a _check_ `test` function defined along with each `default` _devShell_:

[embedmd]:# (./examples/standalone-eval-conan-config/flake.nix nix /.*checks.test/ /.*# checks.test/ dedent)
```nix
checks.test = pkgs.runCommandWith
  {
    name = "standalone-eval-conan-config-test-conan-create";
    inherit (pkgs) stdenv;
    derivationArgs = { inherit (configuration.devShell) buildInputs nativeBuildInputs; };
  }
  ''
    (
    set -x
    ${configuration.devShell.shellHook}
    conan create ${self} -tf "" --build=missing 2>&1 | grep "example/0.0.1"
    touch $out
    )
  ''; # checks.test
```

The `-tf ""` argument is required to prevent it from running the package test on a Nix store location[^1]:

```'shell
nix flake check .
```

[conanfile.py]: examples/standalone-eval-conan-config/conanfile.py

[standalone-eval-conan-config]: examples/standalone-eval-conan-config

[standalone-eval-conan-config/test_package]: examples/standalone-eval-conan-config/test_package

[^1]: When testing, [standalone-eval-conan-config/test_package] is built _in source_, which happens in the Nix store when triggered via _checks_.


### Standalone usage with  `conan-flake.lib.submoduleWith`

This example can be found in the [test/standalone-submodule-with](test/standalone-submodule-with) directory:

```shell
cd test/standalone-submodule-with
```

Where the actual `perSystem` function is used to configure a Debug, C++14 profile:

[embedmd]:# (./test/standalone-submodule-with/flake.nix nix !/.*{ perSystem/ !/.*perSystem }/ s/#  // dedent)
```nix
{
  # ...
  perSystem = system:
    let
      pkgs = nixpkgs.legacyPackages.${system};
      lib = pkgs.lib;
      stdenv = pkgs.stdenv;
      conanSubmodule = conan-flake.lib.submoduleWith pkgs { configRoot = self; };
      conanModule = {
        options = {
          conan = lib.mkOption {
            type = conanSubmodule;
            description = "Conan configuration";
            default = { };
          };
        };
      };
      conanModuleConfig = (lib.evalModules {
        modules = [
          {
            imports = [ conanModule ];

            conan = {
              buildType = "Debug";
              compilerCppStd = "14";

              platformToolRequires = {
                cmake = pkgs.cmake.version;
              };

              devShell = {
                tools = { inherit (pkgs) cmake; };
              };

              remotes.local = {
                url = "./repo";
                local = true;
                allowedPackages = [ "hello-world/0.0.1.cci.20260428" ];
              };

              offline = true;
            };
          }
        ];
      }).config.conan;
    in
    {
      devShells.default = conanModuleConfig.outputs.devShell;
      checks.test = pkgs.runCommandWith
        {
          name = "standalone-submodule-with-test-conan-create";
          inherit (conanModuleConfig) stdenv;
          derivationArgs = { inherit (conanModuleConfig.outputs.devShell) buildInputs nativeBuildInputs; };
        }
        ''
          (
          set -x
          ${conanModuleConfig.outputs.devShell.shellHook}
          conan create ${conanModuleConfig.info.configRoot} -tf="" --build=missing 2>&1 | grep "example/0.0.1"
          touch $out
          )
        '';
    };
    # ...
}
```


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
