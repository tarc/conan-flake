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
      "features/*"
    ];
  };

  programs = {
    cmake-format.enable = true;
    deadnix.enable = true;
    deno.enable = pkgs.stdenv.hostPlatform.system != "riscv64-linux";
    # NOTE: `mdsh` regenerates the `README.md` command-output blocks by running
    # the `examples/*` projects, which resolve `conan-flake` from the *published*
    # upstream (there is no `flake.lock` under `examples/`, and
    # `examples/standalone-submodule-with/default.nix` pins a `fetchGit` rev
    # that is bumped by each `Release x.y.z` commit). Whenever the option
    # interface changes in a breaking way, those pins still carry the previous
    # interface, so the examples fail to evaluate and `mdsh` empties every
    # `README.md` block. Until such a change lands on `main` and the pins are
    # bumped, do not run `treefmt`/`mdsh` against `README.md` (`treefmt
    # --excludes README.md`); the committed `README.md` is the correct
    # post-release state.
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
