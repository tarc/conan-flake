---
title: conan-flake
---

<!-- site.ENTRY.1 -->

The conan-flake module bridges the gap between [Nix](https://nixos.org/) and
the [Conan C/C++ Package Manager](https://conan.io/), supporting a declarative
configuration style and common development workflows.

<!-- site.ENTRY.2 -->

For a user profile configuration like the following:

[embedmd]:# (./.examples/devenv-module/devenv.nix ini !/.*Profile properties:/ /cmake\/X\.Y\.Z/ s/# // dedent)
```ini
[settings]
build_type=Debug
compiler.cppstd=14

[platform_tool_requires]
cmake/X.Y.Z
```

There correspond the following options:

[embedmd]:# (./.examples/devenv-module/devenv.nix nix !/.*Corresponding options:/ !/# devShell/ dedent s/# {/{/ s/# }/}/)
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

The conan-flake module works with plain Nix (no flakes), Nix flakes,
[`flake-parts`](https://flake.parts/), or as a [devenv](https://devenv.sh/)
module.

## Where to go next

<!-- site.OPTIONS_REFERENCE.1 -->

- [Getting started](./getting-started.md) takes an empty directory to a working
  Conan configuration, using one of the [templates](./templates.md).
- [flake-parts](./flake-parts.md) covers the `flake-parts` integration.
- [devenv](./devenv.md) covers the devenv integration, both through devenv's own
  `languages.cplusplus.conan` option and with conan-flake used directly as a
  devenv module.
- [Standalone](./standalone.md) covers plain Nix usage, with and without flakes.
- [Toolchains](./toolchains.md) covers the LLVM/libc++ and CUDA scenarios.
- The [option reference](https://flake.parts/options/conan-flake.html) lists
  every option of the module, generated from the module itself, along with
  initial setup instructions for `flake-parts` scenarios.

<!-- site.ENTRY.3 -->

The source lives at
[codeberg.org/tarcisio/conan-flake](https://codeberg.org/tarcisio/conan-flake),
where issues and pull requests are welcome; see
[Contributing](./contributing.md) for the development environment, and the
[Changelog](./changelog.md) for the revision history.
