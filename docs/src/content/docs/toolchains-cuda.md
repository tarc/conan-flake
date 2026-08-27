---
title: CUDA
---

<!-- site.GUIDES.5 -->

The `pkgs.cudaPackages.backendStdenv` derivation helps integrate the
[NVIDIA](https://www.nvidia.com/) and the host compilers while making it
possible to link against the [CUDA](https://docs.nvidia.com/cuda/) libraries
available in `pkgs.cudaPackages`.[^1]

[^1]: See
    [CUDA Modules](https://github.com/NixOS/nixpkgs/tree/nixos-unstable/pkgs/development/cuda-modules)
    for an overview on how CUDA packages are structured in Nixpkgs.

Nixpkgs parametrization can affect the compatibility and availability of CUDA
packages:

[embedmd]:# (./.examples/cuda-flake-parts/flake.nix nix /.*_module.args.pkgs =/ /.*# _module.args.pkgs/ dedent)
```nix
_module.args.pkgs = import inputs.nixpkgs {
  inherit system;
  config.allowUnfree = true;
  config.allowUnsupportedSystem = false;
  config.cudaForwardCompat = true;
  config.cudaSupport = true;
}; # _module.args.pkgs
```

<!-- site.OPTIONS_REFERENCE.1 -->

The configuration can be done entirely with
[`perSystem.conan`](https://flake.parts/options/conan-flake.html#opt-perSystem.conan)
options:

[embedmd]:# (./.examples/cuda-flake-parts/flake.nix nix !/.*{ conan/ /.*conan }/ dedent)
```nix
# file: examples/cuda-flake-parts/flake.nix
conan = {
  stdenv = pkgs.cudaPackages_13_2.backendStdenv;
  devShell = {
    tools = {
      inherit (pkgs.cudaPackages_13_2)
        cuda_nvcc
        cuda_cccl
        cuda_cudart
        cuda_nvrtc
        cuda_nvtx
        cuda_profiler_api
        cuda_cuxxfilt
        libcublas
        libnvfatbin
        libnvptxcompiler;
    };
    env = {
      LD_LIBRARY_PATH = "/usr/lib/wsl/lib";
      MESA_D3D12_DEFAULT_ADAPTER_NAME = "NVIDIA";
      GALLIUM_DRIVER = "d3d12";
    };
  };
  profiles.default = {
    settings = {
      build_type = "Release";
      "compiler.cppstd" = "20";
    };
    runEnv = [
      {
        name = "LD_LIBRARY_PATH";
        op = "+=(path)";
        value = "/usr/lib/wsl/lib";
      }
      {
        name = "MESA_D3D12_DEFAULT_ADAPTER_NAME";
        op = "=";
        value = "NVIDIA";
      }
      {
        name = "GALLIUM_DRIVER";
        op = "=";
        value = "d3d12";
      }
    ];
  };
  remotes.local = {
    url = "./repo";
    local = true;
    allowedPackages = [ "hello-world/0.0.1.cci.20260428" ];
  };
}; # conan }
```

The above example is on the
[examples/cuda-flake-parts](https://codeberg.org/tarcisio/conan-flake/src/branch/main/examples/cuda-flake-parts)
directory:

```shell
cd examples/cuda-flake-parts
direnv allow .
```

And it can be validated with a call to `conan create`:

```shell
conan create . --build=missing
```

Which returns the result of the program defined in the
[src/modified_cuda_samples/matrixMulCUBLAS/matrixMulCUBLAS.cpp](https://codeberg.org/tarcisio/conan-flake/src/branch/main/examples/cuda-flake-parts/src/modified_cuda_samples/matrixMulCUBLAS/matrixMulCUBLAS.cpp)
source file, on the
[examples/cuda-flake-parts](https://codeberg.org/tarcisio/conan-flake/src/branch/main/examples/cuda-flake-parts)
directory:[^2]

```text
[Matrix Multiply CUBLAS] - Starting...
Using CUDA device NVIDIA GeForce RTX 3060 Laptop GPU (having device ID 0)
GPU Device 0: "NVIDIA GeForce RTX 3060 Laptop GPU" with compute capability 8.6
MatrixA(640,480), MatrixB(480,320), MatrixC(640,320)
Computing result using CUBLAS... done.
Performance= 4266.67 GFlop/s, Time= 0.046 msec, Size= 196608000 Ops
Computing result using host CPU... done.
CUBLAS Matrix Multiply is close enough to CPU results: Yes
SUCCESS
```

[^2]: The source files
    [src/modified_cuda_samples/matrixMulCUBLAS/matrixMulCUBLAS.cpp](https://codeberg.org/tarcisio/conan-flake/src/branch/main/examples/cuda-flake-parts/src/modified_cuda_samples/matrixMulCUBLAS/matrixMulCUBLAS.cpp)
    and
    [src/common.hpp](https://codeberg.org/tarcisio/conan-flake/src/branch/main/examples/cuda-flake-parts/src/common.hpp)
    are taken from the examples of the
    [cuda-api-wrappers](https://github.com/eyalroz/cuda-api-wrappers) project
    &mdash;
    [examples/modified_cuda_samples/matrixMulCUBLAS/matrixMulCUBLAS.cpp](https://github.com/eyalroz/cuda-api-wrappers/blob/v0.8.2/examples/modified_cuda_samples/matrixMulCUBLAS/matrixMulCUBLAS.cpp)
    and
    [examples/common.hpp](https://github.com/eyalroz/cuda-api-wrappers/blob/v0.8.2/examples/common.hpp),
    respectively.
