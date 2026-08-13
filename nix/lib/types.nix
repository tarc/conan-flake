{ conanFlakeLib, ... }:
let
  # A `[buildenv]`/`[runenv]` entry.
  #
  # Unlike every other profile section, these two are a list rather than an
  # attribute set: the entry order is significant (Conan applies the operators
  # in file order) and the same variable may legitimately appear more than
  # once, neither of which an attribute set can express.
  #
  # `valueType` is `nullOr str` for a profile's own entries, where `null` marks
  # the removal of the corresponding default entry, and `str` for the final
  # (defaults-merged) view, from which the merge has already consumed the
  # `null` marker.
  #
  # profile.BUILDENV.2
  # profile.RUNENV.2
  mkEnvSubmodule =
    valueType: lib:
    lib.types.submodule (
      { ... }:
      {
        options = {
          name = lib.mkOption {
            type = lib.types.str;
            description = "Name.";
            default = "";
          };
          op = lib.mkOption {
            type = lib.types.enum [
              "="
              "+=" # appends values at the end of the existing value
              "=+" # puts values at the beginning of the existing value
              "=!" # gets rid of any variable value
              "=(path)" # defines a PATH variable
              "=+(path)" # prepends another PATH to variable
              "+=(path)" # appends another PATH to variable
            ];
            description = "Operation";
            default = "=";
          };
          value = lib.mkOption {
            type = valueType lib;
            description = "Value.";
            default = "";
          };
        };
      }
    );
in
{
  relativePathType =
    lib:
    lib.types.pathWith {
      inStore = false;
      absolute = false;
    };

  # Entries of a profile's own `buildEnv`/`runEnv`: `value` accepts `null` to
  # remove the corresponding default entry.
  #
  # profile.PROFILE.2
  envSubmodule = mkEnvSubmodule (lib: lib.types.nullOr lib.types.str);

  # Entries of the final, defaults-merged `buildEnv`/`runEnv`, minus the `null`
  # marker, which the merge consumes.
  #
  # profile.FINAL.2
  finalEnvSubmodule = mkEnvSubmodule (lib: lib.types.str);

  generatorType =
    lib:
    lib.types.enum [
      "CMakeDeps"
      "CMakeToolchain"
    ];

  listOfGeneratorType = lib: lib.types.listOf (conanFlakeLib.types.generatorType lib);

  outputType =
    lib:
    lib.types.enum [
      "devShells"
      "checks"
      "packages"
    ];

  listOfOutputType = lib: lib.types.listOf (conanFlakeLib.types.outputType lib);

  anyOutput = lib: (conanFlakeLib.types.outputType lib).functor.payload.values;
}
