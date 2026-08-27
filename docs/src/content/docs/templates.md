---
title: Templates
---

<!-- site.GUIDES.6 -->

Every example of this project is also a flake template, so each one can be
instantiated into an empty directory with `nix flake init`. The
[Getting started](./getting-started.md) chapter walks through the first steps
with one of them.

## Simple conan-flake project with only a `flake-parts`-based configuration

This template will get you only the `flake.nix`, `.envrc` and `.gitignore`
files.

```shell
mkdir -p default && cd default
nix flake init -t "git+https://codeberg.org/tarcisio/conan-flake"
```

## C++ conan-flake, `flake-parts`-based project

Alongside the files from the previous item, this template will provide you also
with a complete sample Conan-based C++ project.

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

The remaining templates in this chapter can be initialized and validated in a
similar manner.

## LLVM-based C++ conan-flake project

This template is also `flake-parts`-based; see the
[LLVM](./toolchains-llvm.md) chapter.

```shell
nix flake init -t "git+https://codeberg.org/tarcisio/conan-flake"#templates.llvm
```

## C++ conan-flake, "devenv with `flake-parts`"-based project

```shell
nix flake init -t "git+https://codeberg.org/tarcisio/conan-flake"#templates.devenv
```

## C++ conan-flake, devenv-based project

```shell
nix flake init -t "git+https://codeberg.org/tarcisio/conan-flake"#templates.devenv-module
```

## C++ conan-flake, devenv-based project featuring a local-recipe-index remote

```shell
nix flake init -t "git+https://codeberg.org/tarcisio/conan-flake"#templates.devenv-module-recipe
```

## C++ conan-flake standalone Nix module project

See the [Standalone](./standalone.md) chapter.

```shell
nix flake init -t "git+https://codeberg.org/tarcisio/conan-flake"#templates.standalone
```

## C++ conan-flake, `flake-parts`-based project demonstrating CUDA integration

See the [CUDA](./toolchains-cuda.md) chapter.

```shell
nix flake init -t "git+https://codeberg.org/tarcisio/conan-flake"#templates.cuda
```
