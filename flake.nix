{
  description = "A module to ease the integration of the Conan C/C++ package manager in the Nix ecosystem";
  nixConfig = {
    extra-substituters = "https://cache.nixos.asia/oss";
    extra-trusted-public-keys = "oss:KO872wNJkCDgmGN3xy9dT89WAhvv13EiKncTtHDItVU=";
  };
  outputs = inputs: {
    flakeModule = ./nix/modules/flake-module.nix;
    lib = (import ./nix/lib/lib.nix { inherit inputs; }).conanFlake;
    templates.default = {
      description = "A simple flake.nix using conan-flake as a flake-parts module";
      path = builtins.path {
        path = ./examples/flake-parts;
        filter =
          path: _:
          baseNameOf path == "flake.nix" || baseNameOf path == ".envrc" || baseNameOf path == ".gitignore";
      };
    };
    templates.example = {
      description = "Example C++ project using conan-flake as a flake-parts module";
      path = builtins.path { path = ./examples/flake-parts; };
    };
    templates.llvm = {
      description = "Example LLVM-based C++ project using conan-flake as a flake-parts module";
      path = builtins.path { path = ./examples/llvm-flake-parts; };
    };
    templates.devenv = {
      description = "Example C++ project using conan-flake as a flake-parts module in devenv";
      path = builtins.path { path = ./examples/devenv; };
    };
    templates.devenv-module = {
      description = "Example C++ project using conan-flake as a devenv module";
      path = builtins.path { path = ./examples/devenv-module; };
    };
    templates.devenv-module-recipe = {
      description = "Example C++ project using conan-flake as a devenv module and featuring a local-recipe-index remote";
      path = builtins.path { path = ./examples/devenv-module-recipe; };
    };
    templates.standalone = {
      description = "Example C++ project using conan-flake as a standalone Nix module";
      path = builtins.path { path = ./examples/standalone; };
    };
    templates.cuda = {
      description = "Example C++ project using conan-flake as a flake-parts module demonstrating CUDA integration";
      path = builtins.path { path = ./examples/cuda-flake-parts; };
    };
  };
}
