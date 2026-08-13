{
  # Test: use conan-flake without devenv, via the `flake-parts` module only.
  inputs = {
    nixpkgs.url = "github:cachix/devenv-nixpkgs/12866ae2dddbc0ab8b329915f8072bb9c75bde89";
    flake-parts.url = "github:hercules-ci/flake-parts/f7c1a2d347e4c52d5fb8d10cb4d94b5884e546fb";
    conan-flake = { };
    infuse = {
      url = "git+https://codeberg.org/amjoseph/infuse.nix?rev=364ea18b5611b5fd6a6acd7151411b430a70e194";
      flake = false;
    };
  };
  outputs =
    inputs@{
      nixpkgs,
      flake-parts,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = nixpkgs.lib.systems.flakeExposed;
      imports = [
        inputs.conan-flake.flakeModule
      ];
      perSystem =
        {
          pkgs,
          config,
          lib,
          ...
        }:
        let
          inherit (lib) escapeShellArg;

          # Output of the single `conan create` run, kept so that every
          # assertion below observes the very same build.
          createLog = "conan-create.log";

          # Asserts no line of `file` contains the fixed string `string`.
          #
          # Spelled as an `if`, and never as `! grep ...`, because `set -e` is
          # specified to ignore the exit status of a pipeline negated by `!`,
          # which would turn the assertion into a no-op. `file` is asserted to
          # exist first, because `grep` exits 2 on a missing file, which the
          # `if` would read as "no match", and the pattern is passed with `-e`
          # so that a leading `-` cannot be taken for an option.
          lacksString = file: string: ''
            test -f ${escapeShellArg file}
            if grep -nF -e ${escapeShellArg string} -- ${escapeShellArg file}; then
              echo "unexpected match:" ${escapeShellArg string} ${escapeShellArg file} >&2
              exit 1
            fi'';
        in
        {
          conan = {
            profiles.default.settings = {
              "compiler.cppstd" = "23";
              build_type = "Release";
            };
            stdenv = pkgs.overrideCC (pkgs.llvmPackages.libcxxStdenv.override {
              targetPlatform.useLLVM = true;
              targetPlatform.linker = "lld";
            }) pkgs.llvmPackages.clangUseLLVM;
            remotes.local = {
              url = "./repo";
              local = true;
              allowedPackages = [ "hello-world/0.0.1.cci.20260428" ];
            };
            offline = true;
            checks.test = {
              enable = true;
              drv =
                inputs.conan-flake.lib.runCommandWithInSimulatedShell pkgs config.conan.stdenv
                  config.conan.outputs.devShell
                  config.conan.info.configRoot
                  "./config"
                  "llvm-flake-parts-test-conan-create"
                  { }
                  ''
                    (
                    set -x

                    # Run the package build once, keeping its output, and check
                    # its exit status on its own: a negated pipeline, or one
                    # ending in `grep`, would report the assertion's status
                    # instead of the build's.
                    if ! conan create . --build=missing > ${escapeShellArg createLog} 2>&1; then
                      cat ${escapeShellArg createLog} >&2
                      echo "conan create failed" >&2
                      exit 1
                    fi

                    # The package was built:
                    grep -F -e "example/0.0.1" -- ${escapeShellArg createLog}

                    # ... and the libc++/LLVM toolchain did not compile it
                    # against the libstdc++ ABI:
                    ${lacksString createLog "_GLIBCXX_USE_CXX11_ABI 1"}

                    touch $out
                    )
                  '';
            };
          };
          devShells.default = pkgs.mkShell {
            inputsFrom = [
              config.conan.outputs.devShell
            ];
          };
        };
    };
}
