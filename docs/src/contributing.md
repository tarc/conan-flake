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

> [!NOTE]
> Option documentation is generated from the module options' own `description`
> and `example` attributes, so an option is documented by writing those &mdash;
> never by transcribing them into this site, which would silently go stale.

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
matches its example project fails the `docs.embedmd` check in CI.

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
> `settings.formatter.mdsh.excludes = [ "README.md" "docs/src/*" ]` in
> [dev/treefmt.nix](https://codeberg.org/tarcisio/conan-flake/src/branch/main/dev/treefmt.nix):
> `mdsh` is then pointed at zero files, which turns it off without unwiring it
> and leaves the committed blocks untouched. Clear the exclude once the release
> is on `main`. `embedmd` is unaffected either way.
