# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with
code in this repository. Topic-specific guidance loads on demand from
`.claude/rules/`:

- `.claude/rules/generated-docs.md` — `embedmd`/`mdsh` blocks in the site and
  `README.md` (loads for `docs/**`, `README.md`, `examples/**`,
  `dev/treefmt.nix`).
- `.claude/rules/feature-specs.md` — strict-YAML pitfalls in
  `features/**/*.feature.yaml`.

## What this is

`conan-flake` is a **pure Nix module** (no compiled code of its own) that
bridges [Nix](https://nixos.org/) and the
[Conan C/C++ package manager](https://conan.io/), letting Conan profiles,
remotes, and tool requirements be declared as Nix options instead of
hand-written Conan config files. It can be consumed as: plain Nix (no flakes), a
Nix flake, a [`flake-parts`](https://flake.parts/) module, or a
[devenv](https://devenv.sh/) module (`languages.cplusplus.conan`).

There is no application/library source to build in the traditional sense — the
deliverable is `nix/` (the module + library code), validated by evaluating and
running the example/test flakes under `examples/` and `test/`.

## Repo layout

- `nix/modules/flake-module.nix` — the `flake-parts` module entry point
  (`perSystem.conan` option), wiring `conan.outputs.{devShell,checks,packages}`
  into the corresponding flake outputs when auto-wired.
- `nix/modules/configuration/` — the actual `conan` submodule option/config
  definitions, imported by `default.nix`. Each file owns one concern and they
  compose via NixOS-module `imports`:
  - `root.nix` — `configRoot`/root-finding (locates the project root at runtime
    via a generated `find_up` shell script).
  - `home.nix` — `conanHome`/`homeRoot`/`homeDirectory` and the runtime "home
    finding" shell script that resolves `CONAN_FLAKE_ROOT`, `CONAN_FLAKE_HOME`,
    `CONAN_FLAKE_CONFIG`, `CONAN_HOME` at shell-activation time (not eval time —
    this lets the same derivation work whether the project lives in the Nix
    store or a mutable checkout).
  - `wrappers.nix` — generates the
    `conan`/`build`/`lock-create`/`config-install`/... wrapper scripts
    (`outputs.packages`) that source the home-finding env script before running
    the real `conan` CLI.
  - `settings.nix`, `profiles/`, `remotes/` — Conan profile settings,
    `platform_tool_requires`, and remote (including local-recipe-index)
    configuration, rendered into Conan config file format.
  - `devshell.nix` — builds the `outputs.devShell` (a `pkgs.mkShell`) from
    `devShell.tools`/`env`/`enterShell`, merged with `defaults.devShell.tools`.
  - `defaults.nix` — conan-flake's built-in defaults (default toolchain wiring,
    e.g. clang/libc++ detection via `isClangLibcxxLLVM`).
  - `checks.nix` — user-defined `checks.<name>.{enable,drv}` collected into
    `outputs.checks`.
  - `outputs.nix` / `info.nix` — aggregates generated Conan configuration
    files/packages into `outputs.{configuration,links,packages}`.
- `nix/lib/` — the standalone library surface (`conan-flake.lib` in a flake, or
  `import nix/lib` without flakes):
  - `lib.nix` / `default.nix` — `evalConanConfig` (evaluate a config directly
    with `nixpkgs.lib.evalModules`) and `submoduleWith` (embed conan-flake as a
    submodule inside a larger option tree). Keep these two in sync (see the
    `NOTE: keep in sync` comments) since they assemble the same module list two
    different ways.
  - `types.nix`, `parsing.nix` — shared option types and system/arch parsing
    helpers.
  - `packages.nix`, `external.nix` — package getters (`conan`, `embedmd`,
    `mdsh`, `woodpecker-cli`) and third-party Nix helpers (e.g. `infuse`).
- `nix/packages/` — Nix derivations for tools used by the dev shell/docs
  pipeline (`conan`, `embedmd`, `mdsh-0.9.2`, `mdsh-0.9.3`, `woodpecker`) and
  the documentation site itself (`docs`).
- `examples/` — one directory per integration style (`flake-parts`, `devenv`,
  `devenv-module`, `devenv-module-recipe`, `standalone`,
  `standalone-eval-conan-config`, `standalone-submodule-with`,
  `llvm-flake-parts`, `cuda-flake-parts`), each a real, runnable C++/Conan
  project. These double as the flake `templates.*` outputs in `flake.nix` and as
  the code snippets of the documentation site and of `README.md`.
  `simple-flake-parts` is also tracked but unused: no template, no `vira.hs`
  entry, no doc reference.
- `test/` — additional scenario flakes (default overrides, profile overrides,
  nested home directories, outer root directories, etc.), listed explicitly in
  `vira.hs` for CI.
- `dev/` — the actual devenv-based development environment for hacking on
  conan-flake itself (see below).
- `docs/` — the Astro + Starlight sources of the documentation site
  (`astro.config.mjs`, `package.json`/`pnpm-lock.yaml` and the Markdown
  chapters under `src/content/docs/`), which **is** the project's
  documentation, live at <https://tarcisio.codeberg.page/conan-flake/>.
  - Built by the `conan-flake.lib.packages.docs` derivation
    (`nix/packages/docs/`; npm dependencies vendored by a fixed-output
    `fetchPnpmDeps`), wired into `nix flake check ./dev` as `checks.docs`. The
    root `flake.nix` stays free of inputs, which is why the build lives on the
    `dev` side.
  - Per-ACID assertions over the built site: `nix/packages/docs/checks.nix`
    combines `checks/{site,publishing,readme}.nix` (shared helpers in
    `checks/common.nix`).
  - Preview with `just docs` (Nix build) or `just docs-serve` (`astro dev`,
    live reload).
- Publishing — `scripts/publish-pages.sh` commits the built site onto the
  orphan `pages` branch and pushes it to Codeberg (served by git-pages).
  - Locally: `just docs-publish`.
  - CI: `.woodpecker/pages.yml` via `scripts/publish-pages-ci.sh` (secret
    `codeberg_token`), on a push to `main` touching that workflow's path filter
    **and** on a manual run (how to republish when nothing changed). Webhook
    and secret are registered, so a matching merge to `main` publishes.
  - A fork must make `codeberg_token` available at the `push` event _before_
    turning publishing on: Woodpecker resolves `from_secret:` while compiling
    the workflow, so a run whose event the secret doesn't list fails before any
    step starts. The activation checklist in
    `docs/src/content/docs/contributing.md` is the authority.
- `README.md` — **not** documentation: a pointer at the site (what conan-flake
  is, one embedded configuration example, `nix flake init -t …`, a link per
  chapter, the option reference, the licence). The `readme.*` checks fail if a
  site chapter is not linked from it, if a link points at a page the site does
  not carry, or if its embedded sample drifts from the example it names.
  Chapter links are the site's page URLs (`…/conan-flake/<chapter>/`).

## Spec-driven development (`features/*.feature.yaml`)

This project follows the `acai.sh` spec-driven process (load the `acai` skill
for the full workflow: specs are law, referenced from code/tests by stable ACID
— `<feature>.<COMPONENT>.<requirement>`). The specs live in
`features/<product>/<feature-name>.feature.yaml` (`features/docs/`,
`features/module/`). Before trusting an edit to one, validate it with the strict
parser — see `.claude/rules/feature-specs.md`.

## Development workflow

This project is developed using its own `dev/` devenv configuration (i.e.
conan-flake dogfoods itself — `dev/devenv.nix` / `dev/flake.nix` configure a C++
"foo" project via the local checkout).

Enter the dev shell (first time):

```sh
devenv --from path:dev allow
devenv inputs add conan-flake "git+file://$PWD"
devenv shell
```

After that, use `devenv shell` to get a shell with Conan and all dependencies
installed, or prefix commands with `devenv shell --` to run them directly.

Claude Code configuration is generated too: `.claude/settings.json` and
`.claude/agents/*.md` are Nix-store symlinks produced by `claude.code` in
`dev/devenv.nix` (gitignored) — change them there, not in place. That
`settings.json` carries a `PostToolUse` hook running `prek run` after every
Edit/Write, so the `embedmd` pre-commit hook can rewrite `README.md` and the
site's Markdown right after an edit.

Common commands (see `justfile`, run from repo root — these all point `nix` at
`./dev` and override the `conan-flake` input with the local checkout):

```sh
just show            # nix flake show ./dev (override-input conan-flake .)
just check           # nix flake check ./dev (override-input conan-flake .)
just repl            # nix repl ./dev (override-input conan-flake .)
just ci              # run the full local CI via `vira` (same as Woodpecker's `tests` step)
just vira <args>     # run `vira` with arbitrary arguments
just search <query>  # conan search "<query>" (defaults to "*")
just docs            # build the documentation site through Nix (./result)
just docs-serve      # serve docs/ locally with astro, reloading on changes
just docs-publish    # build the site and push it to the `pages` branch
```

`just show`/`just check` also accept a path/flake ref argument to target
something other than `./dev`, e.g. `just check ./examples/flake-parts`.

Footprint: the repo-root `.devenv/` (the dev shell) and the `./result` link left
by `just docs` are Nix GC roots — both are recorded in `~/.claude/footprint.md`;
`rm result` once the built site has been inspected.

### Running a single example/test scenario

Each directory under `examples/` and `test/` is an independent flake. To
validate one in isolation (overriding its `conan-flake` input with the local
checkout):

```sh
nix flake check ./examples/flake-parts --override-input conan-flake . --show-trace --no-pure-eval
```

For scenarios exercising the actual Conan build (most examples define a
`checks.test` derivation that runs `conan install`/`conan build` inside a
simulated shell via `runCommandWithInSimulatedShell`), `nix flake check` is
sufficient — no separate test runner exists.

### CI

- `.woodpecker/checks.yml` — on push/PR to `main`, path-filtered (`nix/**`,
  `dev/**`, `docs/**`, `examples/**`, `test/**`, `scripts/**`, `justfile`,
  `CHANGELOG.md`, root `README.md`, `flake.nix`, `flake.lock`, `vira.hs`,
  `.woodpecker/*.y*ml`; an example's/test's own `README.md` is excluded). Runs:
  1. `nix flake check ./dev`;
  2. `vira ci -b` (evaluates/builds every flake in `vira.hs`'s `build.flakes`);
  3. a build of `flake.parts-website` against this repo (option reference).

  `flake.lock` in the filter is anticipatory — the root `flake.nix` declares no
  inputs, so no root lockfile exists today.
- `.woodpecker/pages.yml` — publishes the documentation site (see above).
- `.woodpecker/release.yml` — on GitHub/Codeberg `release` events on `main`:
  runs `vira ci -b` again.
- Pinning: `dev/flake.lock` is committed, so CI resolves the same inputs every
  run; refresh deliberately with `nix flake update ./dev` (or
  `nix flake update --flake ./dev <input>`). Its `conan-flake` entry is
  irrelevant (always overridden). `test/*` pin `nixpkgs` by rev inline;
  `examples/*` are deliberately unpinned (`examples/.gitignore` ignores their
  lockfiles).
- `vira.hs` is the source of truth for **which** example/test flakes CI
  exercises — add any new `examples/*` or `test/*` scenario meant for CI to its
  `build.flakes` list.

## Architecture notes worth knowing before editing

- **Two ways to consume the module, kept in sync deliberately**:
  `conanFlakeLib.evalConanConfig` (top-level flake usage) and
  `conanFlakeLib.submoduleWith` (embedding as a submodule, e.g. inside
  `perSystem.conan` or the devenv `languages.cplusplus.conan.config` option)
  both assemble `nix/modules/configuration` plus the same `specialArgs`
  (`defaultSpecialArgs` in `nix/lib/default.nix`). Changing the module list or
  special args in one place almost always requires the matching change in the
  other (see the `# NOTE: keep in sync` comments in `nix/lib/default.nix`).
- **Eval-time config vs. runtime shell-script resolution**: options like
  `configRoot`, `homeRoot`, `homeDirectory` are Nix-eval-time inputs, but the
  actual `CONAN_FLAKE_ROOT`/`CONAN_FLAKE_HOME`/`CONAN_FLAKE_CONFIG`/`CONAN_HOME`
  environment variables are computed by generated shell scripts
  (`rootFinding.package`, `homeFinding.package`, sourced via
  `wrappers.initEnvScript`) at shell-activation/build time. This is what allows
  the same store-path derivation to behave correctly whether it's invoked from
  inside the Nix store, a devenv checkout, or a nested project directory
  (`homeDirectory`) — the `test/inner-home-directory`,
  `test/outer-root-directory` scenarios specifically cover this.
- **`autoWire`** (`nix/modules/configuration/default.nix`) controls which of
  `devShells`/`checks`/`packages` the flake-parts module auto-exposes; setting
  it to `[]` disables autowiring so `config.conan.outputs.*` must be wired
  manually — several `test/flake-parts-*` scenarios test this knob.
- **`defaults.nix`** encodes conan-flake's opinionated defaults (default
  dev-shell tools, clang/libc++ toolchain detection). Anything here can be
  overridden per-config via `devShell.tools.<name> = null` to remove a default
  tool, or `defaults.enable = false` to opt out entirely.
- Nix module options are documented inline via their `description`/`example`
  attributes and published externally at the official
  [flake.parts conan-flake docs](https://flake.parts/options/conan-flake.html)
  (built from this repo by the `flake.parts-website` CI step) — prefer
  writing/updating option `description`s over adding prose elsewhere.
