# Default options

conan-flake provides sensible defaults for various options. See [defaults.nix].

{#override}

## Overriding defaults

{#packages}

### Overriding requirements

This example shows how to specify \[\[requirements\]\]# manually.

```nix
{
  conanProject = {
    # Specify local packages manually
    defaults.packages = {
      foo.version = "1.0.0";
    };
  };
}
```

[defaults.nix]: https://github.com/tarc/conan-flake/blob/master/nix/modules/project/defaults.nix
