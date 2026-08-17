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
mdsh --inputs docs/src/*.md
```

The sources of the site are the whole of that list: `README.md` is a pointer at
this site and carries no command-output block, so it is off
`programs.mdsh.includes` in
[dev/treefmt.nix](https://codeberg.org/tarcisio/conan-flake/src/branch/main/dev/treefmt.nix).
It does keep one embedded sample, which is why it is still named in the
`embedmd` command above.

<!-- authoring.COMMAND_OUTPUT.2 -->

> [!WARNING]
> Those commands _run_ the `examples/*` projects, and those resolve conan-flake
> from the published upstream rather than from the checkout. Between a breaking
> option change and the release that publishes it, the examples fail to evaluate
> and `mdsh` writes back **empty** blocks, deleting committed content. For the
> duration of that window, set
> `programs.mdsh.excludes = [ "docs/src/*.md" ]` in
> [dev/treefmt.nix](https://codeberg.org/tarcisio/conan-flake/src/branch/main/dev/treefmt.nix)
> &mdash; the same list `programs.mdsh.includes` carries there, so `mdsh` is
> then pointed at zero files, which turns it off without unwiring it and leaves
> the committed blocks untouched. Clear the exclude once the release is on
> `main`. `embedmd` is unaffected either way.

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

The pipeline that runs the same script from `main` is
[.woodpecker/pages.yml](https://codeberg.org/tarcisio/conan-flake/src/branch/main/.woodpecker/pages.yml).
A push to `main` that touches the sources the site is built from publishes it,
and the pipeline can still be run on demand, which is how the site is
republished without a commit. The checklist below is how that was set up.

When two publications race, the second push loses: its run fails on a rejected
push, and the site goes on carrying the other run's build until the next change
or a manual run.

### Switching publication on

<!-- publishing.SETUP.1 -->
<!-- publishing.SETUP.1-1 -->
<!-- publishing.SERVING.1 -->
<!-- publishing.SERVING.2 -->
<!-- publishing.CI.3 -->
<!-- publishing.CI.5 -->
<!-- publishing.CI.6 -->

These steps need administration rights on the Codeberg repository and on its
Woodpecker project, so they cannot be done from a checkout. All of them have
been taken here: the webhook and the `codeberg_token` secret are registered,
<https://tarcisio.codeberg.page/conan-flake/> serves this site from the `pages`
branch, and CI publishes it on every change to its sources on `main`. They are
kept because they are what a fork, or a move to another forge, has to repeat
&mdash; and a fork has to repeat them before its `pages` workflow runs at all:
the publishing step names `codeberg_token`, and a workflow whose secret
Woodpecker cannot resolve fails to compile rather than reporting that nothing
was published.

> [!IMPORTANT]
> Order matters between the fourth step and the last one. Woodpecker resolves a
> `from_secret:` while it _compiles_ the workflow, so a run whose event the
> secret does not list fails before any step starts. `codeberg_token` therefore
> has to be available at the `push` event **before** the commit that makes the
> `pages` step run on a push &mdash; otherwise that very push is the run that
> fails.

- [x] **Register the webhook.** Repository settings &rarr; Webhooks &rarr; _Add
      webhook_ &rarr; type **Forgejo**, with
      **Target URL** `https://tarcisio.codeberg.page/conan-flake/` &mdash; which
      doubles as the address the site is served from &mdash; and
      **Branch filter** `pages`. This is what tells
      [git-pages](https://codeberg.org/git-pages/git-pages) to pull the branch
      when it is pushed.
- [x] **Do not read a failed test delivery as a broken setup.** The
      "Test delivery" button fails by design; Codeberg's own documentation says
      so. Verify by pushing the branch and loading the site instead.
- [x] **Create the push credential.** A Codeberg access token with write access
      to this repository, belonging to the account the pipeline pushes as
      (`tarcisio`, or whatever `PAGES_USER` in `scripts/publish-pages-ci.sh`
      names), stored as a secret named exactly `codeberg_token` on this
      repository's Woodpecker project. `.woodpecker/pages.yml` reads it, and
      publishes nothing while it is empty.
- [x] **Allow that secret at both events the pipeline runs on.** Open the secret
      and tick **`push`** _and_ **`manual`** under
      "Available at the following events". Woodpecker offers a secret only to a
      run whose event the secret lists, and a new secret lists `push`, `tag` and
      `deployment` &mdash; so `manual` has to be added, and `push` has to be left
      ticked. It resolves secrets while compiling the workflow, before anything
      runs, so a missing event does not fail a step: it fails the whole run,
      with
      `secret "codeberg_token" is not allowed to be used with pipeline event "push"`
      (or `"manual"`). This is the one step of this checklist that cannot be
      taken from a checkout, and the one to take **before** the commit that
      turns publishing on, or that very push is the run that fails.
- [x] **Publish once**, with `just docs-publish` from a checkout. That first run
      is what creates the `pages` branch, and it uses your own push credentials
      rather than the secret.
- [x] **Publish from CI on demand.** Once `codeberg_token` exists and allows
      `manual`, run the `pages` pipeline of the `main` branch from Woodpecker's
      interface: that publishes the site, with no commit to make. This is still
      how the site is republished when the sources did not change.
- [x] **Let CI publish on every change.** `.woodpecker/pages.yml` has a single
      step, `pages`, which runs on `- event: [push, manual]`: a push to `main`
      touching the paths the workflow filters on publishes the site, and so does
      a run started by hand. There is no second, tokenless step beside it &mdash;
      on a push that one would run the publishing wrapper again without a
      credential and announce that nothing was published next to a successful
      publication. What keeps unrelated pushes from publishing is the workflow's
      own `when`, which was already filtering on `main` and on the site's
      sources. The ordering matters: the `codeberg_token` secret has to allow
      the `push` event **before** the commit that makes this change lands, or
      that push is compiled with a secret it may not read and fails before it
      starts.
- [x] **Verify.** Load <https://tarcisio.codeberg.page/conan-flake/>; content
      can take a few minutes to refresh. If it does not appear, ask git-pages
      what it deployed, with
      `curl https://tarcisio.codeberg.page/conan-flake/.git-pages/manifest.json`
      &mdash; the manifest names the repository, the branch and the commit it
      served the site from.

A path the site does not carry is answered with the site's own `404.html`, which
mdBook generates at the root of the output and links back into the sub-path the
site is built for (`site-url` in `docs/book.toml`).

> [!NOTE]
> `.domains` files are obsolete: git-pages authorises custom domains through DNS
> `TXT` records instead, and a `codeberg.page` sub-path site needs neither.
