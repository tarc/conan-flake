---
title: Getting started
---

<!-- site.GUIDES.1 -->

Every example of this site is a runnable project, collected under
[examples](https://codeberg.org/tarcisio/conan-flake/src/branch/main/examples)
in the source repository, and each one is also exposed as a flake
[template](./templates.md). The quickest way from an empty directory to a
working Conan configuration is to instantiate one of them:

```shell
mkdir -p hello-conan && cd hello-conan
git init
nix flake init -t "git+https://codeberg.org/tarcisio/conan-flake"#templates.devenv-module-recipe
```

That template is the [devenv](./devenv.md) example featuring a
_local-recipe-index_ remote; it carries a complete C++ project — a
`conanfile.py` recipe, its sources and a test package — alongside the Conan
configuration itself, which is the `devenv.nix` shown in the
[devenv](./devenv.md) chapter.

The shell can be activated with [`direnv`](https://direnv.net/):

```shell
direnv allow .
```

It can take a while before completing. After that, the `conan` command is
available in the path, with the profile and the other Conan settings already in
place, so the Conan package defined by the recipe can be built and tested with a
call to `conan create`:

```shell
conan create . --build=missing
```

Whose output can be used to validate if the configuration was applied
successfully:

```text
hello-world: Hello World Release!
  hello-world: __x86_64__ defined
  hello-world: _GLIBCXX_USE_CXX11_ABI 1
  hello-world: __cplusplus201703
  hello-world: __GNUC__15
  hello-world: __GNUC_MINOR__2
example/0.0.1 test_package
```

:::caution[Warning]
Depending when this page is being accessed, the devenv integration may still
be pending approval upstream. The devenv samples here can still be tested
nonetheless, by overriding _devenv itself_ with the version from our
[upstream PR](https://github.com/cachix/devenv/pull/2787). See
[examples/devenv-module-recipe](https://codeberg.org/tarcisio/conan-flake/src/branch/main/examples/devenv-module-recipe)
and
[devenv.yaml](https://codeberg.org/tarcisio/conan-flake/src/branch/main/examples/devenv-module-recipe/devenv.yaml)
therein for more details. The [flake-parts](./flake-parts.md) and
[standalone](./standalone.md) templates are unaffected.
:::

## Working from a clone

It's also possible to interact directly with the example projects from a clone
of this repository:[^1]

```shell
git clone ssh://git@codeberg.org/tarcisio/conan-flake.git
cd conan-flake
```

[^1]: Or, via _https_:

    ```shell
    git clone https://codeberg.org/tarcisio/conan-flake.git
    cd conan-flake
    ```

The example above is on the
[examples/devenv-module-recipe](https://codeberg.org/tarcisio/conan-flake/src/branch/main/examples/devenv-module-recipe)
directory:

```shell
cd examples/devenv-module-recipe
direnv allow .
```

And the same `conan create` call applies from there.

## Where to go next

<!-- site.OPTIONS_REFERENCE.1 -->

- The [option reference](https://flake.parts/options/conan-flake.html) lists
  every option of the module, and carries the initial setup instructions for
  `flake-parts` scenarios.
- The [templates](./templates.md) chapter lists the remaining templates, one per
  integration style.
- The [flake-parts](./flake-parts.md), [devenv](./devenv.md) and
  [standalone](./standalone.md) chapters walk through each of those styles.
