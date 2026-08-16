# References

<!-- site.GUIDES.8 -->

## Projects

This project is heavily based on
[`haskell-flake`](https://github.com/srid/haskell-flake), from which it takes
its overall structure.

It's also influenced, indebted by the following projects in a number of ways:

- [devenv](https://devenv.sh/) ([GitHub](https://github.com/cachix/devenv)):
  - Among other things, the way it handles the developer environment &mdash; see
    [devshell.nix](https://codeberg.org/tarcisio/conan-flake/src/branch/main/nix/modules/configuration/devshell.nix);
- [`treefmt-nix`](https://github.com/numtide/treefmt-nix):
  - Integration with the bare Nix module system &mdash; see
    [default.nix](https://codeberg.org/tarcisio/conan-flake/src/branch/main/nix/lib/default.nix).
- [`cuda-api-wrappers`](https://github.com/eyalroz/cuda-api-wrappers)
  - A CUDA example of matrix multiplication using _libcublas_:
    [src/modified_cuda_samples/matrixMulCUBLAS/matrixMulCUBLAS.cpp](https://codeberg.org/tarcisio/conan-flake/src/branch/main/examples/cuda-flake-parts/src/modified_cuda_samples/matrixMulCUBLAS/matrixMulCUBLAS.cpp)

It goes without saying that these proejects don't have anything to do with
conan-flake &mdash; all wrong design decisions taken on the present scope are on
our own account.

## Tutorials

A good overview of the Nix module system is on [nix.dev](https://nix.dev/):

- [Module system](https://nix.dev/tutorials/module-system/),

specially the second part:

- [Module system deep dive](https://nix.dev/tutorials/module-system/deep-dive).

As for the _standard environment_, it's worth emphasizing the already mentioned:

- [19. Fundamentals of Stdenv](https://nixos.org/guides/nix-pills/19-fundamentals-of-stdenv.html),

## Docs

A good source of information is
[Nixpkgs Reference Manual](https://nixos.org/manual/nixpkgs/stable/):

- [The Standard Environment](https://nixos.org/manual/nixpkgs/stable/#chap-stdenv)

The conan-flake options themselves are published, generated from the module, at
the [conan-flake option reference](https://flake.parts/options/conan-flake.html)
&mdash; see also the [Conan documentation](https://docs.conan.io/2/) for the
configuration files those options render.
