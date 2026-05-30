# A module representing the default values used internally by conan-flake.
{ lib, pkgs, config, ... }:
let
  inherit (lib)
    mkOption
    types;
in
{
  options.defaults = {
    enable = mkOption {
      type = types.bool;
      description = ''
        Whether to enable conan-flake's default settings for this configuration.
      '';
      default = true;
    };

    devShell.tools = mkOption {
      type = types.lazyAttrsOf (types.nullOr types.package);
      description = ''Build tools always included in devShell'';
      default = lib.optionalAttrs config.defaults.enable {
        conan = config.package;
      };
      defaultText = lib.literalExpression ''
        lib.optionalAttrs defaults.enable {
          conan = package;
        }'';
    };
  };
}
