# file: examples/devenv-module/devenv.nix
{ config
, inputs
, pkgs
, ...
}:
{
  name = "conan-flake-dev";

  languages.cplusplus = {
    enable = true;

    conan = {
      enable = true;
      install.enable = true;

      config = {
        # The base developer environment:
        # stdenv = pkgs.cudaPackages.backendStdenv;
        # by default, this is config.stdenv.

        # Profile properties:
        #
        # [settings]
        # build_type=Debug
        # compiler.cppstd
        #
        # [platform_tool_requires]
        # cmake/X.Y.Z

        buildType = "Debug";
        compilerCppStd = "14";

        platformToolRequires = {
          cmake = pkgs.cmake.version;
        };

        devShell = {
          # Programs you want to make available in the shell.
          tools = {
            inherit (pkgs) cmake;
          };
        };

        # It's possible to specify Conan remotes explicitly, including
        # local-recipe-index remotes -- in which case the `url` is taken as a
        # relative path to the root of the configuration.
        # remotes.local = {
        #   url = "./repo";
        #   local = true;
        #   allowedPackages = [
        #     "hello-world/0.0.1.cci.20260428"
        #   ];
        # };

        # Enable only local remotes (i.e. only of local-recipe-index type):
        # offline = true;
      };
    };
  };

  packages = [ pkgs.just ];

  treefmt = {
    enable = true;
    config = {
      programs = {
        nixpkgs-fmt.enable = true;
        cmake-format.enable = true;
      };
    };
  };
}
