# LLVM

<!-- site.GUIDES.5 -->

The way LLVM is packaged in Nix is an example of the `stdenv` pattern
[described in the previous chapter](./toolchains.md). To integrate with the LLVM
compiler infrastructure, there is a `pkgs.llvmPackages.libcxxStdenv` derivation
&mdash; however this will not provide a _pure_ llvm `stdenv` in which all
dependencies come from the LLVM project and none from GCC.[^1] A different
approach would be something like this:

[embedmd]:# (./.examples/llvm-flake-parts/flake.nix nix /.*stdenv = pkgs.overrideCC/ /.*pkgs.llvmPackages.clangUseLLVM/ dedent)
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

[^1]: See
    [this question](https://discourse.nixos.org/t/how-to-create-a-working-llvm-based-stdenv-for-c-development/61581),
    or [this issue](https://github.com/NixOS/nixpkgs/issues/277564), for further
    details on how to create a LLVM-based `stdenv` for C++ development.

<!-- site.OPTIONS_REFERENCE.1 -->

That `stdenv` is what the
[`stdenv`](https://flake.parts/options/conan-flake.html#opt-perSystem.conan.stdenv)
option is given, and the _devShell_ conan-flake computes from it can then be
appended to an `inputsFrom` option for composition:

[embedmd]:# (./.examples/llvm-flake-parts/flake.nix nix !/.*{ outputs/ !/.*outputs }/ s/#  // dedent)
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

The above example is on the
[examples/llvm-flake-parts](https://codeberg.org/tarcisio/conan-flake/src/branch/main/examples/llvm-flake-parts)
directory:

```shell
cd examples/llvm-flake-parts
direnv allow .
```

By default, conan-flake sets `defaults.profiles.settings."compiler.libcxx"` to
`"libstdc++11"`, which would result in the wrong choice for
[_compiler.libcxx_](https://docs.conan.io/2/reference/config_files/settings.html#c-standard-libraries-aka-compiler-libcxx)
&mdash; with the LLVM `stdenv` above it is detected as `libc++` instead:

```shell
conan profile show
```

To the `conan.profiles.default.settings.build_type` and
`conan.profiles.default.settings."compiler.cppstd"` attributes correspond,
respectively, the _build_type_ and _compiler.cppstd_ entries in the command
output:

<!-- authoring.COMMAND_OUTPUT.1 -->

<!-- > $
echo '```text'
cd "$(git rev-parse --show-toplevel)/examples/llvm-flake-parts"
nix develop --command bash -c "profile-show-wrapper 2>/dev/null" | sed -E "s|/nix/store/[a-z0-9]{32}-([a-z-]+)-[0-9.]+|/nix/store/\1|g"
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
tools.build:compiler_executables={'c': '/nix/store/clang-wrapper/bin/clang', 'cpp': '/nix/store/clang-wrapper/bin/clang++'}

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
tools.build:compiler_executables={'c': '/nix/store/clang-wrapper/bin/clang', 'cpp': '/nix/store/clang-wrapper/bin/clang++'}

```
<!-- END mdsh -->

The package defined in the
[examples/llvm-flake-parts/conanfile.py](https://codeberg.org/tarcisio/conan-flake/src/branch/main/examples/llvm-flake-parts/conanfile.py)
recipe &mdash; _example/0.0.1_ &mdash; can be created in order to validate these
settings:

```shell
conan create . --build=missing
```

Lines from its output correspond to entries from the Conan profile and,
ultimately, to the conan-flake options:

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
