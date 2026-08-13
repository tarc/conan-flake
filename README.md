<div align="center">

# conan-flake

**Nix module for [Conan](https://conan.io/) configuration**

<p>
<a href="https://ci.codeberg.org/repos/17003" target="_blank">
  <img src="https://ci.codeberg.org/api/badges/17003/status.svg?events=push%2Cpull_request" alt="status-badge" />
</a>
<a href="https://ci.codeberg.org/repos/17003" target="_blank">
  <img src="https://ci.codeberg.org/api/badges/17003/status.svg?events=release" alt="status-badge" />
</a>
<a href="https://devenv.sh" target="_blank">
  <img src="https://devenv.sh/assets/devenv-badge.svg"/>
</a>
</p>

</div>

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
  profiles.default = {
    settings.build_type = "Debug";
    settings."compiler.cppstd" = "14";

    platformToolRequires = {
      cmake = pkgs.cmake.version;
    };
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

[embedmd]:# (./examples/devenv-module-recipe/devenv.nix nix !/.*{ languages.cplusplus/ /# languages.cplusplus/ dedent)
```nix
# file: examples/devenv-module-recipe/devenv.nix
languages.cplusplus = {
  enable = true;

  conan = {
    enable = true;
    install.enable = true;

    config = {
      profiles.default = {
        settings.build_type = "Release";
        settings."compiler.cppstd" = "17";
      };

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
}; # languages.cplusplus
```

> [!NOTE]
> See [how to setup Conan](https://devenv.sh/languages/cplusplus/#setting-up-the-conan-package-manager) in devenv for further details. As can be seen from the above example, the devenv integration automatically takes care of the CMake part by default, and the `profiles.<name>.platformToolRequires` and `devShell.tools` options are not required to be set explicitly in the `languages.cplusplus.conan.config` namespace.

> [!WARNING]
> Depending when this page is being accessed, devenv integration may still be pending approval upstream and the above links to the devenv docs may be missing. The devenv samples here can still be tested nonetheless, by overriding _devenv itself_ with the version from our [upstream PR](https://github.com/cachix/devenv/pull/2787). See [examples/devenv-module-recipe](examples/devenv-module-recipe) and [devenv.yaml](examples/devenv-module-recipe/devenv.yaml) therein for more details.

All examples here are collected under [examples](examples) and can be used as [templates](#templates):

```shell
nix flake init -t "git+https://codeberg.org/tarcisio/conan-flake"#templates.devenv-module-recipe
```

It's also possible to interact directly with the example projects from a clone of this repository:[^1]

```shell
git clone ssh://git@codeberg.org/tarcisio/conan-flake.git
cd conan-flake
```

[^1]: Or, via _https_:

    ```shell
    git clone https://codeberg.org/tarcisio/conan-flake.git
    cd conan-flake
    ```

The above example (featuring the devenv integration) is on the [examples/devenv-module-recipe](examples/devenv-module-recipe) directory:

```shell
cd examples/devenv-module-recipe
```

The shell can be activated with [`direnv`](https://direnv.net/):

```shell
direnv allow .
```

And the Conan package defined in the [examples/devenv-module-recipe/conanfile.py](examples/devenv-module-recipe/conanfile.py) recipe can be built and tested with a call to `conan create`:

```shell
conan create . --build=missing
```

Whose output can be used to validate if the configuration was applied successfully:

```text
hello-world: Hello World Release!
  hello-world: __x86_64__ defined
  hello-world: _GLIBCXX_USE_CXX11_ABI 1
  hello-world: __cplusplus201703
  hello-world: __GNUC__15
  hello-world: __GNUC_MINOR__2
example/0.0.1 test_package
```

As for the `flake-parts` integration, it requires conan-flake and `infuse` to be added to the flake inputs:

[embedmd]:# (./examples/flake-parts/flake.nix nix !/.*{ inputs/ !/.*inputs }/ s/#  // dedent)
```nix
# file: examples/flake-parts/flake.nix
{
  inputs = {
    nixpkgs.url = "github:cachix/devenv-nixpkgs/rolling";
    flake-parts.url = "github:hercules-ci/flake-parts";
    treefmt-nix.url = "github:numtide/treefmt-nix";

    # Add these two:
    conan-flake.url = "git+https://codeberg.org/tarcisio/conan-flake";
    infuse = {
      url = "git+https://codeberg.org/amjoseph/infuse.nix?rev=364ea18b5611b5fd6a6acd7151411b430a70e194";
      flake = false;
    };
  };
  # ...
}
```

After importing `inputs.conan-flake.flakeModule`, it's possible to use the options from [`perSystem.conan`](https://flake.parts/options/conan-flake.html#opt-perSystem.conan) to configure a suitable Conan profile:

[embedmd]:# (./examples/flake-parts/flake.nix nix !/.*{ outputs/ !/.*outputs }/ s/#  // dedent)
```nix
# file: examples/flake-parts/flake.nix
{
  # ...
  outputs = inputs@{ self, nixpkgs, flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = nixpkgs.lib.systems.flakeExposed;

      imports = [
        inputs.conan-flake.flakeModule # Import this module
        inputs.treefmt-nix.flakeModule
      ];

      perSystem = { pkgs, config, ... }: {

        # A suitable Conan profile:
        conan = {
          profiles.default = {
            settings.build_type = "Release";
            settings."compiler.cppstd" = "23";
          };
        };

        devShells.default = pkgs.mkShell {
          inputsFrom = [
            # conan-flake computes a devShell that can be used directly or
            # appended to the `inputsFrom` option of another devShell as a
            # means to compose with other devShell modules:
            config.conan.outputs.devShell
            config.treefmt.build.devShell
          ];
          packages = [ pkgs.just ];
        }; # devShells

        treefmt.config = {
          projectRoot = self;
          projectRootFile = "README.md";
          programs = {
            cmake-format.enable = true;
          };
        };
      };
    };
}
```

The example above can be found in the [examples/flake-parts](examples/flake-parts) directory:

```shell
cd examples/flake-parts
direnv allow .
```

It can take a while before completing. After that, the `conan` command should be available in the path, and the required profile and other Conan settings already in place:

```shell
conan profile show
```

A Release, C++23 profile is expected:

<!-- > $
echo '```text'
cd examples/flake-parts
nix develop --command bash -c "profile-show-wrapper 2>/dev/null"
echo '```'
-->

<!-- BEGIN mdsh -->
```text
Host profile:
[settings]
arch=x86_64
build_type=Release
compiler=gcc
compiler.cppstd=23
compiler.libcxx=libstdc++11
compiler.version=15.3.0
os=Linux
[platform_tool_requires]
cmake/4.3.4
[conf]


Build profile:
[settings]
arch=x86_64
build_type=Release
compiler=gcc
compiler.cppstd=23
compiler.libcxx=libstdc++11
compiler.version=15.3.0
os=Linux
[platform_tool_requires]
cmake/4.3.4
[conf]


```
<!-- END mdsh -->

> [!NOTE]
> By default, conan-flake sets both CMake and the configured `stdenv.cc` compiler as [`devShell.tools`](https://flake.parts/options/conan-flake.html#opt-perSystem.conan.devShell.tools). Also, whatever CMake version, if any, ends up being in the `devShell.tools` is also set, by default, as a [`profiles.<name>.platformToolRequires`](https://flake.parts/options/conan-flake.html#opt-perSystem.conan.profiles._name_.platformToolRequires) of every profile.

The resulting default _devShell_ defined above is a composition &mdash; it merges `config.conan.outputs.devShell` and `config.treefmt.build.devShell`, and appends `pkgs.just` to the resulting _devShell_'s package list for its _own sake_:

[embedmd]:# (./examples/flake-parts/flake.nix nix /.*devShells.default/ /.*}; # devShells/ dedent)
```nix
devShells.default = pkgs.mkShell {
  inputsFrom = [
    # conan-flake computes a devShell that can be used directly or
    # appended to the `inputsFrom` option of another devShell as a
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

<!-- > $
echo '```text'
cd examples/flake-parts
nix develop --command bash -c "cmake --version && conan --version && treefmt --version && echo && just --version"
echo '```'
-->

<!-- BEGIN mdsh -->
```text
cmake version 4.3.4

CMake suite maintained and supported by Kitware (kitware.com/cmake).
Conan version 2.32.0-dev
treefmt v2.5.0
just 1.57.0
```
<!-- END mdsh -->

## Standalone usage

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
      perSystem = system:
        let
          # ...
          configuration = conan-flake.lib.evalConanConfig pkgs (
            # ...
          );
        in
        {
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
# file: examples/standalone-eval-conan-config/flake.nix
{
  # ...
  perSystem = system:
    let
      pkgs = nixpkgs.legacyPackages.${system};

      configuration = conan-flake.lib.evalConanConfig pkgs (

        { pkgs, config, ... }: {

          configRoot = self;

          profiles.default = {
            settings.build_type = "Release";
            settings."compiler.cppstd" = "17";
          };

          remotes.local = {
            url = "./repo";
            local = true;
            allowedPackages = [ "hello-world/0.0.1.cci.20260428" ];
          };

          offline = true;

          checks.example = {
            enable = true;
            drv =
              conan-flake.lib.runCommandWithInSimulatedShell pkgs config.stdenv config.outputs.devShell
                config.info.configRoot "./config"
                "standalone-eval-conan-config-example-conan-create"
                { }
                ''
                  (
                  set -x
                  conan create . --build=missing 2>&1 | grep -F "example/0.0.1"
                  touch $out
                  )
                ''; # checks.example
          };
        }
      );
    in
    {
      devShells.default = configuration.config.outputs.devShell;
      checks = configuration.config.outputs.checks;
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

To the `profiles.default.settings.build_type` and `profiles.default.settings."compiler.cppstd"` conan-flake options correspond, respectively, the _build_type_ and _compiler.cppstd_ entries in its output:

<!-- > $
echo '```text'
cd examples/standalone-eval-conan-config
nix develop --command bash -c "profile-show-wrapper 2>/dev/null"
echo '```'
-->

<!-- BEGIN mdsh -->
```text
Host profile:
[settings]
arch=x86_64
build_type=Release
compiler=gcc
compiler.cppstd=17
compiler.libcxx=libstdc++11
compiler.version=15.3.0
os=Linux
[platform_tool_requires]
cmake/4.3.4
[conf]


Build profile:
[settings]
arch=x86_64
build_type=Release
compiler=gcc
compiler.cppstd=17
compiler.libcxx=libstdc++11
compiler.version=15.3.0
os=Linux
[platform_tool_requires]
cmake/4.3.4
[conf]


```
<!-- END mdsh -->

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
> There's still no support for the automatic nixification of `conanfile.py` package definitions;[^2] the conan-flake module is about the Conan _configuration_ side of things, that is: profiles, settings, remotes...

[^2]: Or even of `conanfile.txt`, for that matter.

There's also a _check_ `example` function defined along with each `default` _devShell_:

[embedmd]:# (./examples/standalone-eval-conan-config/flake.nix nix /.*checks.example/ /.*# checks.example/ dedent)
```nix
checks.example = {
  enable = true;
  drv =
    conan-flake.lib.runCommandWithInSimulatedShell pkgs config.stdenv config.outputs.devShell
      config.info.configRoot "./config"
      "standalone-eval-conan-config-example-conan-create"
      { }
      ''
        (
        set -x
        conan create . --build=missing 2>&1 | grep -F "example/0.0.1"
        touch $out
        )
      ''; # checks.example
```

Run the check via `nix flake check`:

```'shell
nix flake check .
```

[conanfile.py]: examples/standalone-eval-conan-config/conanfile.py

[standalone-eval-conan-config]: examples/standalone-eval-conan-config

[standalone-eval-conan-config/test_package]: examples/standalone-eval-conan-config/test_package


### Standalone usage with  `conan-flake.lib.submoduleWith`

This example can be found in the [examples/standalone-submodule-with](examples/standalone-submodule-with) directory:

```shell
cd examples/standalone-submodule-with
```

Where the actual `perSystem` function is used to configure a Debug, C++14 profile:

[embedmd]:# (./examples/standalone-submodule-with/flake.nix nix !/.*{ perSystem/ !/.*perSystem }/ s/#  // dedent)
```nix
# file: examples/standalone-submodule-with/flake.nix
{
  # ...
  perSystem =
    system:
    let
      pkgs = nixpkgs.legacyPackages.${system};
      lib = pkgs.lib;
      conanSubmodule = conan-flake.lib.submoduleWith lib {
        modules = [
          {
            options.pkgs = lib.mkOption {
              default = pkgs;
              defaultText = lib.literalExpression "pkgs";
            };
            config.configRoot = self;
          }
        ];
      };
      conanModule = {
        options = {
          conan = lib.mkOption {
            type = conanSubmodule;
            description = "Conan configuration";
            default = { };
          };
        };
      }; # conanModule
      conanModuleConfig =
        (lib.evalModules {
          modules = [
            ({ config, ... }: {
              imports = [ conanModule ];

              conan = {
                profiles.default = {
                  settings.build_type = "Debug";
                  settings."compiler.cppstd" = "14";
                };

                devShell = {
                  tools = { inherit (pkgs) just; };
                };

                remotes.local = {
                  url = "./repo";
                  local = true;
                  allowedPackages = [ "hello-world/0.0.1.cci.20260428" ];
                };

                offline = true;

                checks.example = {
                  enable = true;
                  drv =
                    conan-flake.lib.runCommandWithInSimulatedShell pkgs config.conan.stdenv config.conan.outputs.devShell
                      config.conan.info.configRoot "./config"
                      "standalone-submodule-with-example-conan-create"
                      { }
                      ''
                        (
                        set -x
                        conan create . --build=missing 2>&1 | grep -F "example/0.0.1"
                        touch $out
                        )
                      ''; # checks.example
                };
              };
            })
          ];
        }).config.conan; # conanModuleConfig
    in
    {
      devShells.default = conanModuleConfig.outputs.devShell;
      checks = conanModuleConfig.outputs.checks;
    };
  # ...
}
```

Differently from the example in the previous section, here the options are loaded apart:

[embedmd]:# (./examples/standalone-submodule-with/flake.nix nix /.*conanSubmodule =/ /.*conanSubmodule =.*/ dedent)
```nix
conanSubmodule = conan-flake.lib.submoduleWith lib {
```

And integrated as a submodule of a larger configuration:

[embedmd]:# (./examples/standalone-submodule-with/flake.nix nix /.*conanModule =/ /.*# conanModule/ dedent)
```nix
conanModule = {
  options = {
    conan = lib.mkOption {
      type = conanSubmodule;
      description = "Conan configuration";
      default = { };
    };
  };
}; # conanModule
```

And the final configuration can be obtained with `lib.evalModules`:

[embedmd]:# (./examples/standalone-submodule-with/flake.nix nix /.*conanModuleConfig =/ /.*# conanModuleConfig/ dedent)
```nix
conanModuleConfig =
  (lib.evalModules {
    modules = [
      ({ config, ... }: {
        imports = [ conanModule ];

        conan = {
          profiles.default = {
            settings.build_type = "Debug";
            settings."compiler.cppstd" = "14";
          };

          devShell = {
            tools = { inherit (pkgs) just; };
          };

          remotes.local = {
            url = "./repo";
            local = true;
            allowedPackages = [ "hello-world/0.0.1.cci.20260428" ];
          };

          offline = true;

          checks.example = {
            enable = true;
            drv =
              conan-flake.lib.runCommandWithInSimulatedShell pkgs config.conan.stdenv config.conan.outputs.devShell
                config.conan.info.configRoot "./config"
                "standalone-submodule-with-example-conan-create"
                { }
                ''
                  (
                  set -x
                  conan create . --build=missing 2>&1 | grep -F "example/0.0.1"
                  touch $out
                  )
                ''; # checks.example
          };
        };
      })
    ];
  }).config.conan; # conanModuleConfig
```

Apart from that, all the other commands and considerations from the previous section also apply here.[^3]

[^3]: The definitions of the two methods: `conan-flake.lib.evalConanConfig` and `conan-flake.lib.submoduleWith` try to mimic `treefmt-nix`'s related design. Cf. their [`default.nix`](https://github.com/numtide/treefmt-nix/blob/main/default.nix) to compare definitions.

To make this difference clearer, the [standalone-submodule-with/default.nix](examples/standalone-submodule-with/default.nix) file defines and configures a `conan` option using only a fetched conan-flake module:

[embedmd]:# (./examples/standalone-submodule-with/default.nix nix)
```nix
# file: examples/standalone-submodule-with/default.nix
{
  lib,
  pkgs,
  inputs,
  ...
}:
let
  conan-flake = (
    fetchGit {
      url = "https://codeberg.org/tarcisio/conan-flake";
      name = "conan-flake";
      ref = "refs/branches/main";
      rev = "611c64cbf71b05bdd916cb45dfedd396f1ae10da";
      shallow = true;
    }
  );
  conanSubmodule =
    (import "${conan-flake}/nix/lib/lib.nix" { inherit inputs; }).conanFlakeLib.submoduleWith lib
      {
        modules = [
          {
            options.pkgs = lib.mkOption {
              default = pkgs;
              defaultText = lib.literalExpression "pkgs";
            };
            config.configRoot = ./.;
          }
        ];
      };
in
{
  options = {
    conan = lib.mkOption {
      type = conanSubmodule;
      description = "Conan configuration";
      default = { };
    };
  };

  config = {
    conan = {
      profiles.default = {
        settings.build_type = "Debug";
        settings."compiler.cppstd" = "14";
      };

      devShell = {
        tools = { inherit (pkgs) just; };
      };

      remotes.local = {
        url = "./repo";
        local = true;
        allowedPackages = [ "hello-world/0.0.1.cci.20260428" ];
      };

      offline = true;
    };
  };
}
```

To validate this setup, the [standalone-submodule-with/eval.nix](examples/standalone-submodule-with/eval.nix) file can be used to evaluate the previous definitions:

[embedmd]:# (./examples/standalone-submodule-with/eval.nix nix)
```nix
# file: examples/standalone-submodule-with/eval.nix
let
  pkgs = import <nixpkgs> { };
in
pkgs.lib.evalModules {
  modules = [
    ({ ... }: { config._module.args = { inherit pkgs; }; })
    ./default.nix
    # ./infuse.nix
  ];
}
```

To put these together, the following command instantiate the Nix files and print the resulting expression at a given attribute path:

```shell
nix-instantiate --eval eval.nix -A config.conan.profiles.default.text.text
```

The retuned value is that of the resulting default profile:

<!-- > $
echo '```text'
cd examples/standalone-submodule-with
nix develop --command bash -c "nix-instantiate --eval eval.nix -A config.conan.profiles.default.text.text"
echo '```'
-->

<!-- BEGIN mdsh -->
```text
"[settings]\narch=x86_64\nbuild_type=Debug\ncompiler=gcc\ncompiler.cppstd=14\ncompiler.libcxx=libstdc++11\ncompiler.version=15.3.0\nos=Linux\n\n[options]\n\n\n[tool_requires]\n\n\n[buildenv]\n\n\n[runenv]\n\n\n[conf]\n\n\n[replace_requires]\n\n\n[replace_tool_requires]\n\n\n[platform_requires]\n\n\n[platform_tool_requires]\ncmake/4.3.4\n"
```
<!-- END mdsh -->

Which can be compared with the one already generated:

```shell
cat .conan2/profiles/default
```

Both outputs match, but for the `\n` propper printing:

<!-- > $
echo '```text'
cd examples/standalone-submodule-with
nix develop --command bash -c "cat .conan2/profiles/default"
echo '```'
-->

<!-- BEGIN mdsh -->
```text
[settings]
arch=x86_64
build_type=Debug
compiler=gcc
compiler.cppstd=14
compiler.libcxx=libstdc++11
compiler.version=15.3.0
os=Linux

[options]


[tool_requires]


[buildenv]


[runenv]


[conf]


[replace_requires]


[replace_tool_requires]


[platform_requires]


[platform_tool_requires]
cmake/4.3.4
```
<!-- END mdsh -->

## In-depth overview

A common way to support C and C++ packages in [Nix](https://nixos.org/) is to integrate their build system and expose a specialized `stdenv` derivation responsible to bring in all of the necessary tools required to consistently generate, configure, build and link those, and related, packages. The `stdenv` derivation is a special derivation, defined in [Nixpkgs](https://github.com/NixOS/nixpkgs), and can be regarded as a kind of a pattern as well &mdash; see its reference: [The Standard Environment](https://nixos.org/manual/nixpkgs/stable/#chap-stdenv), on the [Nixpkgs Reference Manual](https://nixos.org/manual/nixpkgs/stable/). For an introduction to the `stdenv` as a pattern, see [19. Fundamentals of Stdenv](https://nixos.org/guides/nix-pills/19-fundamentals-of-stdenv.html), from the [Nix Pills](https://nixos.org/guides/nix-pills/) series.


### LLVM

The way LLVM is packaged in Nix is an example of this pattern. To integrate with the LLVM compiler infrastructure, there is a `pkgs.llvmPackages.libcxxStdenv` derivation &mdash; however this will not provide a _pure_ llvm `stdenv` in which all dependencies come from the LLVM project and none from GCC.[^4] A different approach would be something like this:

[embedmd]:# (./examples/llvm-flake-parts/flake.nix nix /.*stdenv = pkgs.overrideCC/ /.*pkgs.llvmPackages.clangUseLLVM/ dedent)
```nix
stdenv = pkgs.overrideCC
  (
    pkgs.llvmPackages.libcxxStdenv.override {
      targetPlatform.useLLVM = true;
      targetPlatform.linker = "lld";
    }
  )
  pkgs.llvmPackages.clangUseLLVM
```

[^4]: See [this question](https://discourse.nixos.org/t/how-to-create-a-working-llvm-based-stdenv-for-c-development/61581), or [this issue](https://github.com/NixOS/nixpkgs/issues/277564), for further details on how to create a LLVM-based `stdenv` for C++ development.

Therefore, conan-flake is parameterized by a [`stdenv`](https://flake.parts/options/conan-flake.html#opt-perSystem.conan.stdenv) option (defaulting to `pkgs.stdenv`), driving this complexity away from this module, which can then be regarded as its _interface_ with the compile infrastructure of the Nix system. It's used to extract mainly compiler related information and, together with the other options, compute the final configuration, which is exposed as a _devShell_ output. That _devShell_ can then be appended to an `inputsFrom` option for composition:

[embedmd]:# (./examples/llvm-flake-parts/flake.nix nix !/.*{ outputs/ !/.*outputs }/ s/#  // dedent)
```nix
# file: examples/llvm-flake-parts/flake.nix
{
  outputs = inputs@{ nixpkgs, flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = nixpkgs.lib.systems.flakeExposed;
      imports = [
        inputs.conan-flake.flakeModule
      ];
      perSystem = { pkgs, config, ... }:
      {
        conan = {
          profiles.default = {
            settings = {
              build_type = "Release";
              "compiler.cppstd" = "23";
            };
          };

          stdenv = pkgs.overrideCC
            (
              pkgs.llvmPackages.libcxxStdenv.override {
                targetPlatform.useLLVM = true;
                targetPlatform.linker = "lld";
              }
            )
            pkgs.llvmPackages.clangUseLLVM;
        };

        devShells.default = pkgs.mkShell {
          inputsFrom = [
            config.conan.outputs.devShell
          ];
        };
      };
    };
}
```

The above example is on the [examples/llvm-flake-parts](examples/llvm-flake-parts) directory:

```shell
cd examples/llvm-flake-parts
direnv allow .
```

By default, conan-flake sets the `compilerLibCxx` option to `"libstdc++11"`, which would result in the wrong choice for[ _compiler.libcxx_](https://docs.conan.io/2/reference/config_files/settings.html#c-standard-libraries-aka-compiler-libcxx):

```shell
conan profile show
```

To the `conan.profiles.default.settings.build_type` and `conan.profiles.default.settings."compiler.cppstd"` options correspond, respectivelly, the _build_type_ and _compiler.cppstd_ entries in the command output:

<!-- > $
echo '```text'
cd examples/llvm-flake-parts
nix develop --command bash -c "profile-show-wrapper 2>/dev/null"
echo '```'
-->

<!-- BEGIN mdsh -->
```text
Host profile:
[settings]
arch=x86_64
build_type=Release
compiler=clang
compiler.cppstd=23
compiler.libcxx=libc++
compiler.version=21.1.8
os=Linux
[platform_tool_requires]
cmake/4.3.4
[conf]
tools.build:compiler_executables={'c': '/nix/store/va889lnfilh11sjb1rcnrdvp813jpg03-clang-wrapper-21.1.8/bin/clang', 'cpp': '/nix/store/va889lnfilh11sjb1rcnrdvp813jpg03-clang-wrapper-21.1.8/bin/clang++'}

Build profile:
[settings]
arch=x86_64
build_type=Release
compiler=clang
compiler.cppstd=23
compiler.libcxx=libc++
compiler.version=21.1.8
os=Linux
[platform_tool_requires]
cmake/4.3.4
[conf]
tools.build:compiler_executables={'c': '/nix/store/va889lnfilh11sjb1rcnrdvp813jpg03-clang-wrapper-21.1.8/bin/clang', 'cpp': '/nix/store/va889lnfilh11sjb1rcnrdvp813jpg03-clang-wrapper-21.1.8/bin/clang++'}

```
<!-- END mdsh -->

The package defined in the the [examples/llvm-flake-parts/conanfile.py](examples/llvm-flake-parts/conanfile.py) recipe &mdash; _example/0.0.1_ &mdash; can be created in order to validate these settings:

```shell
conan create . --build=missing
```

Lines from its output correspond to entries from the Conan profile and, ultimately, to the conan-flake options:

```text
hello-conan: Hello World Release!
  hello-conan: __x86_64__ defined
  hello-conan: __cplusplus202302
  hello-conan: __GNUC__4
  hello-conan: __GNUC_MINOR__2
  hello-conan: __clang_major__21
  hello-conan: __clang_minor__1
example/0.0.1 test_package
```


### CUDA

The `pkgs.cudaPackages.backendStdenv` derivation helps integrate the [NVIDIA](https://www.nvidia.com/) and the host compilers while making it possible to link against the [CUDA](https://docs.nvidia.com/cuda/) libraries available in `pkgs.cudaPackages`.[^5]

[^5]: See [CUDA Modules](https://github.com/NixOS/nixpkgs/tree/nixos-unstable/pkgs/development/cuda-modules) for an overview on how CUDA packages are structured in Nixpkgs.

Nixpkgs parametrization can affect the compatibility and availability of CUDA packages:

[embedmd]:# (./examples/cuda-flake-parts/flake.nix nix /.*_module.args.pkgs =/ /.*# _module.args.pkgs/ dedent)
```nix
_module.args.pkgs = import inputs.nixpkgs {
  inherit system;
  config.allowUnfree = true;
  config.allowUnsupportedSystem = false;
  config.cudaForwardCompat = true;
  config.cudaSupport = true;
}; # _module.args.pkgs
```

The configuration can be done entirely with [`perSystem.conan`](https://flake.parts/options/conan-flake.html#opt-perSystem.conan) options:

[embedmd]:# (./examples/cuda-flake-parts/flake.nix nix !/.*{ conan/ /.*conan }/ dedent)
```nix
# file: examples/cuda-flake-parts/flake.nix
conan = {
  stdenv = pkgs.cudaPackages_13_2.backendStdenv;
  devShell = {
    tools = {
      inherit (pkgs.cudaPackages_13_2)
        cuda_nvcc
        cuda_cccl
        cuda_cudart
        cuda_nvrtc
        cuda_nvtx
        cuda_profiler_api
        cuda_cuxxfilt
        libcublas
        libnvfatbin
        libnvptxcompiler;
    };
    env = {
      LD_LIBRARY_PATH = "/usr/lib/wsl/lib";
      MESA_D3D12_DEFAULT_ADAPTER_NAME = "NVIDIA";
      GALLIUM_DRIVER = "d3d12";
    };
  };
  profiles.default = {
    settings = {
      build_type = "Release";
      "compiler.cppstd" = "20";
    };
    runEnv = [
      {
        name = "LD_LIBRARY_PATH";
        op = "+=(path)";
        value = "/usr/lib/wsl/lib";
      }
      {
        name = "MESA_D3D12_DEFAULT_ADAPTER_NAME";
        op = "=";
        value = "NVIDIA";
      }
      {
        name = "GALLIUM_DRIVER";
        op = "=";
        value = "d3d12";
      }
    ];
  };
  remotes.local = {
    url = "./repo";
    local = true;
    allowedPackages = [ "hello-world/0.0.1.cci.20260428" ];
  };
}; # conan }
```

The above example is on the [examples/cuda-flake-parts](examples/cuda-flake-parts) directory:

```shell
cd examples/cuda-flake-parts
direnv allow .
```

And it can be validated with a call to `conan create`:

```shell
conan create . --build=missing
```

Which returns the result of the program defined in the [src/modified_cuda_samples/matrixMulCUBLAS/matrixMulCUBLAS.cpp](examples/cuda-flake-parts/src/modified_cuda_samples/matrixMulCUBLAS/matrixMulCUBLAS.cpp) source file, on the [examples/cuda-flake-parts](examples/cuda-flake-parts) directory:[^6]

```text
[Matrix Multiply CUBLAS] - Starting...
Using CUDA device NVIDIA GeForce RTX 3060 Laptop GPU (having device ID 0)
GPU Device 0: "NVIDIA GeForce RTX 3060 Laptop GPU" with compute capability 8.6
MatrixA(640,480), MatrixB(480,320), MatrixC(640,320)
Computing result using CUBLAS... done.
Performance= 4266.67 GFlop/s, Time= 0.046 msec, Size= 196608000 Ops
Computing result using host CPU... done.
CUBLAS Matrix Multiply is close enough to CPU results: Yes
SUCCESS
```

[^6]: The source files [src/modified_cuda_samples/matrixMulCUBLAS/matrixMulCUBLAS.cpp](examples/cuda-flake-parts/src/modified_cuda_samples/matrixMulCUBLAS/matrixMulCUBLAS.cpp) and [src/common.hpp](examples/cuda-flake-parts/src/common.hpp) are taken from the examples of the [cuda-api-wrappers](https://github.com/eyalroz/cuda-api-wrappers) project &mdash; [examples/modified_cuda_samples/matrixMulCUBLAS/matrixMulCUBLAS.cpp](https://github.com/eyalroz/cuda-api-wrappers/blob/v0.8.2/examples/modified_cuda_samples/matrixMulCUBLAS/matrixMulCUBLAS.cpp) and [examples/common.hpp](https://github.com/eyalroz/cuda-api-wrappers/blob/v0.8.2/examples/common.hpp), respectively.


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

### C++ conan-flake, devenv-based project featuring a local-recipe-index remote

```shell
nix flake init -t "git+https://codeberg.org/tarcisio/conan-flake"#templates.devenv-module-recipe
```

### C++ conan-flake standalone Nix module project

```shell
nix flake init -t "git+https://codeberg.org/tarcisio/conan-flake"#templates.standalone
```

### C++ conan-flake, `flake-parts`-based project demonstrating CUDA integration

```shell
nix flake init -t "git+https://codeberg.org/tarcisio/conan-flake"#templates.cuda
```


## Contributing

To get started, clone this repository and allow `devenv` to set up the environment with the configuration from the `./dev` directory:

```sh
git clone ssh://git@codeberg.org/tarcisio/conan-flake.git
cd conan-flake
devenv --from path:dev allow
```

It will complain that `conan-flake` is not available:

```text
    error: To use 'conan', run the following command:

      $ devenv inputs add conan-flake git+https://codeberg.org/tarcisio/conan-flake
```

Add the `conan-flake` input pointing to the local checkout (the root of this repository) and activate `devenv` shell:

```sh
devenv inputs add conan-flake path:"$PWD"
devenv shell
```

Check that a default Conan profile was configured successfully:

```sh > text $
conan profile show
```

<!-- BEGIN mdsh -->
```text
Host profile:
[settings]
arch=x86_64
build_type=Release
compiler=gcc
compiler.cppstd=20
compiler.libcxx=libstdc++11
compiler.version=15.3.0
os=Linux
[platform_tool_requires]
cmake/4.3.4
[conf]


Build profile:
[settings]
arch=x86_64
build_type=Release
compiler=gcc
compiler.cppstd=20
compiler.libcxx=libstdc++11
compiler.version=15.3.0
os=Linux
[platform_tool_requires]
cmake/4.3.4
[conf]


```
<!-- END mdsh -->

To override

```sh
devenv inputs add conan-flake path:"$PWD"
devenv --secretspec-provider dotenv shell
```

## References

### Projects

This project is heavily based on [`haskell-flake`](https://github.com/srid/haskell-flake), from which it takes its overall structure.

It's also influenced, indebted by the following projects in a number of ways:

- [devenv](https://devenv.sh/) ([GitHub](https://github.com/cachix/devenv)):
  - Among other things, the way it handles the developer environment &mdash; see [devshell.nix](nix/modules/configuration/devshell.nix);
- [`treefmt-nix`](https://github.com/numtide/treefmt-nix):
  - Integration with the bare Nix module system &mdash; see [default.nix](nix/lib/default.nix).
- [`cuda-api-wrappers`](https://github.com/eyalroz/cuda-api-wrappers)
  - A CUDA example of matrix multiplication using _libcublas_: [src/modified_cuda_samples/matrixMulCUBLAS/matrixMulCUBLAS.cpp](examples/cuda-flake-parts/src/modified_cuda_samples/matrixMulCUBLAS/matrixMulCUBLAS.cpp)

It goes without saying that these proejects don't have anything to do with conan-flake &mdash; all wrong design decisions taken on the present scope are on our own account.


### Tutorials

A good overview of the Nix module system is on [nix.dev](https://nix.dev/):
- [Module system](https://nix.dev/tutorials/module-system/),

specially the second part:
- [Module system deep dive](https://nix.dev/tutorials/module-system/deep-dive).

As for the _standard environment_, it's worth emphasizing the already mentioned:
- [19. Fundamentals of Stdenv](https://nixos.org/guides/nix-pills/19-fundamentals-of-stdenv.html),


### Docs

A good source of information is [Nixpkgs Reference Manual](https://nixos.org/manual/nixpkgs/stable/):
- [The Standard Environment](https://nixos.org/manual/nixpkgs/stable/#chap-stdenv)
