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
    # upstream rather than from this checkout: there is no *committed*
    # `flake.lock` under `examples/` (`examples/.gitignore` ignores them, so the
    # ones that exist locally are stale, uncommitted and never bumped by a
    # release), and the one explicit rev pin left — the `fetchGit` rev in
    # `examples/standalone-submodule-with/default.nix`, which pins by rev
    # because that example illustrates the no-flakes path, where no lockfile
    # exists to do it — is only bumped by each `Release x.y.z` commit. The
    # other examples name the branch and so follow each release on their own. Whenever the option interface changes in a
    # breaking way, those pins still carry the previous interface, so the
    # examples fail to evaluate and `mdsh` empties every `README.md` block. The
    # committed `README.md` is the correct post-release state, so `README.md` is
    # excluded from this formatter — see `settings.formatter.mdsh.excludes`
    # below. Relying on people remembering to type
    # `treefmt --excludes README.md` is not enough: devenv runs a bare `treefmt`
    # as the `devenv:treefmt:run` task, which is ordered
    # `before = ["devenv:enterShell"]`, so it fires on *every* shell activation
    # (and `.envrc` activates the shell through direnv).
    #
    # `treefmt-nix` only ever points `mdsh` at `README.md`
    # (`includes = ["README.md"]`), so excluding `README.md` makes the formatter
    # match zero files: this disables `mdsh` entirely for `treefmt` runs until
    # the pins are bumped. It is left `enable = true` so the command stays wired
    # and the revert is a one-line change.
    #
    # Revert the exclude — i.e. let `mdsh` own `README.md` again — only once
    # BOTH of the following hold:
    #   1. the flattened profile-settings interface has been released on `main`,
    #      and
    #   2. the `fetchGit` rev in `examples/standalone-submodule-with/default.nix`
    #      — the only explicit rev pin left under `examples/` — has been bumped
    #      to that release, and any stale local `examples/*/flake.lock` has been
    #      refreshed or deleted.
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
