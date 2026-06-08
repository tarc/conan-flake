# file: examples/standalone-submodule-with/eval.nix
let
  pkgs = import <nixpkgs> { };
in
pkgs.lib.evalModules {
  modules = [
    ({ config, ... }: { config._module.args = { inherit pkgs; }; })
    ./default.nix
  ];
}
