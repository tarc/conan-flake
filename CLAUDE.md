# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with
code in this repository.

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
  pipeline (`conan`, `embedmd`, `mdsh`, `woodpecker`).
- `examples/` — one directory per integration style (`flake-parts`, `devenv`,
  `devenv-module`, `devenv-module-recipe`, `standalone`,
  `standalone-eval-conan-config`, `standalone-submodule-with`,
  `llvm-flake-parts`, `cuda-flake-parts`), each a real, runnable C++/Conan
  project. These double as the flake `templates.*` outputs in `flake.nix` and as
  README code snippets (see below).
- `test/` — additional scenario flakes (default overrides, profile overrides,
  nested home directories, outer root directories, etc.), listed explicitly in
  `vira.hs` for CI.
- `dev/` — the actual devenv-based development environment for hacking on
  conan-flake itself (see below).

## Documentation is generated, not hand-maintained

`README.md` embeds live code snippets from `examples/` via `embedmd` markers
(`[embedmd]:# (./examples/... nix ...)`) and a live command-output block (the
`conan profile show` output near "Contributing") via `mdsh`. **If you edit a
referenced example file or change the `conan profile show` output, the
corresponding README block will go stale** — regenerate with the `embedmd`
pre-commit hook (auto-runs on commit inside the devenv shell) or manually:

```sh
embedmd README.md
# Do NOT run a bare `mdsh` on a normal checkout — see the paragraph below; it
# will empty the README's command-output blocks while the examples/* pins are
# stale. Only run it against a checkout whose example pins match the local
# option interface.
mdsh
```

**`mdsh` regeneration of `README.md` is currently pinned off.**
`dev/treefmt.nix` sets `settings.formatter.mdsh.excludes = [ "README.md" ]`, and
because `treefmt-nix` scopes that formatter to `README.md` and nothing else
(`includes = [ "README.md" ]`), the exclude disables `mdsh` entirely for
`treefmt` runs — it is not narrowed to some other markdown. The `mdsh` blocks
are produced by _running_ the `examples/*` projects, which resolve `conan-flake`
from the published upstream rather than the local checkout: there is no
_committed_ `flake.lock` under `examples/` (`examples/.gitignore` ignores them,
so any local lockfiles are stale, uncommitted and never bumped by a release),
and the explicit rev pins — `examples/flake-parts/flake.nix`'s
`conan-flake.url = "...?rev=..."` and the `fetchGit` rev in
`examples/standalone-submodule-with/default.nix` — are bumped only by each
release. While the local option interface is ahead of those pins, the examples
fail to evaluate and `mdsh` writes back _empty_ blocks — silently deleting ~111
committed lines. This mattered in practice because devenv runs a bare `treefmt`
as the `devenv:treefmt:run` task, ordered `before = ["devenv:enterShell"]`, so
it fired on every direnv/devenv shell activation. The committed `README.md` is
the correct post-release state; do not re-enable `mdsh` for it until the current
interface is released on `main` _and_ every explicit rev pin under `examples/`
is bumped to that release. `embedmd` is unaffected and still formats `README.md`
on every `treefmt` run.

## Development workflow

This project is developed using its own `dev/` devenv configuration (i.e.
conan-flake dogfoods itself — `dev/devenv.nix` / `dev/flake.nix` configure a C++
"foo" project via the local checkout).

Enter the dev shell (first time):

```sh
devenv --from path:dev allow
devenv inputs add conan-flake path:"$PWD"
devenv shell
```

After enter the dev shell as above (first time), that is, allowing devenv to set
up the environment and adding conan-flake input, use `devenv shell` to get a
shell with Conan and all dependencies installed. Prefix commands with
`devenv shell --` to run them directly.

Common commands (see `justfile`, run from repo root — these all point `nix` at
`./dev` and override the `conan-flake` input with the local checkout):

```sh
just show            # nix flake show ./dev (override-input conan-flake .)
just check           # nix flake check ./dev (override-input conan-flake .)
just repl            # nix repl ./dev (override-input conan-flake .)
just ci              # run the full local CI via `vira` (same as Woodpecker's `tests` step)
just vira <args>     # run `vira` with arbitrary arguments
just search <query>  # conan search "<query>" (defaults to "*")
```

`just show`/`just check` also accept a path/flake ref argument to target
something other than `./dev`, e.g. `just check ./examples/flake-parts`.

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

- `.woodpecker/checks.yml` — on push/PR to `main` (when `nix/**`, `dev/**`,
  `examples/**`, `test/**`, `flake.nix`, `flake.lock`, `vira.hs`, or
  `.woodpecker/*.y*ml` change): `nix flake check ./dev`, then `vira ci -b`
  (which evaluates/builds every flake listed in `vira.hs`'s `build.flakes`),
  then a build of `flake.parts-website` against this repo (docs build).
  `flake.lock` is anticipatory cover only — the root `flake.nix` declares no
  inputs, so no root lockfile exists to match today.
- `.woodpecker/release.yml` — on GitHub/Codeberg `release` events on `main`:
  runs `vira ci -b` again.
- `vira.hs` is the source of truth for **which** example/test flakes are
  exercised in CI — when adding a new `examples/*` or `test/*` scenario intended
  to be checked in CI, add it to the `build.flakes` list there.

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
