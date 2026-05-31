# Revision history for conan-flake

## X.Y.Z (unreleased)

### Bug Fixes

- Fixed `flake-parts` docs: added missing `defaultText` for `defaults.devShell.tools` option.
- Fixed treefmt's project root configuration of `flake-parts` test.

### Improvements

- Improved docs on devenv integration.
- Added tests on overriding defaults.
- Trimmed embedded snippets in README (using veggiemonk's embedmd's PR: https://github.com/veggiemonk/embedmd/tree/feat/issue-47-directive-options)

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
