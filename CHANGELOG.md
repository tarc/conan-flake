# Revision history for conan-flake

## 0.11.0 (Aug 18, 2026)

### Documentation

- The project's documentation is now a site, published at
  <https://tarcisio.codeberg.page/conan-flake/> and written in
  [mdBook](https://rust-lang.github.io/mdBook/) under `docs/`: a chapter per
  integration style (getting started, `flake-parts`, devenv, standalone with
  `evalConanConfig` and `submoduleWith`, LLVM/CUDA toolchains), plus templates,
  contributing, references and this revision history. It is built by
  `conan-flake.lib.packages.docs` (`just docs`, `just docs-serve`), asserted
  over by one check per requirement in `nix flake check ./dev`, and published to
  Codeberg Pages by `scripts/publish-pages.sh` (`just docs-publish`,
  `.woodpecker/pages.yml`).

- `README.md` is now a pointer at that site: what conan-flake is, one embedded
  configuration example, how to instantiate a template, a link per chapter, and
  the option reference. Every topic it used to carry is on the site; nothing was
  dropped. Its command-output blocks moved there with the prose, so `mdsh` is
  pointed at the site's sources alone and no longer runs over `README.md`
  (`embedmd` still does, for the one sample it kept).

- The site is now published by CI on every change to its sources on `main`: the
  `pages` step of `.woodpecker/pages.yml` runs on a push as well as on demand,
  and the tokenless step that used to keep such a push green while announcing
  that nothing was published is gone. The workflow's existing branch and path
  filters are what keep unrelated pushes from publishing, and a manual run still
  republishes the site without a commit. The `codeberg_token` secret has to be
  available at Woodpecker's `push` event for this, since secrets are resolved
  while the workflow is compiled; the activation checklist in the contributing
  chapter says so. For the same reason a fork now has to work through that
  checklist before its own `pages` workflow compiles at all, rather than getting
  a green run that announces that nothing was published.

## 0.10.0 (Aug 13, 2026)

### Bug Fixes

- `profiles.<name>.buildEnv` and `profiles.<name>.runEnv` are now merged with
  the conan-flake defaults and rendered from the final profile state, like every
  other profile section. They were the only two sections rendered straight from
  the profile's own values, which silently exempted them from the defaults
  merging and from the `null`-removal marker. Added the matching
  `defaults.profiles.buildEnv` and `defaults.profiles.runEnv` options (empty by
  default). An entry replaces the default entry carrying the same `name`, and
  setting its `value` to `null` removes that default entry; the merged defaults
  keep their relative order and come first. Rendered profiles are unchanged for
  configurations that set no environment defaults.

- Removed references to `proactive` from `claude.code.agents.*` (this property
  is going to be deprecated).

### Improvements

- Updated default Conan package to 2.31.2 version
- Added `profiles.<name>.options`, `profiles.<name>.toolRequires`,
  `profiles.<name>.replaceRequires`, `profiles.<name>.replaceToolRequires` and
  `profiles.<name>.platformRequires` options, rendering the Conan profile
  `[options]`, `[tool_requires]`, `[replace_requires]`,
  `[replace_tool_requires]` and `[platform_requires]` sections.
- Added the matching `defaults.profiles.*` options (empty by default), so every
  profile section can be given configuration-wide defaults and removed per
  profile by assigning `null` to an entry.

### Breaking Changes

- Flattened the Conan profile `[settings]` section into a single attribute set,
  removing the `compiler`/`_` split:
  - `profiles.<name>.settings.compiler.*` and `profiles.<name>.settings._.*`
    become `profiles.<name>.settings.*`;
  - `final.profiles.<name>.settings.compiler.*` and
    `final.profiles.<name>.settings._.*` become
    `final.profiles.<name>.settings.*`;
  - `defaults.profiles.settings.compiler.*` and `defaults.profiles.settings._.*`
    become `defaults.profiles.settings.*`.

  There is **no** alias and no deprecation period: the new `settings` option is
  a free-form attribute set that must accept an entry literally named
  `compiler`, so the old declared `compiler` sub-option cannot coexist with it
  at the same path. To migrate, merge the two sets into one, keeping the entry
  names exactly as Conan spells them (`compiler`, `compiler.cppstd`,
  `compiler.libcxx`, `compiler.version`, `arch`, `build_type`, `os`, ...).
  `null` still removes the corresponding default. For example,
  `settings.compiler."compiler.cppstd" = "17"; settings._.build_type = "Release";`
  becomes `settings."compiler.cppstd" = "17"; settings.build_type = "Release";`.

  The top-level `settings.compiler` option (the `settings_user.yml` producer) is
  a different, unrelated option and is **not** affected.

### Notes

- `dev/flake.lock` is now committed. The development flake declared its inputs
  by branch (`nixpkgs-unstable`, `devenv-nixpkgs/rolling`, and the unpinned
  `flake-parts`, `git-hooks`, `devenv`, `treefmt-nix`, `nix2container` and
  `mk-shell-bin`) with no lockfile, so the Woodpecker `dev` step resolved
  whatever each of them happened to point at when it ran, and two runs of the
  same commit could build different closures. Refresh the lock deliberately with
  `nix flake update ./dev`. This affects the development environment only:
  nothing under `nix/` is involved, and conan-flake consumers are unaffected.

- Generated Conan profile files now emit the `[settings]` section as a single
  alphabetically ordered run of entries instead of two consecutive groups
  (non-compiler entries first, then the `compiler*` ones). Anyone diffing
  generated profile files will see `os=` move past the `compiler*` entries; the
  set of rendered lines is unchanged, and Conan parses `[settings]` into a
  dictionary, so intra-section order carries no meaning.
- The `README.md` command-output blocks are regenerated against this release,
  with `examples/standalone-submodule-with/default.nix`'s `fetchGit` rev bumped
  to it and `mdsh` no longer excluded from `README.md` in `dev/treefmt.nix`.
  They now show the ten profile sections and the `[settings]` entries in one
  alphabetically ordered run: the same rendering change described above,
  observed end to end through a real Conan profile.
- Generated Conan profile files now contain all ten sections, ordered as
  `[settings]`, `[options]`, `[tool_requires]`, `[buildenv]`, `[runenv]`,
  `[conf]`, `[replace_requires]`, `[replace_tool_requires]`,
  `[platform_requires]` and `[platform_tool_requires]`. Anyone diffing generated
  configuration files will see the new (empty) sections and the changed section
  order.

## 0.9.0 (Aug 05, 2026)

### Improvements

- Added support for multiple Conan profiles (`profiles.<name>`), each one
  rendered as a `config/profiles/<name>` Conan profile and linked into
  `${configLocal}/profiles/`.
- Added `profiles.<name>.name` option to override the profile name.

### Breaking Changes

- Moved `profiles.*` options under `profiles.<name>.*` (`profiles.X` becomes
  `profiles.default.X`).
- Moved `final.profiles.*` options under `final.profiles.<name>.*`
  (`final.profiles.X` becomes `final.profiles.default.X`).

### Notes

- Until this release lands on `main` and the `conan-flake` pins used by the
  examples are bumped (`examples/standalone-submodule-with/default.nix`'s
  `fetchGit` rev, and the unlocked flake inputs of the other examples), do not
  run `treefmt`/`mdsh` against `README.md`: the pinned revisions still expose
  the old `profiles.*` interface, so the migrated examples fail to evaluate and
  `mdsh` empties the `README.md` command-output blocks. The committed
  `README.md` is the correct post-release state.

## 0.8.1 (Jul 31, 2026)

### Bug Fixes

- Fix autowiring of `packages` outputs.

### Improvements

- Added local package infrastructure.
- Added `devenv` project development integration (under `./dev/`).

## 0.8.0 (Jul 29, 2026)

### Improvements

- Added `nix/packages/conan/package.nix` to track Conan releases and tweak Conan
  CLI.
- Redirected the output of all `conan remote` commands to `stderr`.

### Breaking Changes

- Set `nix/packages/conan/package.nix` as default Conan package.

## 0.7.0 (Jul 21, 2026)

### Improvements

- Silence noisy `pushd`/`popd` during shell activation.
- Added `profile-show-wrapper`.
- Flush `profile-show-wrapper` output to avoid buffering issues.
- Added `pnameFromStdenvCc` and `versionFromStdenvCc` utility functions.
- Added `global.conf` support.
- Default `core.graph:compatibility_mode` to `optimized`.

## 0.6.1 (Jul 07, 2026)

### Improvements

- Added `create-lock-install-wrapper`.

## 0.6.0 (Jul 07, 2026)

### Improvements

- Added support to shared Conan home directory.
- Added wrapping infrastructure.

## 0.5.1 (Jun 30, 2026)

### Bug Fixes

- Fix exposing of `lib` utility functions for `flake-parts` module integration.

## 0.5.0 (Jun 29, 2026)

### Improvements

- Add `generators` option to `conan-flake`.
- Refactored and improved environment variable handling:
  - `CONAN_FLAKE_ROOT`: Root directory of the configuration.
  - `CONAN_FLAKE_HOME`: If there's a `homeDirectory` in the configuration, it
    will be appended to `CONAN_FLAKE_ROOT` and used as the home directory.
  - `CONAN_FLAKE_CONFIG`: `$CONAN_FLAKE_HOME/${configLocal}`
  - `CONAN_HOME`: `$CONAN_FLAKE_HOME/${conanHome}`

### Breaking Changes

- Refactored `lib` interface.

## 0.4.0 (Jun 13, 2026)

### Bug Fixes

- Fixed `flake-parts` docs: added missing `defaultText` for
  `defaults.devShell.tools` option.
- Fixed treefmt's project root configuration of `flake-parts` test.
- Excluded `./examples/devenv-module/devenv.nix` from dev treefmt settings.
- Fixed handling of root configuration path when setting local recipe index
  repos.
- Set `info.configRoot` option.
- Fixed tests to use `grep -F`.

### Improvements

- Improved docs on devenv integration.
- Added tests on overriding defaults.
- Trimmed embedded snippets in README (using veggiemonk's embedmd's PR:
  https://github.com/veggiemonk/embedmd/tree/feat/issue-47-directive-options).
- Added devenv integration example featuring local-recipe-index remote.
- Added `conf` option (to compose profiles [conf] section).
- Added `autoWire` option (initially supporting only `devShells` and mapping
  only the configuration).
- Added `buildEnv` option (to compose profiles [buildenv] section).
- Added `runEnv` option (to compose profiles [runenv] section).
- Added `final.devShell.tools` option to map the final state of `devShell.tools`
  after `defaults` resolution.
- Added CMake by default to `devShell.tools`.
- Added a `defaults.profiles.platformToolRequires` option and set a `cmake`
  attribute by default depending whether CMake is a required tool or not.
- `conan.stdenv.cc` added as a default tool.
- Added `final.profiles.platformToolRequires` option.
- Added `final.settings.compiler`, `defaults.settings.compiler` and
  `settings.compiler` options using `infuse` to merge and `filterAttrs` to
  filter out _nulled_ attributes.
- Added `profiles.settings`, `final.profiles.settings` and
  `defaults.profiles.settings` options.
- Added defaults for `arch`, `build_type` and `os` in
  `defaults.profiles.settings`.
- Added defaults and finals for `profiles.conf`.
- Added `profiles.settings.compiler`, `final.profiles.settings.compiler` and
  `defaults.profiles.settings.compiler` options.
- Whenever a LLVM toolchain is detected (with libcxx):
  - Set `defaults.profiles.conf."tools.build:compiler_executables"`
    appropriately.
  - Set `defaults.profiles.settings.compiler."compiler.libcxx"` to `"libc++"`.

### Breaking Changes

- Removed default `info` output command.
- Removed automatic mapping of `config.conan.outputs.packages`.
- Removed `platformToolRequires` option (`profiles.platformToolRequires` must be
  used instead).
- Removed the `buildEnv`, `runEnv` and `conf` options (keep only those in the
  `profiles` namespace).
- Removed `settings.base` option.
- Removed `arch`, `buildType` and `os` options; the `arch`, `build_type` and
  `os` `profiles.settings` must be used instead respectively.
- Removed `compiler`, `compilerCppStd`, `compilerLibCxx` and `compilerVersion`
  options. The following should be used as a replacement (only if necessary):
  - `profiles.settings.compiler."compiler"`;
  - `profiles.settings.compiler."compiler.cppstd"`;
  - `profiles.settings.compiler."compiler.libcxx"`;
  - `profiles.settings.compiler."compiler.version"`.

## 0.3.1 (May 29, 2026)

### Improvements

- Added `release.yml` workflow.
- Improved documentation.

## 0.3.0 (May 28, 2026)

### Improvements

- Added `defaults` option to track defaults (initially, this contains only
  `defaults.devShell.tools`).
- Improved tests.

### Breaking Changes

- Renamed the `devShell.package` option to `devShell.tools` and changed its type
  to package set.

## 0.2.0 (May 25, 2026)

### Breaking Changes

- Removed the `devShell.apple.sdk` option.

## 0.1.0 (May 05, 2026)
