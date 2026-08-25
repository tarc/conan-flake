# flake-parts

<!-- site.GUIDES.2 -->

The `flake-parts` integration requires conan-flake and
[`infuse`](https://codeberg.org/amjoseph/infuse.nix) to be added to the flake
inputs:

[embedmd]:# (./.examples/flake-parts/flake.nix nix !/.*{ inputs/ !/.*inputs }/ s/#  // dedent)
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

After importing `inputs.conan-flake.flakeModule`, it's possible to use the
options from
[`perSystem.conan`](https://flake.parts/options/conan-flake.html#opt-perSystem.conan)
to configure a suitable Conan profile:

[embedmd]:# (./.examples/flake-parts/flake.nix nix !/.*{ outputs/ !/.*outputs }/ s/#  // dedent)
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

The example above can be found in the
[examples/flake-parts](https://codeberg.org/tarcisio/conan-flake/src/branch/main/examples/flake-parts)
directory:

```shell
cd examples/flake-parts
direnv allow .
```

It can take a while before completing. After that, the `conan` command should be
available in the path, and the required profile and other Conan settings already
in place:

```shell
conan profile show
```

A Release, C++23 profile is expected:

<!-- authoring.COMMAND_OUTPUT.1 -->

<!-- > $
echo '```text'
cd "$(git rev-parse --show-toplevel)/examples/flake-parts"
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
> By default, conan-flake sets both CMake and the configured `stdenv.cc`
> compiler as
> [`devShell.tools`](https://flake.parts/options/conan-flake.html#opt-perSystem.conan.devShell.tools).
> Also, whatever CMake version, if any, ends up being in the `devShell.tools` is
> also set, by default, as a `platformToolRequires` entry of every
> [`profiles.<name>`](https://flake.parts/options/conan-flake.html#opt-perSystem.conan.profiles)
> (a section of the profile itself, not a sub-option of its own: `profiles` has
> no discoverable sub-options, so its reference entry demonstrates every
> section, `platformToolRequires` included, directly).

The resulting default _devShell_ defined above is a composition &mdash; it
merges `config.conan.outputs.devShell` and `config.treefmt.build.devShell`, and
appends `pkgs.just` to the resulting _devShell_'s package list for its _own
sake_:

[embedmd]:# (./.examples/flake-parts/flake.nix nix /.*devShells.default/ /.*}; # devShells/ dedent)
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

A possible sanity check could be to find the corresponding commands available in
the path:

```shell
cmake --version
conan --version
treefmt --version
echo
just --version
```

Also, CMake's version should match the one listed in the
_[platform_tool_requires]_ section of the `conan profile show` command's output
above:

<!-- authoring.COMMAND_OUTPUT.1 -->

<!-- > $
echo '```text'
cd "$(git rev-parse --show-toplevel)/examples/flake-parts"
nix develop --command bash -c "cmake --version && conan --version && treefmt --version && echo"
echo '```'
-->

<!-- BEGIN mdsh -->
```text
cmake version 4.3.4

CMake suite maintained and supported by Kitware (kitware.com/cmake).
Conan version 2.32.0-dev
treefmt v2.5.0
```
<!-- END mdsh -->

<!-- site.OPTIONS_REFERENCE.1 -->

The complete list of the options available under `perSystem.conan`, along with
the initial setup instructions for `flake-parts` scenarios, is in the
[option reference](https://flake.parts/options/conan-flake.html).
