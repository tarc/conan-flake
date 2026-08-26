---
title: devenv
---

<!-- site.GUIDES.3 -->

There are two ways of using conan-flake with [devenv](https://devenv.sh/): the
`languages.cplusplus.conan` option, which devenv itself provides and which
carries conan-flake's own options under `languages.cplusplus.conan.config`, and
a devenv shell that takes conan-flake's computed _devShell_ directly.

## The `languages.cplusplus.conan` option

Configure Conan in any devenv shell with the
[supported integration](https://devenv.sh/reference/options/#languagescplusplusconanenable):

[embedmd]:# (./.examples/devenv-module-recipe/devenv.nix nix !/.*{ languages.cplusplus/ /# languages.cplusplus/ dedent)
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

:::note[Note]
See [how to setup Conan](https://devenv.sh/languages/cplusplus/#setting-up-the-conan-package-manager)
in devenv for further details. As can be seen from the above example, the
devenv integration automatically takes care of the CMake part by default, so
neither `devShell.tools` nor `platformToolRequires` (a section of every
`profiles.<name>`, not an option of its own) needs to be set explicitly in
the `languages.cplusplus.conan.config` namespace.
:::

:::caution[Warning]
Depending when this page is being accessed, the devenv integration may still
be pending approval upstream and the above links to the devenv docs may be
missing. The devenv samples here can still be tested nonetheless, by
overriding _devenv itself_ with the version from our
[upstream PR](https://github.com/cachix/devenv/pull/2787). See
[examples/devenv-module-recipe](https://codeberg.org/tarcisio/conan-flake/src/branch/main/examples/devenv-module-recipe)
and
[devenv.yaml](https://codeberg.org/tarcisio/conan-flake/src/branch/main/examples/devenv-module-recipe/devenv.yaml)
therein for more details.
:::

The example above is on the
[examples/devenv-module-recipe](https://codeberg.org/tarcisio/conan-flake/src/branch/main/examples/devenv-module-recipe)
directory, and the [Getting started](./getting-started.md) chapter walks through
it. A variant without the _local-recipe-index_ remote is on
[examples/devenv-module](https://codeberg.org/tarcisio/conan-flake/src/branch/main/examples/devenv-module);
its profile settings, and the Conan profile they produce, are the pair shown on
[the front page](./index.md).

## A devenv shell taking conan-flake's _devShell_

Where devenv shells are declared through
[`flake-parts`](./flake-parts.md), conan-flake can be used without the
`languages.cplusplus` option at all: importing `inputs.conan-flake.flakeModule`
next to `inputs.devenv.flakeModule` makes `config.conan.outputs.devShell`
available, which composes into a devenv shell the same way it composes into a
`pkgs.mkShell`:

[embedmd]:# (./.examples/devenv/flake.nix nix /.*devenv = {/ /.*}; # devenv/ dedent)
```nix
devenv = {
  shells.default = {
    name = "conan-flake-dev";

    inputsFrom = [
      # conan-flake exposes a `configuration` devShell by default that
      # can be used directly, or passed in the inputsFrom option as a
      # means to compose with other devShell modules.
      config.conan.outputs.devShell
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
}; # devenv
```

That example is on the
[examples/devenv](https://codeberg.org/tarcisio/conan-flake/src/branch/main/examples/devenv)
directory, whose Conan configuration is written with the same
[`perSystem.conan`](https://flake.parts/options/conan-flake.html#opt-perSystem.conan)
options the [flake-parts](./flake-parts.md) chapter describes:

```shell
cd examples/devenv
direnv allow .
```

<!-- site.OPTIONS_REFERENCE.1 -->

Either way, the options being set are conan-flake's own, and the complete list
of them is in the
[option reference](https://flake.parts/options/conan-flake.html) &mdash; under
`perSystem.conan` for the `flake-parts` spelling, and under
`languages.cplusplus.conan.config` for the devenv one.
