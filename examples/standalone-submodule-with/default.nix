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
      rev = "29fc813f278edf99a59f2553501418e908103d1f";
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
      profiles.default = {
        settings.build_type = "Debug";
        settings."compiler.cppstd" = "14";
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
