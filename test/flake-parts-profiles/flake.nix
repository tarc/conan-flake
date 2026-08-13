{
  # Test: the Conan profile and the profile file it is rendered into (feature
  # `profile`), via the `flake-parts` module only.
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
          inherit (lib) boolToString escapeShellArg;

          configLocal = "CONFIGLOCAL";
          conanHome = "./CONANHOME";

          # The `default` profile carries every section of the profile file,
          # while `nulls` removes defaults from it.
          nullsKey = "nulls";

          # A settings entry the conan-flake defaults also define, declared here
          # with a different value so that the rendered file can be told apart
          # from the defaults.
          cppstdKey = "compiler.cppstd";
          cppstdValue = "17";

          # `op = "="` is the plain `name=value` rendering; the remaining Conan
          # operators are an extension of the same shape.
          buildEnvKey = "BUILD_ASSIGN";
          buildEnvValue = "assigned";
          buildEnvPrependKey = "BUILD_FLAG";
          buildEnvPrependValue = "--IBF=Value";

          runEnvKey = "RUN_ASSIGN";
          runEnvValue = "assigned";
          runEnvPathKey = "LD_RUN_PATH";
          runEnvPathValue = "/my/path";

          # A user-defined configuration variable: free-form, so that the
          # rendered profile stays one Conan itself accepts.
          confKey = "user.conan_flake:some_property";
          confValue = "some_value";

          optionsKey = "mylib/*:shared";
          optionsValue = "True";

          toolRequiresKey = "tool1";
          toolRequiresValue = "0.1@user/channel";

          # Both sides of a replacement are complete Conan references or
          # reference patterns.
          replaceRequiresKey = "zlib/1.2.12";
          replaceRequiresValue = "zlib/[*]";

          replaceToolRequiresKey = "7zip/*";
          replaceToolRequiresValue = "7zip/system";

          platformRequiresKey = "dlib";
          platformRequiresValue = "1.3.22";

          # A platform requirement conan-flake ships no default for, declared
          # here as a configuration-wide default so that the new sections can be
          # observed going through the defaults/final merge.
          defaultPlatformRequiresKey = "zlib";
          defaultPlatformRequiresValue = "1.2.11";

          cfg = config.conan;

          configuration = cfg.outputs.packages.configuration;

          # Profile file inside the generated configuration package.
          packagedProfile = name: "${configuration}/config/profiles/${name}";

          # Profile file inside the local Conan configuration directory.
          localProfile = name: "${cfg.configLocal}/profiles/${name}";

          defaultProfile = packagedProfile cfg.profiles.default.name;
          nullsProfile = packagedProfile cfg.profiles.${nullsKey}.name;

          # Asserts `line` is a line of its own in `file`.
          #
          # No `test -f` guard, unlike `lacksMatch` below: a missing `file`
          # makes `grep` exit 2, which is already a failure for a positive
          # assertion. The pattern is still passed with `-e` so that a leading
          # `-` cannot be taken for an option.
          hasLine = file: line: "grep -qxF -e ${escapeShellArg line} -- ${escapeShellArg file}";

          # Asserts no line of `file` matches the (extended) regex `pattern`.
          #
          # Spelled as an `if`, and never as `! grep ...`, because `set -e` is
          # specified to ignore the exit status of a pipeline negated by `!`,
          # which would turn the assertion into a no-op. `file` is asserted to
          # exist first, because `grep` exits 2 on a missing file, which the
          # `if` would read as "no match", and the pattern is passed with `-e`
          # so that a leading `-` cannot be taken for an option.
          lacksMatch = file: pattern: ''
            test -f ${escapeShellArg file}
            if grep -nE -e ${escapeShellArg pattern} -- ${escapeShellArg file}; then
              echo "unexpected match:" ${escapeShellArg pattern} ${escapeShellArg file} >&2
              exit 1
            fi'';

          # Asserts every attribute of `attrs` has a line of its own in `file`,
          # rendered as `name<sep>value`.
          hasEntries =
            file: sep: attrs:
            lib.concatLines (lib.mapAttrsToList (name: value: hasLine file "${name}${sep}${value}") attrs);

          # Asserts the `header` section of `file` holds exactly `count`
          # non-blank lines, that is, one line per rendered entry and nothing
          # else.
          #
          # `awk` is the assertion itself, and never `test "$(... | wc -l)" -eq
          # N`, because a command substitution discards the exit status of what
          # it runs (`pipefail` does not reach inside it): a missing `file` or a
          # failing `awk` would then be read as "the section is empty" and pass
          # vacuously for `count = 0`. Here a missing `file` is `awk`'s own exit
          # 2, so no `test -f` is needed, consistent with `hasLine` above. The
          # `count = 0` case is exact too: `lines` is only ever compared, and an
          # uninitialised `awk` variable compares equal to `0`.
          hasBodyLines = file: header: count: ''
            awk -v header=${escapeShellArg header} -v expected=${escapeShellArg (toString count)} '
              $0 == header { inside = 1; next }
              /^\[.*\]$/ { inside = 0 }
              inside && NF { lines++ }
              END {
                if (lines != expected) {
                  printf "expected %d body line(s) in %s, got %d\n", expected, header, lines > "/dev/stderr"
                  exit 1
                }
              }
            ' ${escapeShellArg file}'';

          # Asserts an eval-time (Nix) fact, so that a check cannot silently
          # pass on a configuration that no longer holds it.
          nixFact = fact: "test ${escapeShellArg (boolToString fact)} = true";

          # A conan-flake configuration evaluated on its own, used to observe
          # evaluation behaviour without disturbing this flake's own
          # configuration.
          evalConan = module: (inputs.conan-flake.lib.evalConanConfig pkgs module).config;

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
                echo "Testing test/flake-parts-profiles (${name}) ..."

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
              echo "Testing test/flake-parts-profiles (${name}) ..."

              ${command}

              touch $out
              )
            '';
        in
        {
          conan = {
            inherit configLocal conanHome;

            defaults.profiles.platformRequires.${defaultPlatformRequiresKey} = defaultPlatformRequiresValue;

            profiles = {
              default = {
                settings = {
                  compiler = {
                    ${cppstdKey} = cppstdValue;
                    "compiler.libcxx" = "libstdc++11";
                  };
                  _.build_type = "Debug";
                };

                buildEnv = [
                  {
                    name = buildEnvKey;
                    value = buildEnvValue;
                  }
                  {
                    name = buildEnvPrependKey;
                    op = "=+";
                    value = buildEnvPrependValue;
                  }
                ];

                runEnv = [
                  {
                    name = runEnvKey;
                    value = runEnvValue;
                  }
                  {
                    name = runEnvPathKey;
                    op = "+=(path)";
                    value = runEnvPathValue;
                  }
                ];

                conf = {
                  ${confKey} = confValue;
                };

                options = {
                  ${optionsKey} = optionsValue;
                };

                toolRequires = {
                  ${toolRequiresKey} = toolRequiresValue;
                };

                replaceRequires = {
                  ${replaceRequiresKey} = replaceRequiresValue;
                };

                replaceToolRequires = {
                  ${replaceToolRequiresKey} = replaceToolRequiresValue;
                };

                platformRequires = {
                  ${platformRequiresKey} = platformRequiresValue;
                };
              };

              # Removes conan-flake defaults from this profile only.
              ${nullsKey} = {
                settings.compiler = {
                  ${cppstdKey} = null;
                };
                platformToolRequires.cmake = null;
                platformRequires.${defaultPlatformRequiresKey} = null;
              };
            };

            offline = true;

            checks = {
              "profile.SETTINGS.1" = {
                enable = true;
                drv = pureCheck "profile.SETTINGS.1" ''
                  echo "Checking the settings section header..."

                  ${hasLine defaultProfile "[settings]"}
                '';
              };

              "profile.SETTINGS.2" = {
                enable = true;
                drv = pureCheck "profile.SETTINGS.2" ''
                  echo "Checking the settings section entries..."

                  ${hasEntries defaultProfile "=" cfg.final.profiles.default.settings._}
                  ${hasEntries defaultProfile "=" cfg.final.profiles.default.settings.compiler}

                  # ... one line per entry and nothing else:
                  ${hasBodyLines defaultProfile "[settings]" (
                    lib.length (
                      lib.attrNames cfg.final.profiles.default.settings._
                      ++ lib.attrNames cfg.final.profiles.default.settings.compiler
                    )
                  )}
                '';
              };

              "profile.OPTIONS.1" = {
                enable = true;
                drv = pureCheck "profile.OPTIONS.1" ''
                  echo "Checking the options section header..."

                  ${hasLine defaultProfile "[options]"}
                '';
              };

              "profile.OPTIONS.2" = {
                enable = true;
                drv = pureCheck "profile.OPTIONS.2" ''
                  echo "Checking the options section entries..."

                  ${hasEntries defaultProfile "=" cfg.final.profiles.default.options}

                  # ... one line per entry and nothing else:
                  ${hasBodyLines defaultProfile "[options]" (
                    lib.length (lib.attrNames cfg.final.profiles.default.options)
                  )}
                '';
              };

              "profile.TOOL_REQUIRES.1" = {
                enable = true;
                drv = pureCheck "profile.TOOL_REQUIRES.1" ''
                  echo "Checking the tool_requires section header..."

                  ${hasLine defaultProfile "[tool_requires]"}
                '';
              };

              "profile.TOOL_REQUIRES.2" = {
                enable = true;
                drv = pureCheck "profile.TOOL_REQUIRES.2" ''
                  echo "Checking the tool_requires section entries..."

                  ${hasEntries defaultProfile "/" cfg.final.profiles.default.toolRequires}

                  # ... one line per entry and nothing else:
                  ${hasBodyLines defaultProfile "[tool_requires]" (
                    lib.length (lib.attrNames cfg.final.profiles.default.toolRequires)
                  )}
                '';
              };

              "profile.BUILDENV.1" = {
                enable = true;
                drv = pureCheck "profile.BUILDENV.1" ''
                  echo "Checking the buildenv section header..."

                  ${hasLine defaultProfile "[buildenv]"}
                '';
              };

              "profile.BUILDENV.2" = {
                enable = true;
                drv = pureCheck "profile.BUILDENV.2" ''
                  echo "Checking the buildenv section entries..."

                  ${hasLine defaultProfile "${buildEnvKey}=${buildEnvValue}"}

                  # ... and the Conan operators extending the rendering:
                  ${hasLine defaultProfile "${buildEnvPrependKey}=+${buildEnvPrependValue}"}

                  # ... one line per entry and nothing else:
                  ${hasBodyLines defaultProfile "[buildenv]" (lib.length cfg.profiles.default.buildEnv)}
                '';
              };

              "profile.RUNENV.1" = {
                enable = true;
                drv = pureCheck "profile.RUNENV.1" ''
                  echo "Checking the runenv section header..."

                  ${hasLine defaultProfile "[runenv]"}
                '';
              };

              "profile.RUNENV.2" = {
                enable = true;
                drv = pureCheck "profile.RUNENV.2" ''
                  echo "Checking the runenv section entries..."

                  ${hasLine defaultProfile "${runEnvKey}=${runEnvValue}"}

                  # ... and the Conan operators extending the rendering:
                  ${hasLine defaultProfile "${runEnvPathKey}+=(path)${runEnvPathValue}"}

                  # ... one line per entry and nothing else:
                  ${hasBodyLines defaultProfile "[runenv]" (lib.length cfg.profiles.default.runEnv)}
                '';
              };

              "profile.CONF.1" = {
                enable = true;
                drv = pureCheck "profile.CONF.1" ''
                  echo "Checking the conf section header..."

                  ${hasLine defaultProfile "[conf]"}
                '';
              };

              "profile.CONF.2" = {
                enable = true;
                drv = pureCheck "profile.CONF.2" ''
                  echo "Checking the conf section entries..."

                  ${hasEntries defaultProfile "=" cfg.final.profiles.default.conf}

                  # ... one line per entry and nothing else:
                  ${hasBodyLines defaultProfile "[conf]" (lib.length (lib.attrNames cfg.final.profiles.default.conf))}
                '';
              };

              "profile.REPLACE_REQUIRES.1" = {
                enable = true;
                drv = pureCheck "profile.REPLACE_REQUIRES.1" ''
                  echo "Checking the replace_requires section header..."

                  ${hasLine defaultProfile "[replace_requires]"}
                '';
              };

              "profile.REPLACE_REQUIRES.2" = {
                enable = true;
                drv = pureCheck "profile.REPLACE_REQUIRES.2" ''
                  echo "Checking the replace_requires section entries..."

                  # The whole `<pattern>: <replacement>` line, colon and space
                  # included, and never the pattern alone:
                  ${hasEntries defaultProfile ": " cfg.final.profiles.default.replaceRequires}

                  # ... which is not the slash-separated rendering of the
                  # "requires"-shaped sections:
                  ${lacksMatch defaultProfile "^${lib.escapeRegex "${replaceRequiresKey}/"}"}

                  # ... one line per entry and nothing else:
                  ${hasBodyLines defaultProfile "[replace_requires]" (
                    lib.length (lib.attrNames cfg.final.profiles.default.replaceRequires)
                  )}
                '';
              };

              "profile.REPLACE_TOOL_REQUIRES.1" = {
                enable = true;
                drv = pureCheck "profile.REPLACE_TOOL_REQUIRES.1" ''
                  echo "Checking the replace_tool_requires section header..."

                  ${hasLine defaultProfile "[replace_tool_requires]"}
                '';
              };

              "profile.REPLACE_TOOL_REQUIRES.2" = {
                enable = true;
                drv = pureCheck "profile.REPLACE_TOOL_REQUIRES.2" ''
                  echo "Checking the replace_tool_requires section entries..."

                  # The whole `<pattern>: <replacement>` line, colon and space
                  # included, and never the pattern alone:
                  ${hasEntries defaultProfile ": " cfg.final.profiles.default.replaceToolRequires}

                  # ... which is not the slash-separated rendering of the
                  # "requires"-shaped sections:
                  ${lacksMatch defaultProfile "^${lib.escapeRegex "${replaceToolRequiresKey}/"}"}

                  # ... one line per entry and nothing else:
                  ${hasBodyLines defaultProfile "[replace_tool_requires]" (
                    lib.length (lib.attrNames cfg.final.profiles.default.replaceToolRequires)
                  )}
                '';
              };

              "profile.PLATFORM_REQUIRES.1" = {
                enable = true;
                drv = pureCheck "profile.PLATFORM_REQUIRES.1" ''
                  echo "Checking the platform_requires section header..."

                  ${hasLine defaultProfile "[platform_requires]"}
                '';
              };

              "profile.PLATFORM_REQUIRES.2" = {
                enable = true;
                drv = pureCheck "profile.PLATFORM_REQUIRES.2" ''
                  echo "Checking the platform_requires section entries..."

                  ${hasEntries defaultProfile "/" cfg.final.profiles.default.platformRequires}

                  # ... one line per entry and nothing else:
                  ${hasBodyLines defaultProfile "[platform_requires]" (
                    lib.length (lib.attrNames cfg.final.profiles.default.platformRequires)
                  )}
                '';
              };

              "profile.PLATFORM_TOOL_REQUIRES.1" = {
                enable = true;
                drv = pureCheck "profile.PLATFORM_TOOL_REQUIRES.1" ''
                  echo "Checking the platform_tool_requires section header..."

                  ${hasLine defaultProfile "[platform_tool_requires]"}
                '';
              };

              "profile.PLATFORM_TOOL_REQUIRES.2" = {
                enable = true;
                drv = pureCheck "profile.PLATFORM_TOOL_REQUIRES.2" ''
                  echo "Checking the platform_tool_requires section entries..."

                  ${hasEntries defaultProfile "/" cfg.final.profiles.default.platformToolRequires}

                  # ... one line per entry and nothing else:
                  ${hasBodyLines defaultProfile "[platform_tool_requires]" (
                    lib.length (lib.attrNames cfg.final.profiles.default.platformToolRequires)
                  )}
                '';
              };

              # A profile entry whose evaluation fails is only a problem once
              # that very entry is used: its sibling entries stay usable, which
              # is what lets defaults be assigned to entries of any type.
              "profile.PROFILE.1" =
                let
                  deferred = evalConan (_: {
                    configRoot = ./.;
                    profiles.deferred.settings._ = {
                      build_type = "MinSizeRel";
                      os = throw "profile.PROFILE.1: profile entry evaluated eagerly";
                    };
                  });
                in
                {
                  enable = true;
                  drv = pureCheck "profile.PROFILE.1" ''
                    echo "Checking profile entries are evaluated per entry..."

                    # The entry does fail once it is used ...
                    ${nixFact (!(builtins.tryEval deferred.profiles.deferred.settings._.os).success)}

                    # ... and its sibling entry is usable regardless:
                    ${nixFact (deferred.profiles.deferred.settings._.build_type == "MinSizeRel")}
                  '';
                };

              # An entry assigned `null` drops the corresponding default from
              # the rendered profile file.
              "profile.PROFILE.2" = {
                enable = true;
                drv = pureCheck "profile.PROFILE.2" ''
                  echo "Checking null entries remove their defaults..."

                  # All three entries come from the defaults ...
                  ${nixFact (lib.hasAttr cppstdKey cfg.defaults.profiles.settings.compiler)}
                  ${nixFact (lib.hasAttr "cmake" cfg.defaults.profiles.platformToolRequires)}
                  ${nixFact (lib.hasAttr defaultPlatformRequiresKey cfg.defaults.profiles.platformRequires)}

                  # ... and are rendered wherever they are not assigned `null`:
                  ${hasLine defaultProfile "${cppstdKey}=${cppstdValue}"}
                  ${hasLine defaultProfile "cmake/${cfg.final.profiles.default.platformToolRequires.cmake}"}
                  ${hasLine defaultProfile "${defaultPlatformRequiresKey}/${defaultPlatformRequiresValue}"}

                  # ... while the profile assigning them `null` renders none:
                  ${lacksMatch nullsProfile "^${lib.escapeRegex cppstdKey}="}
                  ${lacksMatch nullsProfile "^cmake/"}
                  ${lacksMatch nullsProfile "^${lib.escapeRegex defaultPlatformRequiresKey}/"}
                '';
              };

              # A default entry overridden by the profile is never evaluated,
              # so the final entry is computed out of the profile entry and the
              # default entry that actually contribute to it.
              "profile.FINAL.1" =
                let
                  lazy = evalConan (_: {
                    configRoot = ./.;
                    defaults.profiles.settings._.build_type = throw "profile.FINAL.1: default entry evaluated eagerly";
                    profiles.lazy.settings._.build_type = "MinSizeRel";
                  });
                in
                {
                  enable = true;
                  drv = pureCheck "profile.FINAL.1" ''
                    echo "Checking the final profile is computed per entry..."

                    # The default entry does fail once it is used ...
                    ${nixFact (!(builtins.tryEval lazy.defaults.profiles.settings._.build_type).success)}

                    # ... and the final profile, entry by entry, is usable
                    # regardless, since that default entry is not part of it:
                    ${nixFact (
                      builtins.deepSeq lazy.final.profiles.lazy.settings._ (
                        lazy.final.profiles.lazy.settings._.build_type == "MinSizeRel"
                      )
                    )}
                  '';
                };

              # An entry assigned `null` is absent from the final profile.
              "profile.FINAL.2" = {
                enable = true;
                drv = pureCheck "profile.FINAL.2" ''
                  echo "Checking the final profile ignores null entries..."

                  ${nixFact (!(lib.hasAttr cppstdKey cfg.final.profiles.${nullsKey}.settings.compiler))}
                  ${nixFact (!(lib.hasAttr "cmake" cfg.final.profiles.${nullsKey}.platformToolRequires))}
                  ${nixFact (
                    !(lib.hasAttr defaultPlatformRequiresKey cfg.final.profiles.${nullsKey}.platformRequires)
                  )}

                  # ... only in the profile assigning them `null`:
                  ${nixFact (lib.hasAttr cppstdKey cfg.final.profiles.default.settings.compiler)}
                  ${nixFact (lib.hasAttr "cmake" cfg.final.profiles.default.platformToolRequires)}
                  ${nixFact (
                    cfg.final.profiles.default.platformRequires.${defaultPlatformRequiresKey}
                    == defaultPlatformRequiresValue
                  )}
                '';
              };

              # The file renders the final profile, not the profile as declared.
              "profile.PROFILE_FILE.1" = {
                enable = true;
                drv = pureCheck "profile.PROFILE_FILE.1" ''
                  echo "Checking the file is rendered from the final profile..."

                  # An entry the profile does not declare at all is rendered
                  # with the value the final profile took from the defaults:
                  ${nixFact (!(lib.hasAttr "arch" cfg.profiles.default.settings._))}
                  ${hasLine defaultProfile "arch=${cfg.final.profiles.default.settings._.arch}"}

                  # ... and an entry the profile does declare is rendered with
                  # the value of the final profile, not the default one:
                  ${nixFact (cppstdValue != cfg.defaults.profiles.settings.compiler.${cppstdKey})}
                  ${hasLine defaultProfile "${cppstdKey}=${
                    cfg.final.profiles.default.settings.compiler.${cppstdKey}
                  }"}
                  ${lacksMatch defaultProfile "^${lib.escapeRegex cppstdKey}=${
                    lib.escapeRegex cfg.defaults.profiles.settings.compiler.${cppstdKey}
                  }$"}
                '';
              };

              # Every line of the file belongs to a section.
              "profile.PROFILE_FILE.2" = {
                enable = true;
                drv = pureCheck "profile.PROFILE_FILE.2" ''
                  echo "Checking the file is composed of sections..."

                  awk '
                    NF == 0 { next }
                    /^\[.*\]$/ { sections++; inside = 1; next }
                    inside != 1 { print "line outside of any section: " $0; exit 1 }
                    END { if (sections < 2) { print "not composed of sections"; exit 1 } }
                  ' ${escapeShellArg defaultProfile}
                '';
              };

              # Every section starts with a header.
              "profile.PROFILE_FILE.2-1" = {
                enable = true;
                drv = pureCheck "profile.PROFILE_FILE.2-1" ''
                  echo "Checking every section starts with a header..."

                  # The first section of the file starts with a header ...
                  grep -m1 . ${escapeShellArg defaultProfile} | grep -qxE '\[[a-z_]+\]'

                  # ... and so does every other one, since every bracketed line
                  # of the file is a well-formed header:
                  awk '
                    /^\[/ && !/^\[[a-z_]+\]$/ { print "malformed section header: " $0; exit 1 }
                  ' ${escapeShellArg defaultProfile}
                '';
              };

              "profile.PROFILE_FILE.3" = {
                enable = true;
                drv = pureCheck "profile.PROFILE_FILE.3" ''
                  echo "Checking the file has a settings section..."

                  ${hasLine defaultProfile "[settings]"}
                  ${hasLine defaultProfile "build_type=${cfg.final.profiles.default.settings._.build_type}"}
                '';
              };

              "profile.PROFILE_FILE.4" = {
                enable = true;
                drv = pureCheck "profile.PROFILE_FILE.4" ''
                  echo "Checking the file has an options section..."

                  ${hasLine defaultProfile "[options]"}
                  ${hasLine defaultProfile "${optionsKey}=${optionsValue}"}
                '';
              };

              "profile.PROFILE_FILE.5" = {
                enable = true;
                drv = pureCheck "profile.PROFILE_FILE.5" ''
                  echo "Checking the file has a tool_requires section..."

                  ${hasLine defaultProfile "[tool_requires]"}
                  ${hasLine defaultProfile "${toolRequiresKey}/${toolRequiresValue}"}
                '';
              };

              "profile.PROFILE_FILE.6" = {
                enable = true;
                drv = pureCheck "profile.PROFILE_FILE.6" ''
                  echo "Checking the file has a buildenv section..."

                  ${hasLine defaultProfile "[buildenv]"}
                  ${hasLine defaultProfile "${buildEnvKey}=${buildEnvValue}"}
                '';
              };

              "profile.PROFILE_FILE.7" = {
                enable = true;
                drv = pureCheck "profile.PROFILE_FILE.7" ''
                  echo "Checking the file has a runenv section..."

                  ${hasLine defaultProfile "[runenv]"}
                  ${hasLine defaultProfile "${runEnvKey}=${runEnvValue}"}
                '';
              };

              "profile.PROFILE_FILE.8" = {
                enable = true;
                drv = pureCheck "profile.PROFILE_FILE.8" ''
                  echo "Checking the file has a conf section..."

                  ${hasLine defaultProfile "[conf]"}
                  ${hasLine defaultProfile "${confKey}=${confValue}"}
                '';
              };

              "profile.PROFILE_FILE.9" = {
                enable = true;
                drv = pureCheck "profile.PROFILE_FILE.9" ''
                  echo "Checking the file has a replace_requires section..."

                  ${hasLine defaultProfile "[replace_requires]"}
                  ${hasLine defaultProfile "${replaceRequiresKey}: ${replaceRequiresValue}"}
                '';
              };

              "profile.PROFILE_FILE.10" = {
                enable = true;
                drv = pureCheck "profile.PROFILE_FILE.10" ''
                  echo "Checking the file has a replace_tool_requires section..."

                  ${hasLine defaultProfile "[replace_tool_requires]"}
                  ${hasLine defaultProfile "${replaceToolRequiresKey}: ${replaceToolRequiresValue}"}
                '';
              };

              "profile.PROFILE_FILE.11" = {
                enable = true;
                drv = pureCheck "profile.PROFILE_FILE.11" ''
                  echo "Checking the file has a platform_requires section..."

                  ${hasLine defaultProfile "[platform_requires]"}
                  ${hasLine defaultProfile "${platformRequiresKey}/${platformRequiresValue}"}
                '';
              };

              "profile.PROFILE_FILE.12" = {
                enable = true;
                drv = pureCheck "profile.PROFILE_FILE.12" ''
                  echo "Checking the file has a platform_tool_requires section..."

                  ${hasLine defaultProfile "[platform_tool_requires]"}
                  ${hasLine defaultProfile "cmake/${cfg.final.profiles.default.platformToolRequires.cmake}"}
                '';
              };

              # A default entry no profile keeps is never evaluated, which is
              # what allows defaults to be derived from configuration a profile
              # may well remove.
              "defaults.PROFILE.1" =
                let
                  lazy = evalConan (_: {
                    configRoot = ./.;
                    defaults.profiles.platformToolRequires.cmake = throw "defaults.PROFILE.1: default entry evaluated eagerly";
                    profiles.lazy.platformToolRequires.cmake = null;
                  });
                in
                {
                  enable = true;
                  drv = pureCheck "defaults.PROFILE.1" ''
                    echo "Checking default entries are evaluated per entry..."

                    # The default entry does fail once it is used ...
                    ${nixFact (!(builtins.tryEval lazy.defaults.profiles.platformToolRequires.cmake).success)}

                    # ... and the profile removing it is usable regardless:
                    ${nixFact (
                      builtins.deepSeq lazy.final.profiles.lazy.platformToolRequires (
                        !(lazy.final.profiles.lazy.platformToolRequires ? cmake)
                      )
                    )}
                  '';
                };

              # Conan itself accepts the generated profile, every section of it
              # included: a section Conan rejects (or an empty section it does
              # not tolerate) fails here instead of shipping silently.
              testProfileShow = {
                enable = true;
                drv = inSimulatedShell "flake-parts-profiles-test-profile-show" ''
                  echo "Checking Conan reads back the generated profiles..."

                  conan profile show -pr:a ${escapeShellArg cfg.profiles.default.name} \
                    > profile-show.txt
                  conan profile show -pr:a ${escapeShellArg cfg.profiles.${nullsKey}.name} \
                    > /dev/null

                  # Conan echoes back what it parsed out of every section:
                  grep -qxF ${escapeShellArg "${optionsKey}=${optionsValue}"} profile-show.txt
                  grep -qF ${escapeShellArg "${toolRequiresKey}/${toolRequiresValue}"} profile-show.txt
                  grep -qxF ${escapeShellArg "${replaceRequiresKey}: ${replaceRequiresValue}"} profile-show.txt
                  grep -qxF ${escapeShellArg "${replaceToolRequiresKey}: ${replaceToolRequiresValue}"} profile-show.txt
                  grep -qxF ${escapeShellArg "${platformRequiresKey}/${platformRequiresValue}"} profile-show.txt
                '';
              };

              # The activated shell links the very profile file that was
              # generated, next to the remaining local Conan configuration.
              testLocalSetup = {
                enable = true;
                drv =
                  let
                    stdenv = pkgs.gccStdenv;
                    backendStdenv = pkgs.cudaPackages.backendStdenv;
                    llvmPackages = pkgs.llvmPackages;
                  in
                  inSimulatedShell "flake-parts-profiles-test-local-setup" ''
                    echo "Checking local setup..."

                    cat ${escapeShellArg cfg.configLocal}"/settings_user.yml" \
                      | grep -F ${escapeShellArg (inputs.conan-flake.lib.versionFromStdenvCc lib stdenv)}
                    cat ${escapeShellArg cfg.configLocal}"/settings_user.yml" \
                      | grep -F ${escapeShellArg (inputs.conan-flake.lib.versionFromStdenvCc lib backendStdenv)}
                    cat ${escapeShellArg cfg.configLocal}"/settings_user.yml" \
                      | grep -F ${escapeShellArg (inputs.conan-flake.lib.versionFromStdenvCc lib llvmPackages.libcxxStdenv)}

                    cat ${escapeShellArg cfg.configLocal}"/global.conf" \
                      | grep -F "core.graph:compatibility_mode" \
                      | grep -F "optimized"

                    cmp ${escapeShellArg (localProfile cfg.profiles.default.name)} \
                      ${escapeShellArg defaultProfile}
                    cmp ${escapeShellArg (localProfile cfg.profiles.${nullsKey}.name)} \
                      ${escapeShellArg nullsProfile}
                  '';
              };
            };
          };
        };
    };
}
