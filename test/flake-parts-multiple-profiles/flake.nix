{
  # Test: multiple Conan profiles (feature `multiple-profiles`), via the
  # `flake-parts` module only.
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

      imports = [
        inputs.conan-flake.flakeModule
      ];

      systems = nixpkgs.lib.systems.flakeExposed;

      perSystem =
        {
          pkgs,
          config,
          lib,
          ...
        }:
        let
          inherit (lib) escapeShellArg;
          getCommand = package: baseNameOf (lib.getExe package);

          configLocal = "CONFIGLOCAL";
          conanHome = "./CONANHOME";

          # `default` is deliberately *not* declared: its presence is the proof
          # of `multiple-profiles.PROFILES.2`.
          #
          # Both `debug` and `my-profile` are named after their attribute key
          # (`multiple-profiles.PROFILES.1`). The `-` in the latter is
          # intentional: profile names end up in derivation names and
          # attribute keys, so a name that is not a valid shell identifier
          # must keep working.
          debugKey = "debug";
          altKey = "my-profile";

          # Distinguishing `[conf]` entry, per profile, used to prove profiles
          # are rendered independently of each other.
          confKey = "user.test:profile";

          cfg = config.conan;

          # The Conan profile name of every declared profile, `default`
          # included.
          profileNames = lib.attrNames cfg.profiles;

          configuration = cfg.outputs.packages.configuration;

          # Profile file inside the generated configuration package.
          packagedProfile = name: "${configuration}/config/profiles/${name}";

          # Profile file inside the local Conan configuration directory.
          localProfile = name: "${cfg.configLocal}/profiles/${name}";

          forEachProfile = f: lib.concatMapStrings f profileNames;

          # Asserts `line` is a line of its own in `file`.
          #
          # No `test -f` guard, unlike `lacksString` below: a missing `file`
          # makes `grep` exit 2, which is already a failure for a positive
          # assertion. The pattern is still passed with `-e` so that a leading
          # `-` cannot be taken for an option.
          hasLine = file: line: "grep -qxF -e ${escapeShellArg line} -- ${escapeShellArg file}";

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

          inSimulatedShell =
            name: command:
            inputs.conan-flake.lib.runCommandWithInSimulatedShell pkgs cfg.stdenv cfg.outputs.devShell
              cfg.info.configRoot
              "./config"
              name
              { }
              ''
                (
                set -x
                echo "Testing test/flake-parts-multiple-profiles (${name}) ..."

                ${command}

                touch $out
                )
              '';

          pureCheck =
            name: command:
            pkgs.runCommand name { } ''
              (
              set -euo pipefail
              set -x
              echo "Testing test/flake-parts-multiple-profiles (${name}) ..."

              ${command}

              touch $out
              )
            '';
        in
        {
          conan = {
            inherit configLocal conanHome;

            profiles = {
              ${debugKey} = {
                settings.build_type = "Debug";
                conf.${confKey} = debugKey;
              };

              ${altKey} = {
                settings.build_type = "RelWithDebInfo";
                conf.${confKey} = altKey;
              };
            };

            offline = true;

            checks = {
              # The key of each attribute set is considered the profile name.
              "multiple-profiles.PROFILES.1" = {
                enable = true;
                drv = pureCheck "multiple-profiles.PROFILES.1" ''
                  echo "Checking profile naming..."

                  # Each profile is named after its attribute key, dashes and
                  # all:
                  test -f ${escapeShellArg (packagedProfile debugKey)}
                  test -f ${escapeShellArg (packagedProfile altKey)}
                  ${hasLine (packagedProfile altKey) "${confKey}=${altKey}"}
                '';
              };

              # The default profile is named `default` and is automatically
              # included if not specified.
              "multiple-profiles.PROFILES.2" = {
                enable = true;
                drv = inSimulatedShell "multiple-profiles.PROFILES.2" ''
                  echo "Checking the automatically included default profile..."

                  # `default` is not declared by this configuration, yet it is
                  # generated and carries the conan-flake defaults:
                  test -e ${escapeShellArg (localProfile "default")}

                  ${hasLine (localProfile "default") "build_type=${cfg.final.profiles.default.settings.build_type}"}
                  ${hasLine (localProfile "default") "compiler.cppstd=${
                    cfg.final.profiles.default.settings."compiler.cppstd"
                  }"}
                  ${hasLine (localProfile "default") "compiler.libcxx=${
                    cfg.final.profiles.default.settings."compiler.libcxx"
                  }"}
                  ${hasLine (localProfile "default") "cmake/${cfg.final.profiles.default.platformToolRequires.cmake}"}

                  # ... and nothing from the declared profiles leaks into it:
                  ${lacksString (localProfile "default") confKey}
                '';
              };

              # Each profile named PROFILE results in a Conan profile PROFILE
              # being generated in the `config/profiles` directory of the output
              # configuration package `outputs.packages.configuration`.
              "multiple-profiles.PROFILES.3" = {
                enable = true;
                drv = pureCheck "multiple-profiles.PROFILES.3" ''
                  echo "Checking the generated configuration package..."

                  ${forEachProfile (name: ''
                    test -f ${escapeShellArg (packagedProfile name)}
                  '')}

                  # Each profile is rendered on its own, with its own content:
                  ${hasLine (packagedProfile "default") "build_type=${cfg.final.profiles.default.settings.build_type}"}

                  ${hasLine (packagedProfile debugKey) "build_type=${
                    cfg.final.profiles.${debugKey}.settings.build_type
                  }"}
                  ${hasLine (packagedProfile debugKey) "${confKey}=${debugKey}"}

                  ${hasLine (packagedProfile altKey) "build_type=${cfg.final.profiles.${altKey}.settings.build_type}"}
                  ${hasLine (packagedProfile altKey) "${confKey}=${altKey}"}

                  # ... so no profile carries another profile's content:
                  ${lacksString (packagedProfile debugKey) "${confKey}=${altKey}"}
                  ${lacksString (packagedProfile altKey) "${confKey}=${debugKey}"}
                '';
              };

              # This Conan PROFILE is linked to the `''${configLocal}/profiles/`
              # directory.
              "multiple-profiles.PROFILES.3-1" = {
                enable = true;
                drv = inSimulatedShell "multiple-profiles.PROFILES.3-1" ''
                  echo "Checking the links into the local configuration..."

                  ${forEachProfile (name: ''
                    test -L ${escapeShellArg (localProfile name)}
                    test "$(readlink ${escapeShellArg (localProfile name)})" \
                      = ${escapeShellArg (packagedProfile name)}
                  '')}

                  echo "Checking Conan knows about every profile..."

                  # `conan profile list` prints one bare profile name per line
                  # (its "Profiles found in the cache:" banner goes to stderr,
                  # which the `2>&1` folds in harmlessly), so the name is
                  # matched as a whole line here too.
                  #
                  # Deliberately not `grep -q`, unlike `hasLine` above: this is
                  # a pipeline out of the Python `conan` CLI, and `grep -q`
                  # exits on the first match, which can leave `conan` writing
                  # into a closed pipe. Today's three-line output fits the pipe
                  # buffer, so `conan` is done writing before that happens, but
                  # a longer profile list would let it die on `SIGPIPE` and
                  # `pipefail` would report that as a failure of this check.
                  # Consuming all the input costs nothing here and also puts the
                  # matched line in the build log, next to the `set -x` trace.
                  ${forEachProfile (name: ''
                    ${getCommand cfg.package} profile list 2>&1 | grep -xF -e ${escapeShellArg name}
                  '')}
                '';
              };
            };
          };
        };
    };
}
