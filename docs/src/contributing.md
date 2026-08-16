# Contributing

<!-- site.GUIDES.7 -->

## The development environment

To get started, clone this repository and allow `devenv` to set up the
environment with the configuration from the `./dev` directory:

```sh
git clone ssh://git@codeberg.org/tarcisio/conan-flake.git
cd conan-flake
devenv --from path:dev allow
```

It will complain that `conan-flake` is not available:

```text
    error: To use 'conan', run the following command:

      $ devenv inputs add conan-flake git+https://codeberg.org/tarcisio/conan-flake
```

Add the `conan-flake` input pointing to the local checkout (the root of this
repository) and activate `devenv` shell:

```sh
devenv inputs add conan-flake path:"$PWD"
devenv shell
```

Check that a default Conan profile was configured successfully:

<!-- authoring.COMMAND_OUTPUT.1 -->

```sh > text $
conan profile show
```

<!-- BEGIN mdsh -->
```text
Host profile:
[settings]
arch=x86_64
build_type=Release
compiler=gcc
compiler.cppstd=20
compiler.libcxx=libstdc++11
compiler.version=15.3.0
os=Linux
[platform_tool_requires]
cmake/4.3.4
[conf]


Build profile:
[settings]
arch=x86_64
build_type=Release
compiler=gcc
compiler.cppstd=20
compiler.libcxx=libstdc++11
compiler.version=15.3.0
os=Linux
[platform_tool_requires]
cmake/4.3.4
[conf]


```
<!-- END mdsh -->

Commands can also be run without entering the shell interactively, by prefixing
them with `devenv shell --`. To pick a different `secretspec` provider when
activating it:

```sh
devenv inputs add conan-flake path:"$PWD"
devenv --secretspec-provider dotenv shell
```

## Running the checks

The [`justfile`](https://codeberg.org/tarcisio/conan-flake/src/branch/main/justfile)
recipes all point `nix` at `./dev` and override the `conan-flake` input with the
local checkout:

```sh
just show            # nix flake show ./dev
just check           # nix flake check ./dev
just repl            # nix repl ./dev
just ci              # the full local CI, via `vira`
just vira <args>     # `vira` with arbitrary arguments
just search <query>  # conan search "<query>" (defaults to "*")
```

`just show` and `just check` also accept a path or flake reference, so a single
scenario can be targeted:

```sh
just check ./examples/flake-parts
```

Each directory under
[examples](https://codeberg.org/tarcisio/conan-flake/src/branch/main/examples)
and
[test](https://codeberg.org/tarcisio/conan-flake/src/branch/main/test) is an
independent flake, and can be validated in isolation against the local checkout:

```sh
nix flake check ./examples/flake-parts --override-input conan-flake . --show-trace --no-pure-eval
```

Most examples define a `checks.test` derivation that runs `conan install` and
`conan build` inside a simulated shell, so `nix flake check` is the whole test
runner &mdash; there is no separate one.

[`vira.hs`](https://codeberg.org/tarcisio/conan-flake/src/branch/main/vira.hs)
is the source of truth for **which** example and test flakes CI exercises: a new
scenario under `examples/` or `test/` has to be added to its `build.flakes` list
to be checked. The pipelines themselves are in
[.woodpecker](https://codeberg.org/tarcisio/conan-flake/src/branch/main/.woodpecker):
`checks.yml` runs `nix flake check ./dev`, then `vira ci -b`, then a build of
`flake.parts-website` against this repository, which is what publishes the
[option reference](https://flake.parts/options/conan-flake.html); `release.yml`
runs `vira ci -b` again on release events.

<!-- site.OPTIONS_REFERENCE.1 -->

> [!NOTE]
> Option documentation is generated from the module options' own `description`
> and `example` attributes, so an option is documented by writing those &mdash;
> never by transcribing them into this site, which would silently go stale. The
> generated result is the
> [option reference](https://flake.parts/options/conan-flake.html) this site
> links to throughout.

## The documentation site

<!-- authoring.PREVIEW.1 -->
<!-- authoring.PREVIEW.2 -->

The sources of this site are the Markdown files under
[docs](https://codeberg.org/tarcisio/conan-flake/src/branch/main/docs), rendered
by [mdBook](https://rust-lang.github.io/mdBook/). From the development shell:

```sh
just docs         # build the site, exactly as CI builds it
just docs-serve   # serve it locally, reloading on every source change
```

A new page has to be listed in
[docs/src/SUMMARY.md](https://codeberg.org/tarcisio/conan-flake/src/branch/main/docs/src/SUMMARY.md);
mdBook renders nothing that the summary does not name.

`just docs` builds through Nix, from a filtered copy of the sources, and its
output carries the site alone. `just docs-serve` runs `mdbook serve` over the
checkout instead, so it follows the `docs/src/.examples` symbolic link described
below: the preview publishes that link and mdBook watches the whole `examples`
tree, including whatever an example run left behind there. That is a property of
the local preview only, never of the built site.

### How the generated blocks are refreshed

<!-- authoring.EMBEDDING.1 -->
<!-- authoring.EMBEDDING.2 -->
<!-- authoring.EMBEDDING.3 -->

Code samples are never written into the Markdown sources by hand. Each one is
declared by an [`embedmd`](https://github.com/veggiemonk/embedmd) marker naming
the example file and the region to take, and the fenced block below the marker
is rewritten from that file:

```text
[embedmd]:# (./.examples/flake-parts/flake.nix nix !/.*{ inputs/ !/.*inputs }/ s/#  // dedent)
```

`embedmd` resolves the path relative to the Markdown file and refuses to leave
that directory, which is why the site's markers go through `docs/src/.examples`,
a symbolic link to the `examples` directory at the root of the repository.

Running `embedmd` over the sources rewrites every such block in place:

```sh
embedmd README.md docs/src/*.md
```

That same command runs as a `pre-commit` hook and as a `treefmt` formatter, so
in practice the blocks are refreshed on commit, and a sample that no longer
matches its example project fails the `authoring.EMBEDDING.2` check in CI &mdash;
the checks over the site are named after the requirement each one proves.

> [!NOTE]
> Only `nix` and `ini` blocks are guarded that way. The few `text` blocks that
> transcribe a command's output without an `mdsh` block above them &mdash; the
> `conan create` outputs, mostly &mdash; are hand-maintained, and have to be
> updated by hand when the example they came from changes.

<!-- authoring.COMMAND_OUTPUT.1 -->

Command-output blocks are generated the same way, by
[`mdsh`](https://github.com/zimbatm/mdsh): the command that produces the output
is recorded next to the block, either visibly&nbsp;&mdash;

````text
```sh > text $
conan profile show
```

<!-- BEGIN mdsh -->
```text
…output…
```
<!-- END mdsh -->
````

&mdash;&nbsp;or hidden, when the command is scaffolding rather than something
the reader would type:

```text
<!-- > $
echo '```text'
cd "$(git rev-parse --show-toplevel)/examples/flake-parts"
nix develop --command bash -c "profile-show-wrapper 2>/dev/null"
echo '```'
-->
```

`mdsh` runs each block from the directory of the Markdown file that carries it,
which is why the site's blocks `cd` to the repository root first. Running it
replaces the block that follows with the command's current output:

```sh
mdsh --inputs README.md docs/src/*.md
```

<!-- authoring.COMMAND_OUTPUT.2 -->

> [!WARNING]
> Those commands _run_ the `examples/*` projects, and those resolve conan-flake
> from the published upstream rather than from the checkout. Between a breaking
> option change and the release that publishes it, the examples fail to evaluate
> and `mdsh` writes back **empty** blocks, deleting committed content. For the
> duration of that window, set
> `settings.formatter.mdsh.excludes = [ "README.md" "docs/src/*.md" ]` in
> [dev/treefmt.nix](https://codeberg.org/tarcisio/conan-flake/src/branch/main/dev/treefmt.nix)
> &mdash; the same list `settings.formatter.mdsh.includes` carries there, so
> `mdsh` is then pointed at zero files, which turns it off without unwiring it
> and leaves the committed blocks untouched. Clear the exclude once the release
> is on `main`. `embedmd` is unaffected either way.

## Publishing the site

<!-- publishing.PUBLISH.1 -->
<!-- publishing.PUBLISH.2 -->

This site is a [Codeberg Page](https://docs.codeberg.org/codeberg-pages/) of
this repository: the content of its `pages` branch is served at
<https://tarcisio.codeberg.page/conan-flake/>. One command builds the site and
updates that branch from the build:

```sh
just docs-publish
```

It runs
[scripts/publish-pages.sh](https://codeberg.org/tarcisio/conan-flake/src/branch/main/scripts/publish-pages.sh),
which is also what CI runs, so what a contributor publishes and what a pipeline
publishes are produced by the same code. It needs no credential beyond the one
that already pushes to this repository: the push goes through the checkout's own
`origin`.

<!-- publishing.BRANCH.1 -->
<!-- publishing.BRANCH.2 -->
<!-- publishing.BRANCH.3 -->
<!-- publishing.PUBLISH.3 -->
<!-- publishing.PUBLISH.4 -->
<!-- publishing.ARTIFACT.1 -->
<!-- publishing.ARTIFACT.2 -->

What it does, and why it does it that way:

- the site is built **first**, and nothing else happens if that build fails, so
  a broken build cannot leave a half-published branch behind;
- the branch is updated through a temporary git worktree, never by switching
  this checkout, so the branch that was checked out stays checked out and the
  working tree is not touched &mdash; including when the run fails;
- `pages` is created as an **orphan** branch: it carries no source of the
  repository and its history starts at a root commit of its own;
- everything the branch carried is dropped before the new build is copied in,
  so a page removed from the site stops being served;
- the build output is copied out of the Nix store dereferencing symbolic links
  and without the store's permissions, since a store path is read-only and its
  links point back into a store no visitor has. What lands on the branch is the
  output of the site's derivation, whole: the server builds nothing.

The pipeline that does the same on the default branch is
[.woodpecker/pages.yml](https://codeberg.org/tarcisio/conan-flake/src/branch/main/.woodpecker/pages.yml).

### Switching publication on

<!-- publishing.SETUP.1 -->
<!-- publishing.SERVING.1 -->
<!-- publishing.SERVING.2 -->
<!-- publishing.CI.1 -->
<!-- publishing.CI.2 -->

These steps need administration rights on the Codeberg repository and on its
Woodpecker project, so they cannot be done from a checkout. Until they are, the
pipeline reports success and publishes nothing.

- [ ] **Register the webhook.** Repository settings &rarr; Webhooks &rarr; _Add
      webhook_ &rarr; type **Forgejo**, with
      **Target URL** `https://tarcisio.codeberg.page/conan-flake/` &mdash; which
      doubles as the address the site is served from &mdash; and
      **Branch filter** `pages`. This is what tells
      [git-pages](https://codeberg.org/git-pages/git-pages) to pull the branch
      when it is pushed.
- [ ] **Do not read a failed test delivery as a broken setup.** The
      "Test delivery" button fails by design; Codeberg's own documentation says
      so. Verify by pushing the branch and loading the site instead.
- [ ] **Create the push credential.** A Codeberg access token with write access
      to this repository, stored as a secret named exactly `codeberg_token` on
      this repository's Woodpecker project. `.woodpecker/pages.yml` reads it,
      and publishes nothing while it is empty.
- [ ] **Publish once**, with `just docs-publish` from a checkout. That first run
      is what creates the `pages` branch.
- [ ] **Let CI publish on every push.** Woodpecker resolves secrets while
      compiling a workflow and fails the whole pipeline when a step names a
      secret that does not exist, so the publishing step of
      `.woodpecker/pages.yml` is gated on `manual` and a step that names no
      secret keeps a push green. Once `codeberg_token` exists, a manual run of
      that pipeline publishes; to publish on every push to `main`, change the
      `pages` step's `when` to `- event: [push, manual]` and drop the
      `publication-status` step above it.
- [ ] **Verify.** Load <https://tarcisio.codeberg.page/conan-flake/>; content
      can take a few minutes to refresh. If it does not appear, ask git-pages
      what it deployed:

      ```sh
      curl https://tarcisio.codeberg.page/conan-flake/.git-pages/manifest.json
      ```

      A path the site does not carry is answered with the site's own `404.html`,
      which mdBook generates at the root of the output and links back into the
      sub-path the site is built for (`site-url` in `docs/book.toml`).

> [!NOTE]
> `.domains` files are obsolete: git-pages authorises custom domains through DNS
> `TXT` records instead, and a `codeberg.page` sub-path site needs neither.
