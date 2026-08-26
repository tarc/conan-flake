# Assertions over the built documentation site, one derivation per ACID.
#
# `dev/flake.nix` wires whatever this file returns into `nix flake check ./dev`,
# which is what makes the site's build, its sub-path behaviour, its publishing
# and the `README.md` pointing at it a CI failure when they regress.
#
# The set is empty for the moment: the previous checks asserted against mdBook's
# `book.toml`, `SUMMARY.md` and rendered artifacts (`toc.html`,
# `searchindex*.js`), none of which the Astro/Starlight build produces, so they
# could not survive the swap. They are being rewritten against the new output
# and re-wired here; the wiring on both sides — `docsChecks` in
# `nix/lib/default.nix` and the `checks = docsChecks // { ... }` merge in
# `dev/flake.nix` — is left in place so that re-wiring them is a change to this
# file alone. Their previous text is recoverable with
# `git show main:nix/packages/docs/checks/{common,site,publishing,readme}.nix`.
#
# Building the site is itself a check (`checks.docs` in `dev/flake.nix`), so
# `nix flake check ./dev` still fails when the site stops building.
#
# site.BUILD.3
{ ... }:
{ }
