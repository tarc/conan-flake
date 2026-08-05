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
          # `debug` is named after its attribute key, while `alt` overrides its
          # name with `my-profile` (`multiple-profiles.PROFILES.1`). The `-` in
          # the overridden name is intentional: profile names end up in
          # derivation names and attribute keys, so a name that is not a valid
          # shell identifier must keep working.
          debugKey = "debug";
          altKey = "alt";
          altName = "my-profile";

          # Distinguishing `[conf]` entry, per profile, used to prove profiles
          # are rendered independently of each other.
          confKey = "user.test:profile";

          cfg = config.conan;

          # The Conan profile name of every declared profile, `default`
          # included.
          profileNames = lib.mapAttrsToList (_: profile: profile.name) cfg.profiles;

          configuration = cfg.outputs.packages.configuration;

          # Profile file inside the generated configuration package.
          packagedProfile = name: "${configuration}/config/profiles/${name}";

          # Profile file inside the local Conan configuration directory.
          localProfile = name: "${cfg.configLocal}/profiles/${name}";

          forEachProfile = f: lib.concatMapStrings f profileNames;

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
                settings._.build_type = "Debug";
                conf.${confKey} = debugKey;
              };

              ${altKey} = {
                name = altName;
                settings._.build_type = "RelWithDebInfo";
                conf.${confKey} = altName;
              };
            };

            offline = true;

            checks = {
              # The key of each attribute set is considered the profile name,
              # but can be overridden by a `name` field if specified.
              "multiple-profiles.PROFILES.1" = {
                enable = true;
                drv = pureCheck "multiple-profiles.PROFILES.1" ''
                  echo "Checking profile naming..."

                  # The attribute key is the profile name by default:
                  test -f ${escapeShellArg (packagedProfile cfg.profiles.${debugKey}.name)}
                  test ${escapeShellArg cfg.profiles.${debugKey}.name} = ${escapeShellArg debugKey}

                  # ... and is overridden by the `name` option:
                  test ${escapeShellArg cfg.profiles.${altKey}.name} = ${escapeShellArg altName}
                  test -f ${escapeShellArg (packagedProfile cfg.profiles.${altKey}.name)}
                  grep -F ${escapeShellArg "${confKey}=${altName}"} \
                    ${escapeShellArg (packagedProfile cfg.profiles.${altKey}.name)}

                  # ... so the attribute key is not used as a profile file name:
                  test ! -e ${escapeShellArg (packagedProfile altKey)}
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

                  grep -F "build_type="${escapeShellArg cfg.final.profiles.default.settings._.build_type} \
                    ${escapeShellArg (localProfile "default")}
                  grep -F "compiler.cppstd="${
                    escapeShellArg cfg.final.profiles.default.settings.compiler."compiler.cppstd"
                  } \
                    ${escapeShellArg (localProfile "default")}
                  grep -F "compiler.libcxx="${
                    escapeShellArg cfg.final.profiles.default.settings.compiler."compiler.libcxx"
                  } \
                    ${escapeShellArg (localProfile "default")}
                  grep -F "cmake/"${escapeShellArg cfg.final.profiles.default.platformToolRequires.cmake} \
                    ${escapeShellArg (localProfile "default")}

                  # ... and nothing from the declared profiles leaks into it:
                  ! grep -F ${escapeShellArg confKey} ${escapeShellArg (localProfile "default")}
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
                  grep -F "build_type="${escapeShellArg cfg.final.profiles.default.settings._.build_type} \
                    ${escapeShellArg (packagedProfile "default")}

                  grep -F "build_type="${escapeShellArg cfg.final.profiles.${debugKey}.settings._.build_type} \
                    ${escapeShellArg (packagedProfile debugKey)}
                  grep -F ${escapeShellArg "${confKey}=${debugKey}"} \
                    ${escapeShellArg (packagedProfile debugKey)}

                  grep -F "build_type="${escapeShellArg cfg.final.profiles.${altKey}.settings._.build_type} \
                    ${escapeShellArg (packagedProfile altName)}
                  grep -F ${escapeShellArg "${confKey}=${altName}"} \
                    ${escapeShellArg (packagedProfile altName)}

                  # ... so no profile carries another profile's content:
                  ! grep -F ${escapeShellArg "${confKey}=${altName}"} \
                    ${escapeShellArg (packagedProfile debugKey)}
                  ! grep -F ${escapeShellArg "${confKey}=${debugKey}"} \
                    ${escapeShellArg (packagedProfile altName)}
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

                  ${forEachProfile (name: ''
                    ${getCommand cfg.package} profile list 2>&1 | grep -F ${escapeShellArg name}
                  '')}
                '';
              };
            };
          };
        };
    };
}
