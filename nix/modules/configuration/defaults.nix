# A module representing the default values used internally by conan-flake.
{ lib, pkgs, config, ... }:
let
  inherit (lib)
    mkDefault
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
      defaultText = lib.literalExpression ''
        lib.optionalAttrs defaults.enable {
          conan = package;
        }'';
    };
  };

  config.defaults = {
    devShell.tools = mkDefault (lib.optionalAttrs config.defaults.enable {
      conan = config.package;
    });
  };
}
