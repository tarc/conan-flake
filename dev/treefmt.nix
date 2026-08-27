{ pkgs, ... }:
{
  settings = {
    excludes = [
      "*.toml"
      "build/*"
      # `astro build`/`astro dev` write the rendered site here; it is generated
      # output and is git-ignored.
      "docs/dist/*"
      # The site's dependency tree: copied out of the Nix store by the
      # development shell, holding nothing this repository authors. The
      # trailing `/*` is what makes this match anything — the patterns are
      # matched whole against repository-relative *file* paths (see the
      # `features/*` note below), so a bare directory name would exclude
      # nothing. It is git-ignored, and treefmt's default walk is git-based, so
      # the walker already keeps it out; this entry is the second net, for a
      # walk that is not.
      "docs/node_modules/*"
      # Written by `pnpm`, not by hand: `yamlfmt` reformats both (it drops the
      # blank lines separating the settings of the second), and the lockfile's
      # bytes are what the fixed-output dependency fetch is pinned against.
      "docs/pnpm-lock.yaml"
      "docs/pnpm-workspace.yaml"
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
    # NOTE: `mdsh` regenerates the command-output blocks of the documentation
    # site by *running* the `examples/*` projects, and those resolve
    # `conan-flake` from the published upstream, never from this checkout:
    # `examples/.gitignore` keeps
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
    # If that window opens again, set
    # `excludes = [ "docs/src/content/docs/*.md" ]` here for its duration — the
    # same list `includes` carries just below, so that the formatter matches
    # zero files and is disabled without being unwired, leaving the committed
    # blocks untouched. Clear the exclude once the release is on `main` *and*
    # that rev is bumped to it.
    #
    # `README.md` used to carry blocks of this kind and is where the hazard was
    # first met; it is now a pointer at the site (`readme.SCOPE.1`) and carries
    # no command-output block, so it is off this formatter's `includes`. `mdsh`
    # runs each block from the directory of the file carrying it, which is why
    # the site's blocks `cd` to the repository root first.
    #
    # The list is set here rather than under `settings.formatter.mdsh` because
    # `treefmt-nix` ships `programs.mdsh` as `mkFormatterModule { includes =
    # [ "README.md" ]; }`: that *defines* `settings.formatter.mdsh.includes`,
    # which is a `listOf str`, so a definition of our own there would merge with
    # `README.md` instead of replacing it. `programs.mdsh.includes` is that same
    # list's option *default*, so assigning it replaces the file — verified
    # against the generated `treefmt.toml` by the `readme.INTEGRITY.2` check,
    # which reads the evaluated configuration rather than this text.
    #
    # authoring.COMMAND_OUTPUT.1
    # authoring.COMMAND_OUTPUT.2
    # readme.INTEGRITY.2
    mdsh = {
      enable = true;
      includes = [
        "docs/src/content/docs/*.md"
      ];
    };
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
      # other on every activation. `README.md` was excluded for that reason and
      # stays excluded, because the one sample it kept is embedded like the
      # site's; the site's Markdown sources carry the same markers and need the
      # same exclusion.
      #
      # `CLAUDE.md` is excluded for an unrelated reason: `deno fmt` strips
      # leading/trailing whitespace *inside* inline code spans while reflowing
      # a paragraph, `--prose-wrap=preserve` does not stop it (verified against
      # both), and this file is exactly the kind of place that documents an
      # exact character sequence inside backticks (e.g. "a colon immediately
      # followed by a space (`: `)") — silently corrupting that on every shell
      # activation is worse here than in ordinary prose, since this file is
      # read as authoritative agent instructions, not just formatted for
      # humans. It carries no `embedmd`/`mdsh` markers, so it loses nothing
      # from `deno fmt`'s other behaviors by being excluded.
      #
      # authoring.FORMATTING.1
      # readme.INTEGRITY.2
      excludes = [
        "README.md"
        "docs/*"
        "CLAUDE.md"
      ];
    };

    embedmd = {
      # The code samples of the documentation site are declared by the same
      # kind of `[embedmd]:# (...)` marker `README.md` uses, so the formatter
      # has to reach them too — `embedmd` rewrites a marker's block from the
      # example file it names, and a sample nobody regenerates is a sample that
      # rots. The site's markers reach `examples/` through the
      # `docs/src/content/docs/.examples` symbolic link, because `embedmd`
      # resolves a path relative to the Markdown file and refuses to leave that
      # directory.
      #
      # `README.md` stays on this list for the one configuration example it
      # kept, which is embedded from an example project too.
      #
      # authoring.EMBEDDING.2
      # readme.INTEGRITY.2
      command = "${pkgs.embedmd}/bin/embedmd";
      includes = [
        "README.md"
        "docs/src/content/docs/*.md"
      ];
    };
  };
}
