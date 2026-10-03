---
paths:
  - "features/**/*.feature.yaml"
---

# Strict YAML in feature specs

A requirement's text is a YAML plain scalar, not free text. Two mistakes parse
fine under a lenient parser (e.g. Python's `yaml.safe_load`) but fail under the
stricter YAML 1.2 parser that actually validates specs (`@acai.sh/cli`'s bundled
`yaml` npm package):

- **A colon followed by a space (`: `) inside the value** is read as a nested
  mapping and fails with "Nested mappings are not allowed in compact mappings".
  Use ` - ` instead (this project's convention for an inline aside, e.g.
  `defaults.PROFILE.2`'s "... native option priority - an entry assigned...").
- **Starting the value with `'` or `"`** makes the parser read a quoted scalar,
  then fail on trailing text with "Unexpected scalar at node end". Use backticks
  for emphasis (`` `options` ``, not `'options'`) — the convention throughout.

Nix doesn't catch either (these files are in no `nix flake check`). The strict
`yaml` package is not resolvable from the repo (not in `docs/node_modules`, not
via `astro`; `@acai.sh/cli` bundles its own), so validate with a disposable
install in the session scratchpad, using the dev shell's `node`:

```sh
d=<session scratchpad>/yaml-check   # not /tmp
mkdir -p "$d" && (cd "$d" && npm install --silent yaml)
NODE_PATH="$d/node_modules" node -e "require('yaml').parse(require('fs').readFileSync(process.argv[1], 'utf8'), { strict: true })" path/to/x.feature.yaml
```
