---
paths:
  - "docs/**"
  - "README.md"
  - "examples/**"
  - "dev/treefmt.nix"
---

# Generated documentation blocks

The site's Markdown sources (`docs/src/content/docs/*.md`) and `README.md`
embed live code snippets from `examples/` via `embedmd` markers
(`[embedmd]:# (./.examples/... nix ...)` on the site, which reaches `examples/`
through the `docs/src/content/docs/.examples` symlink). The site's sources also
carry live command-output blocks (such as the `conan profile show` output in
the contributing chapter) via `mdsh`. `README.md` carries exactly one `embedmd`
marker and no `mdsh` block.

**If you edit a referenced example file or change the output of one of those
commands, the corresponding block goes stale.** The `embedmd` pre-commit hook
regenerates on commit inside the devenv shell (and, through the Claude Code
`PostToolUse` hook, after every Edit/Write); manually:

```sh
embedmd README.md docs/src/content/docs/*.md
# Deliberately left commented out: a bare `mdsh` on a normal checkout empties
# the site's command-output blocks while the examples/* pin is stale (see
# below). Uncomment only against a checkout whose example pin matches the local
# option interface.
# mdsh --inputs docs/src/content/docs/*.md
```

## The `mdsh` window around a breaking release

`mdsh` blocks are produced by _running_ the `examples/*` projects, which resolve
`conan-flake` from the published upstream, not from this checkout. Between a
breaking option change and the release that publishes it they fail, and `mdsh`
writes back _empty_ blocks, silently deleting committed lines. devenv runs a
bare `treefmt` on every shell activation (`devenv:treefmt:run`), so this fires
without anyone asking.

If that window opens: set `programs.mdsh.excludes = [ "docs/src/content/docs/*.md" ]`
in `dev/treefmt.nix` for its duration. Clear it once the interface is released
on `main` _and_ the `fetchGit` rev in
`examples/standalone-submodule-with/default.nix` is bumped to that release, then
regenerate with `mdsh`. `embedmd` is unaffected.

The full reasoning — why the examples resolve upstream, why the list is set on
`programs.mdsh` rather than `settings.formatter.mdsh` (a `listOf str` merge with
treefmt-nix's default `README.md`), and how `readme.INTEGRITY.2` checks the
generated `treefmt.toml` — lives in the `NOTE` comment above `mdsh` in
`dev/treefmt.nix`. Keep it there; don't copy it back here.
