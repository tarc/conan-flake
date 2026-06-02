{
  inputs = {
    nixpkgs.url = "github:cachix/devenv-nixpkgs/rolling";
    conan-flake.url = "git+https://codeberg.org/tarcisio/conan-flake";
  };
  outputs = { self, nixpkgs, conan-flake, ... }:
    let
      eachSystem = nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed;

      perSystem = system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          stdenv = pkgs.stdenv;
          configuration = conan-flake.lib.evalConanConfig pkgs {
            configRoot = self;
            modules = [
              ({ pkgs, config, ... }: {

                # The base developer environment.
                # By default, this is pkgs.stdenv.
                # stdenv = pkgs.stdenv;

                settings.base = {
                  # gcc = {
                  #   version = [ "15.2.0" ];
                  # };
                };

                conf = {
                  "tools.cmake.cmaketoolchain:user_presets" = "";
                };

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
                # local-recipe-index remotes -- in which case the `url` is
                # taken as a relative path to the root of the configuration.
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
          checks.test = pkgs.runCommandWith
            {
              name = "standalone-test-conan-create";
              inherit stdenv;
              derivationArgs = { inherit (configuration.devShell) buildInputs nativeBuildInputs; };
            }
            ''
              (
              set -x
              ${configuration.devShell.shellHook}
              mkdir $out
              conan install ${self} -of $out --build=missing
              conan build ${self} -of $out --build=missing
              find $out/build -iname "example*" -type f -executable -exec "{}" ";" \
                | grep "example/0.0.1"
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
