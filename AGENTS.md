# AGENTS.md

Pure Nix module repo (no compiled code): conan-flake bridges Nix and the Conan
C/C++ package manager. The deliverable is `nix/`; validation means evaluating
and running the flakes under `examples/`, `test/`, and `dev/`. See `CLAUDE.md`
for the full architecture guide — this file holds the facts you are most likely
to get wrong.

## Commands

- `just check` — `nix flake check ./dev --override-input conan-flake .` (the
  primary verification; also accepts a path, e.g.
  `just check ./examples/flake-parts`).
- `just ci` — full local CI via `vira` (same as Woodpecker's `tests` step).
- Single scenario:
  `nix flake check ./examples/flake-parts --override-input conan-flake . --show-trace --no-pure-eval`.
- `just docs` / `just docs-serve` — build (Nix) / serve (`mdbook`) the docs
  site.

Always pass `--override-input conan-flake .` when evaluating example/test
flakes, or they resolve conan-flake from the published upstream instead of this
checkout. `nix flake show` additionally needs
`--option allow-import-from-derivation true` (the `justfile` handles this in its
recipes).

## Hard constraints

- The root `flake.nix` declares **no inputs** and nothing may add one (the docs
  site builds from `dev/flake.nix` for this reason). Only `dev/flake.lock` is
  committed; `examples/*` lockfiles are deliberately gitignored.
- **Spec-driven development (acai)**: `features/*.feature.yaml` are the source
  of truth. Spec first, then code; reference ACIDs (e.g. `readme.INTEGRITY.2`)
  in code comments and test names. Load the `acai` skill before planning or
  implementing.
- Keep `evalConanConfig` and `submoduleWith` in sync — both assemble
  `nix/modules/configuration` + the same `specialArgs` (see the
  `# NOTE: keep in sync` comments in `nix/lib/default.nix`).
- New `examples/*` or `test/*` scenarios must be added to `build.flakes` in
  `vira.hs` or CI never exercises them.

## Docs are generated — the `mdsh` trap

`docs/src/*.md` and `README.md` embed live snippets from `examples/` (via
`embedmd`) and live command output (via `mdsh`). If you edit a referenced
example file, regenerate with `embedmd README.md docs/src/*.md` (also runs as a
pre-commit hook).

**Never run bare `mdsh` (or `treefmt`, which triggers it) while the local option
interface is ahead of the latest release**: examples resolve conan-flake from
upstream, fail against the old interface, and `mdsh` silently writes _empty_
blocks, deleting committed lines. During that window set
`programs.mdsh.excludes = [ "docs/src/*.md" ]` in `dev/treefmt.nix`. `CLAUDE.md`
explains the full mechanism.

## Repo shape (one line each)

- `nix/modules/configuration/` — the actual `conan` option definitions (one
  concern per file); `nix/lib/` — the standalone library surface.
- `dev/` — devenv-based dev environment that dogfoods conan-flake; all `just`
  recipes point `nix` at it.
- Config-root/home paths are resolved by generated shell scripts at
  shell-activation time, not eval time — this is intentional and covered by
  `test/inner-home-directory` / `test/outer-root-directory`.
- Option docs live in the options' `description`/`example` attributes (published
  to flake.parts); prefer updating those over adding prose elsewhere.
