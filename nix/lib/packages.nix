{ conanFlakeLib, ... }:
{
  conan = pkgs: pkgs.callPackage ../packages/conan/package.nix { };
  # The documentation site; see `nix/packages/docs`. site.BUILD.1
  docs = pkgs: pkgs.callPackage ../packages/docs/package.nix { };
  embedmd = pkgs: pkgs.callPackage ../packages/embedmd/package.nix { };
  mdsh_0_9_2 = pkgs: pkgs.callPackage ../packages/mdsh-0.9.2/package.nix { };
  mdsh_0_9_3 =
    pkgs:
    pkgs.callPackage ../packages/mdsh-0.9.3/package.nix {
      mdsh = conanFlakeLib.packages.mdsh_0_9_2 pkgs;
    };
  woodpecker-cli = pkgs: pkgs.callPackage ../packages/woodpecker/cli.nix { };
}
