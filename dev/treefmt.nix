{ pkgs, ... }:
{
  settings = {
    excludes = [
      "*.toml"
      "build/*"
      "examples/cuda-flake-parts/flake.nix"
      "examples/devenv-module/devenv.nix"
      "examples/devenv-module-recipe/devenv.nix"
      "examples/flake-parts/flake.nix"
      "examples/llvm-flake-parts/flake.nix"
      "examples/simple-flake-parts/flake.nix"
      "examples/standalone-eval-conan-config/flake.nix"
      "examples/standalone-submodule-with/flake.nix"
      "nix/packages/*"
    ];
  };

  programs = {
    cmake-format.enable = true;
    deadnix.enable = true;
    deno.enable = pkgs.stdenv.hostPlatform.system != "riscv64-linux";
    mdsh.enable = true;
    nixfmt.enable = true;
    shellcheck.enable = pkgs.stdenv.hostPlatform.system != "riscv64-linux";
    shfmt.enable = pkgs.stdenv.hostPlatform.system != "riscv64-linux";
    yamlfmt.enable = true;
  };

  settings.formatter = {
    deno = {
      excludes = [ "README.md" ];
    };

    embedmd = {
      command = "${pkgs.embedmd}/bin/embedmd";
      includes = [ "README.md" ];
    };
  };
}
