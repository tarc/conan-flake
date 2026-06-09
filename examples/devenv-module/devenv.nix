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
        # [settings]
        # build_type=Debug
        # compiler.cppstd=14

        # [platform_tool_requires]
        # cmake/X.Y.Z

        # Corresponding options:
        # {
          buildType = "Debug";
          compilerCppStd = "14";

          profiles.platformToolRequires = {
            cmake = pkgs.cmake.version;
          };

          devShell = {
            # Programs you want to make available in the shell:
            tools = { inherit (pkgs) cmake; };
          };
        # }
        # devShell
      };
    };
  };
}
