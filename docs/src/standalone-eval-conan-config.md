# evalConanConfig

<!-- site.GUIDES.4 -->

This example can be found in the
[standalone-eval-conan-config](https://codeberg.org/tarcisio/conan-flake/src/branch/main/examples/standalone-eval-conan-config)
directory:

```shell
cd examples/standalone-eval-conan-config
```

Where the actual `perSystem` function &mdash; the one left out of the
[schema](./standalone.md) of the previous chapter &mdash; is used to configure a
Release, C++17 profile:

[embedmd]:# (./.examples/standalone-eval-conan-config/flake.nix nix !/.*{ perSystem/ !/.*perSystem }/ s/#  // dedent)
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

This configuration now can be used to set a developer environment with
[`direnv`](https://direnv.net/):

```shell
direnv allow .
```

But even a plain `nix develop` would suffice:

```shell
nix develop .
```

From within this shell, the following command can be used to obtain the
resulting profile:

```shell
conan profile show
```

To the `profiles.default.settings.build_type` and
`profiles.default.settings."compiler.cppstd"` attributes correspond,
respectively, the _build_type_ and _compiler.cppstd_ entries in its output:

<!-- authoring.COMMAND_OUTPUT.1 -->

<!-- > $
echo '```text'
cd "$(git rev-parse --show-toplevel)/examples/standalone-eval-conan-config"
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

In the
[standalone-eval-conan-config](https://codeberg.org/tarcisio/conan-flake/src/branch/main/examples/standalone-eval-conan-config)
directory, the
[conanfile.py](https://codeberg.org/tarcisio/conan-flake/src/branch/main/examples/standalone-eval-conan-config/conanfile.py)
recipe file defines a C++ package &mdash; _example/0.0.1_ &mdash; it's possible
to call `conan create` on it, and export this package into the local Conan
cache:

```shell
conan create . --build=missing
```

The above command is going to install the dependencies and then build the
_example/0.0.1_ package. Then export it to the local Conan cache and test it
afterwards against
[standalone-eval-conan-config/test_package](https://codeberg.org/tarcisio/conan-flake/src/branch/main/examples/standalone-eval-conan-config/test_package).
If everything goes well, the last lines from the previous command would be the
test package's output:

```text
hello-world: Hello World Release!
  hello-world: __x86_64__ defined
  hello-world: _GLIBCXX_USE_CXX11_ABI 1
  hello-world: __cplusplus201703
  hello-world: __GNUC__15
  hello-world: __GNUC_MINOR__2
example/0.0.1 test_package
```

There's also a _check_ `example` function defined along with each `default`
_devShell_:

[embedmd]:# (./.examples/standalone-eval-conan-config/flake.nix nix /.*checks.example/ /.*# checks.example/ dedent)
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

```shell
nix flake check .
```
