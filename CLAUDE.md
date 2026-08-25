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
  the code snippets of the documentation site and of `README.md` (see below).
- `test/` — additional scenario flakes (default overrides, profile overrides,
  nested home directories, outer root directories, etc.), listed explicitly in
  `vira.hs` for CI.
- `dev/` — the actual devenv-based development environment for hacking on
  conan-flake itself (see below).
- `docs/` — the mdBook sources of the documentation site (`book.toml` plus
  `src/`), which **is** the project's documentation and is live at
  <https://tarcisio.codeberg.page/conan-flake/>. The site is built by the
  `conan-flake.lib.packages.docs` derivation (`nix/packages/docs/`) and wired
  into `nix flake check ./dev` as `checks.docs` plus one check per ACID it has
  to satisfy (`nix/packages/docs/checks/`, one file per feature: `site.nix`,
  `publishing.nix`, `readme.nix`, sharing `common.nix`); the root `flake.nix`
  stays free of inputs, which is why the build lives on the `dev` side. Preview
  it with `just docs` (Nix build) or `just docs-serve` (`mdbook serve`, live
  reload).
- Publishing: `scripts/publish-pages.sh` commits the built site onto the orphan
  `pages` branch and pushes it to Codeberg, which serves it through git-pages.
  `just docs-publish` runs it locally; `.woodpecker/pages.yml` runs it from CI
  through `scripts/publish-pages-ci.sh`, reading the `codeberg_token` secret, on
  a push to `main` touching the paths that workflow filters on (the site's
  sources plus everything that decides what publishing does) **and** on a manual
  run — the manual run being how the site is republished when nothing changed.
  The webhook and that secret are registered and the site is being served, so a
  merge to `main` touching those paths publishes. A fork has to make
  `codeberg_token` available at the `push` event _before_ it turns publishing
  on: Woodpecker resolves `from_secret:` while _compiling_ the workflow, so a
  run whose event the secret does not list fails before any step starts — the
  activation checklist in `docs/src/contributing.md` is the authority on that.
- `README.md` — **not** documentation: a pointer at the site (what conan-flake
  is, one embedded configuration example, `nix flake init -t …`, a link per
  chapter, the option reference, the licence). Every topic it used to cover
  lives in `docs/src/`; the `readme.*` checks fail if a chapter of the site is
  not linked from it, if one of its links points at a page the site does not
  carry, or if its embedded sample drifts from the example project it names.

## Documentation is generated, not hand-maintained

The site's Markdown sources (`docs/src/*.md`) and `README.md` embed live code
snippets from `examples/` via `embedmd` markers
(`[embedmd]:# (./.examples/... nix ...)` on the site, which reaches `examples/`
through the `docs/src/.examples` symlink), and the site's sources also carry
live command-output blocks (such as the `conan profile show` output in the
contributing chapter) via `mdsh`. **If you edit a referenced example file or
change the output of one of those commands, the corresponding block will go
stale** — regenerate with the `embedmd` pre-commit hook (auto-runs on commit
inside the devenv shell) or manually:

```sh
embedmd README.md docs/src/*.md
# Deliberately left commented out: running a bare `mdsh` on a normal checkout
# empties the site's command-output blocks while the examples/* pin is stale
# — see the paragraph below. Uncomment it only against a checkout whose example
# pin matches the local option interface.
# mdsh --inputs docs/src/*.md
```

`README.md` carries no `mdsh` block, so `programs.mdsh.includes` in
`dev/treefmt.nix` names `docs/src/*.md` alone. That list has to be set on
`programs.mdsh` rather than on `settings.formatter.mdsh`: `treefmt-nix` ships
`programs.mdsh` as `mkFormatterModule { includes = [ "README.md" ]; }`, which
_defines_ `settings.formatter.mdsh.includes`, and since that option is a
`listOf str` a definition of our own there merges with `README.md` instead of
replacing it. `README.md` keeps exactly one `embedmd` marker, so it stays on
`embedmd`'s `includes` and on `deno`'s `excludes`. The `readme.INTEGRITY.2`
check reads the generated `treefmt.toml`, not `dev/treefmt.nix`, so claims of
this kind are checked against what `treefmt` is handed.

**Beware the `mdsh` window around a breaking release.** The `mdsh` blocks are
produced by _running_ the `examples/*` projects, and those resolve `conan-flake`
from the published upstream, never from the local checkout:
`examples/.gitignore` keeps their lockfiles uncommitted, and the one explicit
rev pin left — the `fetchGit` rev in
`examples/standalone-submodule-with/default.nix`, which pins by rev because that
example illustrates the no-flakes path, where no lockfile exists to do it — is
bumped by each release. So between a breaking option change and the release that
publishes it, the examples still evaluate against the _previous_ interface: they
fail, and `mdsh` writes back _empty_ blocks, silently deleting committed lines
(~111 of them when `README.md` still carried those blocks). Nothing about that
is hypothetical — devenv runs a bare `treefmt` as the `devenv:treefmt:run` task,
ordered `before = ["devenv:enterShell"]`, so it fires on every direnv/devenv
shell activation.

If that window opens again, set `programs.mdsh.excludes = [ "docs/src/*.md" ]`
in `dev/treefmt.nix` for its duration — the same list `programs.mdsh.includes`
carries there, so the exclude points `mdsh` at zero files and disables it
without unwiring it. Clear it once the interface is released on `main` _and_
that rev is bumped to the release, then regenerate with `mdsh`. `embedmd` is
unaffected either way.

## Spec-driven development (`features/*.feature.yaml`)

This project follows the `acai.sh` spec-driven process (load the `acai` skill
for the full workflow: specs are law, referenced from code/tests by stable ACID
— `<feature>.<COMPONENT>.<requirement>`). The specs live in
`features/<product>/<feature-name>.feature.yaml`.

**A requirement's text is a YAML plain scalar, not free text.** Two mistakes
both parse fine under a lenient parser (e.g. Python's `yaml.safe_load`, easy to
reach for while authoring/checking) and fail under the stricter YAML 1.2 parser
that actually validates specs (`@acai.sh/cli`'s bundled `yaml` npm package):

- **A colon immediately followed by a space (`: `) inside the value** is read
  as introducing a nested mapping, and fails with "Nested mappings are not
  allowed in compact mappings". Use ` - ` instead (already this project's
  convention for an inline aside, e.g. requirement `defaults.PROFILE.2`'s "...
  native option priority - an entry assigned...").
- **Starting the value with a quote character (`'`/`"`)** makes the parser
  read a quoted scalar there, then fails on any trailing text with "Unexpected
  scalar at node end". Use backticks for emphasis instead — already this
  project's convention throughout every spec and doc comment (`` `options` ``,
  not `'options'`).

`@acai.sh/cli`'s own error for the first mistake is literally "Nested mappings
are not allowed in compact mappings (YAML 0)" — that strict-mode `yaml` npm
package isn't a resolvable dependency anywhere in `dev/node_modules`
(`@acai.sh/cli` bundles it), so validate with a disposable install rather than
assuming it's on the require path. Neither mistake is caught by Nix (these
files are pure YAML, uninvolved in any `nix flake check`), so this is worth
doing before trusting a `.feature.yaml` edit compiles, not just before
`acai push`:

```sh
mkdir -p /tmp/yaml-check && cd /tmp/yaml-check && npm install --silent yaml
node -e "require('yaml').parse(require('fs').readFileSync(process.argv[1], 'utf8'), { strict: true })" path/to/x.feature.yaml
```

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
just docs            # build the documentation site through Nix (./result)
just docs-serve      # serve docs/ locally with mdbook, reloading on changes
just docs-publish    # build the site and push it to the `pages` branch
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
  `docs/**`, `examples/**`, `test/**`, `scripts/**`, `justfile`, `CHANGELOG.md`,
  the repository-root `README.md`, `flake.nix`, `flake.lock`, `vira.hs`, or
  `.woodpecker/*.y*ml` change; the `README.md` of an example/test scenario is
  excluded): `nix flake check ./dev`, then `vira ci -b` (which evaluates/builds
  every flake listed in `vira.hs`'s `build.flakes`), then a build of
  `flake.parts-website` against this repo (option reference build). `flake.lock`
  is anticipatory cover only — the root `flake.nix` declares no inputs, so no
  root lockfile exists to match today.
- `.woodpecker/pages.yml` — publishes the documentation site (see the `docs/`
  entry above).
- `dev/flake.lock` is committed, so the `dev` step resolves the same input
  revisions on every run. Refresh it deliberately with `nix flake update ./dev`
  (or a single input with `nix flake update --flake ./dev <input>`); nothing
  refreshes it on its own. Its `conan-flake` entry is irrelevant, since every
  invocation overrides that input. The `test/*` scenarios pin `nixpkgs` by rev
  inline instead, and the `examples/*` ones are deliberately left unpinned —
  they demonstrate current usage, and `examples/.gitignore` ignores their
  lockfiles.
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
