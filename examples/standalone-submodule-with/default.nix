# file: examples/standalone-submodule-with/default.nix
{ lib, pkgs, config, ... }:
let
  conan-flake = (builtins.fetchGit {
    url = "https://codeberg.org/tarcisio/conan-flake";
    name = "conan-flake";
    ref = "refs/branches/main";
    rev = "886d37706b9b71e895a8fc3cc59e1449bc0a7057";
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
      buildType = "Debug";
      compilerCppStd = "14";

      platformToolRequires = {
        cmake = pkgs.cmake.version;
      };

      devShell = {
        tools = { inherit (pkgs) cmake just; };
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
