# file: examples/cuda-flake-parts/flake.nix
{
  inputs = {
    nixpkgs.url = "github:cachix/devenv-nixpkgs/rolling";
    flake-parts.url = "github:hercules-ci/flake-parts";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    conan-flake.url = "git+https://codeberg.org/tarcisio/conan-flake";
    infuse = {
      url = "git+https://codeberg.org/amjoseph/infuse.nix?rev=e837ece1b9de6ebcb7abd261f54a09bad3a2f820";
      flake = false;
    };
  };
  # { outputs
  # file: examples/cuda-flake-parts/flake.nix
  #  {
    # ...
    outputs = inputs@{ self, nixpkgs, flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = nixpkgs.lib.systems.flakeExposed;
      imports = [
        inputs.conan-flake.flakeModule
      ];
      perSystem = { self', pkgs, config, system, ... }: {
        _module.args.pkgs = import inputs.nixpkgs {
          inherit system;
          config.allowUnfree = true;
          config.allowUnsupportedSystem = false;
          config.cudaForwardCompat = true;
          config.cudaSupport = true;
        }; # _module.args.pkgs

        # { conan
        # file: examples/cuda-flake-parts/flake.nix
        conan = {
          buildType = "Release";
          compilerCppStd = "20";
          stdenv = pkgs.cudaPackages_13_2.backendStdenv;
          platformToolRequires = {
            cmake = pkgs.cmake.version;
          };
          devShell = {
            tools = {
              inherit (pkgs) cmake;
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
          remotes.local = {
            url = "./repo";
            local = true;
            allowedPackages = [ "hello-world/0.0.1.cci.20260428" ];
          };
        }; # conan }

        devShells.default = pkgs.mkShell {
          inputsFrom = [
            config.conan.outputs.devShell
          ];
        };

        checks.test = pkgs.runCommandWith
          {
            name = "cuda-flake-parts-test-conan-create";
            inherit (config.conan) stdenv;
            derivationArgs = { inherit (config.conan.outputs.devShell) buildInputs nativeBuildInputs; };
          }
          ''
            (
            set -x
            ${config.conan.outputs.devShell.shellHook}
            conan create ${config.conan.info.configRoot} -tf="" --build=missing 2>&1 | grep "example/0.0.1"
            touch $out
            )
          '';
      };
    };
  #  }
  # outputs }
}
