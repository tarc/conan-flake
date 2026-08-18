# submoduleWith

<!-- site.GUIDES.4 -->

This example can be found in the
[examples/standalone-submodule-with](https://codeberg.org/tarcisio/conan-flake/src/branch/main/examples/standalone-submodule-with)
directory:

```shell
cd examples/standalone-submodule-with
```

Where the actual `perSystem` function is used to configure a Debug, C++14
profile:

[embedmd]:# (./.examples/standalone-submodule-with/flake.nix nix !/.*{ perSystem/ !/.*perSystem }/ s/#  // dedent)
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

Differently from the example in the
[previous chapter](./standalone-eval-conan-config.md), here the options are
loaded apart:

[embedmd]:# (./.examples/standalone-submodule-with/flake.nix nix /.*conanSubmodule =/ /.*conanSubmodule =.*/ dedent)
```nix
conanSubmodule = conan-flake.lib.submoduleWith lib {
```

And integrated as a submodule of a larger configuration:

[embedmd]:# (./.examples/standalone-submodule-with/flake.nix nix /.*conanModule =/ /.*# conanModule/ dedent)
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

[embedmd]:# (./.examples/standalone-submodule-with/flake.nix nix /.*conanModuleConfig =/ /.*# conanModuleConfig/ dedent)
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

Apart from that, all the other commands and considerations from the
[previous chapter](./standalone-eval-conan-config.md) also apply here.[^1]

[^1]: The definitions of the two methods: `conan-flake.lib.evalConanConfig` and
    `conan-flake.lib.submoduleWith` try to mimic `treefmt-nix`'s related design.
    Cf. their
    [`default.nix`](https://github.com/numtide/treefmt-nix/blob/main/default.nix)
    to compare definitions.

## Without flakes

To make this difference clearer, the
[standalone-submodule-with/default.nix](https://codeberg.org/tarcisio/conan-flake/src/branch/main/examples/standalone-submodule-with/default.nix)
file defines and configures a `conan` option using only a fetched conan-flake
module:

[embedmd]:# (./.examples/standalone-submodule-with/default.nix nix)
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
      rev = "55a3e4025974d01980f637e37e636d7a43a22a91";
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

To validate this setup, the
[standalone-submodule-with/eval.nix](https://codeberg.org/tarcisio/conan-flake/src/branch/main/examples/standalone-submodule-with/eval.nix)
file can be used to evaluate the previous definitions:

[embedmd]:# (./.examples/standalone-submodule-with/eval.nix nix)
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

To put these together, the following command instantiate the Nix files and print
the resulting expression at a given attribute path:

```shell
nix-instantiate --eval eval.nix -A config.conan.profiles.default.text.text
```

The retuned value is that of the resulting default profile:

<!-- authoring.COMMAND_OUTPUT.1 -->

<!-- > $
echo '```text'
cd "$(git rev-parse --show-toplevel)/examples/standalone-submodule-with"
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

<!-- authoring.COMMAND_OUTPUT.1 -->

<!-- > $
echo '```text'
cd "$(git rev-parse --show-toplevel)/examples/standalone-submodule-with"
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
