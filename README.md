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

**[Documentation](https://tarcisio.codeberg.page/conan-flake/)** &middot;
[Option reference](https://flake.parts/options/conan-flake.html) &middot;
[Changelog](https://tarcisio.codeberg.page/conan-flake/changelog.html)

</div>

<!-- What conan-flake is, one configuration example, and how to instantiate it:
     everything else lives on the documentation site linked below.

     readme.SCOPE.1 -->

The conan-flake module bridges the gap between [Nix](https://nixos.org/) and the
[Conan C/C++ Package Manager](https://conan.io/), supporting a declarative
configuration style and common development workflows. Conan profiles, remotes
and tool requirements are declared as Nix options, and the Conan configuration
files, the wrapper commands and the development shell are generated from them.

The module works with plain Nix (no flakes), Nix flakes,
[`flake-parts`](https://flake.parts/), or as a [devenv](https://devenv.sh/)
module.

A configuration declaring a `Debug` profile, the C++ standard to compile
against, and a `cmake` taken from Nix instead of built by Conan looks like this:

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

From it, conan-flake renders the matching Conan profile — its `[settings]` and
`[platform_tool_requires]` sections — and puts `cmake` on the `PATH` of the
development shell, so that Conan resolves the tool from the environment instead
of building it. The [entry page](https://tarcisio.codeberg.page/conan-flake/) of
the documentation site shows the rendered profile next to these options.

## Getting started

Instantiate one of the
[templates](https://tarcisio.codeberg.page/conan-flake/templates.html) into an
empty directory:

```shell
nix flake init -t "git+https://codeberg.org/tarcisio/conan-flake"#templates.devenv-module-recipe
```

The
[getting started](https://tarcisio.codeberg.page/conan-flake/getting-started.html)
chapter takes that directory to a Conan package built with the generated
configuration, and the other chapters cover the remaining ways of consuming the
module.

## Documentation

<!-- Every topic this file no longer covers, with the chapter of the site that
     covers it now.

     readme.SCOPE.2
     readme.SCOPE.3 -->

The documentation site is at <https://tarcisio.codeberg.page/conan-flake/>:

- [Getting started](https://tarcisio.codeberg.page/conan-flake/getting-started.html)
  — from an empty directory to a working Conan configuration, and the example
  projects this repository ships.
- [flake-parts](https://tarcisio.codeberg.page/conan-flake/flake-parts.html) —
  the `flake-parts` integration: the flake inputs, the `perSystem.conan`
  options, and composing the generated development shell.
- [devenv](https://tarcisio.codeberg.page/conan-flake/devenv.html) — the devenv
  integration, through devenv's own `languages.cplusplus.conan` option and with
  conan-flake used directly as a devenv module.
- [Standalone](https://tarcisio.codeberg.page/conan-flake/standalone.html) —
  plain Nix usage, with and without flakes.
  - [evalConanConfig](https://tarcisio.codeberg.page/conan-flake/standalone-eval-conan-config.html)
    — evaluating a configuration directly.
  - [submoduleWith](https://tarcisio.codeberg.page/conan-flake/standalone-submodule-with.html)
    — embedding conan-flake in a larger option tree.
- [Toolchains](https://tarcisio.codeberg.page/conan-flake/toolchains.html) —
  configuring the compiler and the standard library conan-flake reports to
  Conan.
  - [LLVM](https://tarcisio.codeberg.page/conan-flake/toolchains-llvm.html) —
    clang with libc++.
  - [CUDA](https://tarcisio.codeberg.page/conan-flake/toolchains-cuda.html) —
    the CUDA toolkit and its host compiler.
- [Templates](https://tarcisio.codeberg.page/conan-flake/templates.html) — every
  template of this flake and the command that instantiates it.
- [Contributing](https://tarcisio.codeberg.page/conan-flake/contributing.html) —
  the development environment, the checks, and the generated blocks.
- [References](https://tarcisio.codeberg.page/conan-flake/references.html) — the
  projects, tutorials and manuals this one builds on.
- [Changelog](https://tarcisio.codeberg.page/conan-flake/changelog.html) — the
  revision history.

The [option reference](https://flake.parts/options/conan-flake.html) lists every
option of the module, generated from the module itself, along with initial setup
instructions for `flake-parts` scenarios.

Issues and pull requests are welcome at
[codeberg.org/tarcisio/conan-flake](https://codeberg.org/tarcisio/conan-flake).

## License

conan-flake is distributed under the terms of the MIT license — see
[LICENSE](LICENSE).
