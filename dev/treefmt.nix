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
    # `README.md` block. The committed `README.md` is the correct post-release
    # state, so `README.md` is excluded from this formatter — see
    # `settings.formatter.mdsh.excludes` below. Relying on people remembering to
    # type `treefmt --excludes README.md` is not enough: devenv runs a bare
    # `treefmt` as the `devenv:treefmt:run` task, which is ordered
    # `before = ["devenv:enterShell"]`, so it fires on *every* shell activation
    # (and `.envrc` activates the shell through direnv).
    #
    # Revert the exclude — i.e. let `mdsh` own `README.md` again — only once
    # BOTH of the following hold:
    #   1. the flattened profile-settings interface has been released on `main`,
    #      and
    #   2. the `examples/*` upstream pins have been bumped to that release
    #      (including the `fetchGit` rev in
    #      `examples/standalone-submodule-with/default.nix`).
    # Until then, regenerate the blocks deliberately with `mdsh` against a
    # checkout whose example pins match the local interface.
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

    # See the NOTE on `programs.mdsh.enable` above: regenerating the `README.md`
    # command-output blocks requires `examples/*` pins that carry the current
    # option interface, and stale pins make `mdsh` empty every block instead.
    mdsh = {
      excludes = [ "README.md" ];
    };
  };
}
