{
  description = "A module to ease the integration of the Conan C/C++ package manager in the Nix ecosystem";

  outputs = inputs: {
    flakeModule = ./nix/modules/flake-module.nix;
    lib = import ./nix/lib.nix;

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
      description = "Example C++ project using conan-flake as a devenv module";
      path = builtins.path { path = ./examples/devenv; };
    };
    templates.standalone = {
      description = "Example C++ project using conan-flake as a standalone Nix module";
      path = builtins.path { path = ./examples/standalone; };
    };

  };
}
