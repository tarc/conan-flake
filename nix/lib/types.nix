{ conanFlakeLib, ... }:
{
  relativePathType =
    lib:
    lib.types.pathWith {
      inStore = false;
      absolute = false;
    };

  envSubmodule =
    lib:
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
            type = lib.types.str;
            description = "Value.";
            default = "";
          };
        };
      }
    );

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
    ];

  listOfOutputType = lib: lib.types.listOf (conanFlakeLib.types.outputType lib);

  anyOutput = lib: (conanFlakeLib.types.outputType lib).functor.payload.values;
}
