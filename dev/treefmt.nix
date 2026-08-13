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
    # NOTE: `mdsh` regenerates the `README.md` command-output blocks by *running*
    # the `examples/*` projects, and those resolve `conan-flake` from the
    # published upstream, never from this checkout: `examples/.gitignore` keeps
    # their lockfiles uncommitted, and the one explicit rev pin left — the
    # `fetchGit` rev in `examples/standalone-submodule-with/default.nix`, which
    # pins by rev because that example illustrates the no-flakes path, where no
    # lockfile exists to do it — is bumped by each `Release x.y.z` commit.
    #
    # So whenever the option interface changes in a breaking way, the examples
    # keep evaluating against the *previous* interface until the release lands
    # and that rev is bumped. In between they fail to evaluate and `mdsh` writes
    # back *empty* blocks, silently deleting ~111 committed lines. This is not
    # hypothetical and it is not something a convention can prevent: devenv runs
    # a bare `treefmt` as the `devenv:treefmt:run` task, ordered
    # `before = ["devenv:enterShell"]`, so it fires on *every* shell activation,
    # and `.envrc` activates the shell through direnv.
    #
    # If that window opens again, set `settings.formatter.mdsh.excludes =
    # [ "README.md" ]` below for its duration. `treefmt-nix` only ever points
    # `mdsh` at `README.md` (`includes = ["README.md"]`), so that exclude makes
    # the formatter match zero files, disabling it without unwiring it. Clear
    # the exclude once the release is on `main` *and* that rev is bumped to it.
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
