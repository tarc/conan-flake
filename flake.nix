{
  description = "A `flake-parts` module to ease the integration of the Conan C/C++ package manager in the Nix ecosystem";

  outputs = inputs: {
    flakeModule = ./nix/modules;
  };
}
