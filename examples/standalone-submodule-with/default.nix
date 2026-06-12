# file: examples/standalone-submodule-with/default.nix
{ lib, pkgs, config, ... }:
let
  conan-flake = (builtins.fetchGit {
    url = "https://codeberg.org/tarcisio/conan-flake";
    name = "conan-flake";
    ref = "refs/branches/main";
    rev = "34a77b745ebbc130a3d2e8d0566644af709c1649";
    shallow = true;
  });
  conanSubmodule = (import "${conan-flake}/nix/lib").submoduleWith pkgs { configRoot = ./.; };
in
{
  options = {
    conan = lib.mkOption {
      type = conanSubmodule;
      description = "Conan configuration";
      default = { };
    };
  };

  config = {
    conan = {
      profiles.settings.build_type = "Debug";
      compilerCppStd = "14";

      devShell = {
        tools = { inherit (pkgs) just; };
      };

      remotes.local = {
        url = "./repo";
        local = true;
        allowedPackages = [ "hello-world/0.0.1.cci.20260428" ];
      };

      offline = true;
    };
  };
}
