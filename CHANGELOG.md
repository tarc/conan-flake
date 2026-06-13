# Revision history for conan-flake

## 0.4.0 (Jun 13, 2026)

### Bug Fixes

- Fixed `flake-parts` docs: added missing `defaultText` for `defaults.devShell.tools` option.
- Fixed treefmt's project root configuration of `flake-parts` test.
- Excluded `./examples/devenv-module/devenv.nix` from dev treefmt settings.
- Fixed handling of root configuration path when setting local recipe index repos.
- Set `info.configRoot` option.
- Fixed tests to use `grep -F`.

### Improvements

- Improved docs on devenv integration.
- Added tests on overriding defaults.
- Trimmed embedded snippets in README (using veggiemonk's embedmd's PR: https://github.com/veggiemonk/embedmd/tree/feat/issue-47-directive-options).
- Added devenv integration example featuring local-recipe-index remote.
- Added `conf` option (to compose profiles [conf] section).
- Added `autoWire` option (initially supporting only `devShells` and mapping only the configuration).
- Added `buildEnv` option (to compose profiles [buildenv] section).
- Added `runEnv` option (to compose profiles [runenv] section).
- Added `final.devShell.tools` option to map the final state of `devShell.tools` after `defaults` resolution.
- Added CMake by default to `devShell.tools`.
- Added a `defaults.profiles.platformToolRequires` option and set a `cmake` attribute by default depending whether CMake is a required tool or not.
- `conan.stdenv.cc` added as a default tool.
- Added `final.profiles.platformToolRequires` option.
- Added `final.settings.compiler`, `defaults.settings.compiler` and `settings.compiler` options using `infuse` to merge and `filterAttrs` to filter out _nulled_ attributes.
- Added `profiles.settings`, `final.profiles.settings` and `defaults.profiles.settings` options.
- Added defaults for `arch`, `build_type` and `os` in `defaults.profiles.settings`.
- Added defaults and finals for `profiles.conf`.
- Added `profiles.settings.compiler`, `final.profiles.settings.compiler` and `defaults.profiles.settings.compiler` options.
- Whenever a LLVM toolchain is detected (with libcxx):
  - Set `defaults.profiles.conf."tools.build:compiler_executables"` appropriately.
  - Set `defaults.profiles.settings.compiler."compiler.libcxx"` to `"libc++"`.

### Breaking Changes

- Removed default `info` output command.
- Removed automatic mapping of `config.conan.outputs.packages`.
- Removed `platformToolRequires` option (`profiles.platformToolRequires` must be used instead).
- Removed the `buildEnv`, `runEnv` and `conf` options (keep only those in the `profiles` namespace).
- Removed `settings.base` option.
- Removed `arch`, `buildType` and `os` options; the `arch`, `build_type` and `os` `profiles.settings` must be used instead respectively.
- Removed `compiler`, `compilerCppStd`, `compilerLibCxx` and `compilerVersion` options. The following should be used as a replacement (only if necessary):
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

- Added `defaults` option to track defaults (initially, this contains only `defaults.devShell.tools`).
- Improved tests.

### Breaking Changes

- Renamed the `devShell.package` option to `devShell.tools` and changed its type to package set.

## 0.2.0 (May 25, 2026)

### Breaking Changes

- Removed the `devShell.apple.sdk` option.

## 0.1.0 (May 05, 2026)

- Initial release
