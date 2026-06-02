# file: examples/devenv-module-recipe/devenv.nix
{ config
, inputs
, pkgs
, ...
}:
{
  name = "conan-flake-dev";

  # devenv languages.cplusplus option:
  # {
    languages.cplusplus = {
      enable = true;

      conan = {
        enable = true;
        install.enable = true;

        config = {
          buildType = "Release";
          compilerCppStd = "17";

          # It's possible to specify Conan remotes explicitly, including
          # local-recipe-index remotes, in which case the `url` is taken as a
          # relative path to the root of the configuration:
          remotes.local = {
            url = "./repo";
            local = true;
            allowedPackages = [
              "hello-world/0.0.1.cci.20260428"
            ];
          };

          # Enable only local remotes (i.e. only of local-recipe-index type):
          offline = true;
        };
      };
    };
  # }
  # languages.cplusplus
}
