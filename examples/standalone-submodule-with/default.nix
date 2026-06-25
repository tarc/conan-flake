# file: examples/standalone-submodule-with/default.nix
{
  lib,
  pkgs,
  ...
}:
let
  conan-flake = (
    fetchGit {
      url = "https://codeberg.org/tarcisio/conan-flake";
      name = "conan-flake";
      ref = "refs/branches/main";
      rev = "d56f1c1916f9b6348c090aeac9ab1e7b808f9540";
      shallow = true;
    }
  );
  conanSubmodule = (import "${conan-flake}/nix/lib").submoduleWith lib {
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
        settings.rest.build_type = "Debug";
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
