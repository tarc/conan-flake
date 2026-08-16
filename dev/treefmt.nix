{ pkgs, ... }:
{
  settings = {
    excludes = [
      "*.toml"
      "build/*"
      # `mdbook build`/`mdbook serve` write the rendered site here; it is
      # generated output and is git-ignored.
      "docs/book/*"
      "examples/cuda-flake-parts/flake.nix"
      "examples/devenv-module/devenv.nix"
      "examples/devenv-module-recipe/devenv.nix"
      "examples/flake-parts/flake.nix"
      "examples/llvm-flake-parts/flake.nix"
      "examples/simple-flake-parts/flake.nix"
      "examples/standalone-eval-conan-config/flake.nix"
      "examples/standalone-submodule-with/flake.nix"
      "nix/packages/*"
      # The specification files, including the per-product subdirectories:
      # treefmt matches these patterns against the whole repository-relative
      # path and its `*` does cross `/`, so this one covers
      # `features/<product>/<name>.feature.yaml` as well — verified by feeding
      # a deliberately misformatted file to `treefmt` at both depths, which
      # `yamlfmt` left untouched at both.
      #
      # authoring.FORMATTING.2
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
      # `deno fmt` rewrites the two kinds of generated block this repository
      # relies on: it respells an `[embedmd]:# (...)` marker as
      # `[embedmd]: # (...)`, and it inserts blank lines around the fenced code
      # inside an `<!-- BEGIN mdsh -->`/`<!-- END mdsh -->` pair, which the
      # next `mdsh` run strips again — the two formatters then rewrite each
      # other on every activation. `README.md` was excluded for that reason;
      # the site's Markdown sources carry the same markers and need the same
      # exclusion.
      #
      # authoring.FORMATTING.1
      excludes = [
        "README.md"
        "docs/*"
      ];
    };

    embedmd = {
      command = "${pkgs.embedmd}/bin/embedmd";
      includes = [ "README.md" ];
    };
  };
}
