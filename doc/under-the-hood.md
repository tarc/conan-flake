# Under the hood

> \[!tip\] Under the hood
> `conan-flake` is based on [haskell-flake](https://github.com/srid/haskell-flake/)

In addition, compared to using plain nixpkgs, conan-flake supports:

- Auto-detection of requirements \[\[requirements|local packages\]\] based on `cabal.project` file (via [conan-parsers](https://github.com/srid/haskell-flake/tree/master/nix/haskell-parsers))

See #\[\[start\]\] for getting started with haskell-flake.
