# file: examples/standalone-submodule-with/default.nix
{
  lib,
  pkgs,
  inputs,
  ...
}:
let
  conan-flake = (
    fetchGit {
      url = "https://codeberg.org/tarcisio/conan-flake";
      name = "conan-flake";
      ref = "refs/branches/main";
      rev = "00526d2fd8a8162dae27e3bd257f90a7bdc42ab7";
      shallow = true;
    }
  );
  conanSubmodule =
    (import "${conan-flake}/nix/lib/lib.nix" { inherit inputs; }).conanFlakeLib.submoduleWith lib
      {
        modules = [
          {
            options.pkgs = lib.mkOption {
              default = pkgs;
              defaultText = lib.literalExpression "pkgs";
            };
            config.configRoot = ./.;
          }
        ];
      };
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
      profiles = {
        settings.compiler."compiler.cppstd" = "14";
        settings._.build_type = "Debug";
      };

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
