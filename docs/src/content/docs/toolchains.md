---
title: Toolchains
---

<!-- site.GUIDES.5 -->

A common way to support C and C++ packages in [Nix](https://nixos.org/) is to
integrate their build system and expose a specialized `stdenv` derivation
responsible to bring in all of the necessary tools required to consistently
generate, configure, build and link those, and related, packages. The `stdenv`
derivation is a special derivation, defined in
[Nixpkgs](https://github.com/NixOS/nixpkgs), and can be regarded as a kind of a
pattern as well &mdash; see its reference:
[The Standard Environment](https://nixos.org/manual/nixpkgs/stable/#chap-stdenv),
on the
[Nixpkgs Reference Manual](https://nixos.org/manual/nixpkgs/stable/). For an
introduction to the `stdenv` as a pattern, see
[19. Fundamentals of Stdenv](https://nixos.org/guides/nix-pills/19-fundamentals-of-stdenv.html),
from the [Nix Pills](https://nixos.org/guides/nix-pills/) series.

<!-- site.OPTIONS_REFERENCE.1 -->

conan-flake is parameterized by a
[`stdenv`](https://flake.parts/options/conan-flake.html#opt-perSystem.conan.stdenv)
option (defaulting to `pkgs.stdenv`), driving this complexity away from this
module, which can then be regarded as its _interface_ with the compile
infrastructure of the Nix system. It's used to extract mainly compiler related
information and, together with the other options, compute the final
configuration, which is exposed as a _devShell_ output.

The two scenarios this project demonstrates are:

- [LLVM](./toolchains-llvm.md) &mdash; a `stdenv` in which all dependencies come
  from the LLVM project, and the `compiler.libcxx` setting that goes with it.
- [CUDA](./toolchains-cuda.md) &mdash; the
  [NVIDIA](https://www.nvidia.com/) toolchain, linking against the CUDA
  libraries available in `pkgs.cudaPackages`.
