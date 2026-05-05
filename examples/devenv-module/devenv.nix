{ config
, inputs
, pkgs
, ...
}:
{
  name = "conan-flake-dev";

  # A single Conan configuration is supported.
  conan = {
    #
    enable = true;

    config = {
      # The base developer environment.
      # By default, this is pkgs.stdenv.
      # stdenv = pkgs.cudaPackages.backendStdenv;

      settings.base = {
        # gcc = {
        #   version = [ "15.2.0" ];
        # };
      };

      platformToolRequires = {
        cmake = pkgs.cmake.version;
      };

      devShell = {
        # Programs you want to make available in the shell.
        packages = [
          pkgs.cmake
        ];
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
