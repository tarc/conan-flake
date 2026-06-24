# file: examples/standalone/flake.nix
{
  inputs = {
    nixpkgs.url = "github:cachix/devenv-nixpkgs/rolling";
    conan-flake.url = "git+https://codeberg.org/tarcisio/conan-flake";
  };

  outputs =
    { self
    , nixpkgs
    , conan-flake
    , ...
    }:
    let
      eachSystem = nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed;
      configLocal = "CONFIGLOCAL";
      conanHome = "CONANHOME";

      perSystem =
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          inherit (pkgs.lib) escapeShellArg;

          configuration = conan-flake.lib.evalConanConfig pkgs {

            configRoot = self;

            modules = [
              ({ pkgs, ... }: {
                inherit configLocal conanHome;

                profiles = {
                  settings.compiler."compiler.cppstd" = "17";

                  settings.rest.build_type = "Release";

                  # This should be set whenever CMakeToolchain is being used and
                  # the `CMakeUserPresets.json` file should not be created on the
                  # Conan package source_folder (wich, in this case, is the same
                  # as `conan.configRoot` and lies on the Nix store, so will
                  # trigger an error):
                  conf = {
                    "tools.cmake.cmaketoolchain:user_presets" =
                      "{{ os.path.join(os.getenv(\"out\"), \"CMakeUserPresets.json\") }}";
                  };
                };

                devShell = {
                  # Programs you want to make available in the shell:
                  tools = { inherit (pkgs) just; };
                };

                # It's possible to specify Conan remotes explicitly, including
                # local-recipe-index remotes -- in which case the `url` is
                # taken as a relative path to the root of the configuration:
                remotes.local = {
                  url = "./repo";
                  local = true;
                  allowedPackages = [
                    "hello-world/0.0.1.cci.20260428"
                  ];
                };

                # Enable only local remotes (i.e. only of local-recipe-index type):
                offline = true;
              })
            ];
          };
        in
        {
          packages = configuration.packages;
          devShells.default = configuration.devShell;
          checks.test =
            pkgs.runCommandWith
              {
                name = "standalone-test-conan-install-build";
                inherit (pkgs) stdenv;
                derivationArgs = { inherit (configuration.devShell) buildInputs nativeBuildInputs; };
              }
              ''
                (
                set -x
                mkdir $out
                ${configuration.devShell.shellHook}
                echo "CONAN_FLAKE_ROOT:''${CONAN_FLAKE_ROOT@Q}" | grep -F "CONAN_FLAKE_ROOT:'${escapeShellArg self}'"
                echo "CONAN_FLAKE_HOME:''${CONAN_FLAKE_HOME@Q}" | grep -F "CONAN_FLAKE_HOME:''${PWD@Q}"
                echo "CONAN_FLAKE_CONFIG:''${CONAN_FLAKE_CONFIG@Q}" | grep -F "CONAN_FLAKE_CONFIG:'$(realpath "$PWD/"${escapeShellArg configLocal})'"
                echo "CONAN_HOME:''${CONAN_HOME@Q}" | grep -F "CONAN_HOME:'$(realpath "$PWD/"${escapeShellArg conanHome})'"
                conan install ${self} -of $out --build=missing
                conan build ${self} -of $out --build=missing
                find $out/build -iname "example*" -type f -executable -exec "{}" ";" \
                  | grep -F "example/0.0.1"
                )
              '';
        };

      systemOutputs = eachSystem perSystem;
    in
    {
      packages = nixpkgs.lib.mapAttrs (_: s: s.packages) systemOutputs;
      devShells = nixpkgs.lib.mapAttrs (_: s: s.devShells) systemOutputs;
      checks = nixpkgs.lib.mapAttrs (_: s: s.checks) systemOutputs;
    };
}
