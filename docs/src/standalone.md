# Standalone

<!-- site.GUIDES.4 -->

Although conan-flake is presented as a [`flake-parts`](./flake-parts.md) module,
there is a subset of its options that can be imported independently, directly
into any Nix code. This use case is supported by two helper functions, exposed
in the `lib` namespace of the flake defined by this repository:
[`evalConanConfig`](./standalone-eval-conan-config.md) and
[`submoduleWith`](./standalone-submodule-with.md).

To use these functions, add conan-flake to your flake inputs:

[embedmd]:# (./.examples/standalone-eval-conan-config/flake.nix nix !/.*{ inputs/ !/.*inputs }/ s/# {/{/ s/# }/}/ dedent)
```nix
{
  inputs = {
    nixpkgs.url = "github:cachix/devenv-nixpkgs/rolling";

    # Add this:
    conan-flake.url = "git+https://codeberg.org/tarcisio/conan-flake";
  };
  # ...
}
```

Now `conan-flake.lib.evalConanConfig` can be used to configure, for each system
supported, a Conan configuration and output a _devShell_ and a _check_ command.
With this schema in place:

[embedmd]:# (./.examples/standalone-eval-conan-config/flake.nix nix !/.*{ outputs/ !/.*outputs }/ s/#  // dedent)
```nix
{
  # ...
  outputs = { self, nixpkgs, conan-flake, ... }:
    let
      eachSystem = nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed;

      # See below for the actual `perSystem` function definition:
      perSystem = system:
        let
          # ...
          configuration = conan-flake.lib.evalConanConfig pkgs (
            # ...
          );
        in
        {
          devShells = {
            # ...
          };
          checks = {
            # ...
          };
        };
      systemOutputs = eachSystem perSystem;
    in
    {
      devShells = nixpkgs.lib.mapAttrs (_: s: s.devShells) systemOutputs;
      checks = nixpkgs.lib.mapAttrs (_: s: s.checks) systemOutputs;
    };
}
```

The two chapters that follow fill in the `perSystem` function, one with each
helper:

- [`conan-flake.lib.evalConanConfig`](./standalone-eval-conan-config.md)
  evaluates a configuration directly.
- [`conan-flake.lib.submoduleWith`](./standalone-submodule-with.md) embeds the
  same options as a submodule of a larger option tree &mdash; including, with no
  flakes at all, from a plain `default.nix`.

> [!WARNING]
> There's still no support for the automatic nixification of `conanfile.py`
> package definitions;[^1] the conan-flake module is about the Conan
> _configuration_ side of things, that is: profiles, settings, remotes...

[^1]: Or even of `conanfile.txt`, for that matter.

<!-- site.OPTIONS_REFERENCE.1 -->

The options accepted by both helpers are the ones documented in the
[option reference](https://flake.parts/options/conan-flake.html) (the
`perSystem.conan.*` entries, minus their `perSystem.conan` prefix).
