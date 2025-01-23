{
  description = "A `flake-parts` module for C/C++ development with the Conan package manager";
  outputs = inputs: {
    flakeModule = ./nix/modules;

    templates.default = {
      description = "Example C++ project using conan-flake";
      path = builtins.path { path = ./examples/app; };
    };

    om = {
      # https://omnix.page/om/init.html#spec
      templates.conan-flake = {
        template = inputs.self.templates.default;
        params = [
          {
            name = "project-name";
            description = "Name of the project";
            placeholder = "example-app";
          }
        ];
      };

      # CI spec
      # https://omnix.page/om/ci.html
      ci.default =
        let
          conan-flake = ./.;
        in
        {
          dev = {
            dir = "dev";
            overrideInputs = { inherit conan-flake; };
          };

          doc = {
            dir = "doc";
            overrideInputs = { inherit conan-flake; };
          };

          example-library = {
            dir = "examples/library";
            overrideInputs = { inherit conan-flake; };
          };

          example-app = {
            dir = "examples/app";
            overrideInputs = { inherit conan-flake; };
          };
        };
    };
  };
}
