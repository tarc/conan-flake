# Definition of the `conan` submodule's configuration
{ self, config, lib, pkgs, ... }:

let
  inherit (lib)
    mkOption
    types;

  infuse = (import self.inputs.infuse { inherit lib; }).v1.infuse;

  cudaCompilerSettings = {
    "${pkgs.cudaPackages.backendStdenv.cc.cc.pname}".version.__append = [
      pkgs.cudaPackages.backendStdenv.cc.cc.version
    ];
  };

  settingsSubmodule = types.submodule (
    { name, config, ... }:
    let
      compilerSettings = infuse config.base cudaCompilerSettings;
    in
    {
      options = {
        base = mkOption {
          type = types.attrs;
          description = ''Base user settings.'';
          default = { };
        };

        user = mkOption {
          type = types.attrs;
          description = ''Default user settings.'';
          default = {
            compiler = infuse compilerSettings {
              "gcc".version.__append = [ pkgs.gccStdenv.cc.version ];
              "clang".version.__append = [ pkgs.llvmPackages.libcxxStdenv.cc.version ];
            };
          };
          defaultText = lib.literalMD ''
            Default user settings computed from the provided `base` settings,
            from `pkgs.cudaPackages.backendStdenv`, `pkgs.gccStdenv`, and
            `pkgs.llvmPackages.libcxxStdenv`.
          '';
          readOnly = true;
        };

        yaml = mkOption {
          type = types.package;
          description = ''
            The YAML-outputing derivation generated for the user configuration.
          '';
          default = (pkgs.formats.yaml { }).generate "settings_user.yml" config.user;
          defaultText = lib.literalExpression ''
            (pkgs.formats.yaml { }).generate "settings_user.yml" settings.user
          '';
          readOnly = true;
        };
      };
    }
  );

in
{
  options.settings = mkOption {
    type = settingsSubmodule;
    description = ''
      Representation of Conan's user settings (`settings_user.yml`).
    '';
  };

  config = {
    outputs = {
      packages.settings = {
        package = config.settings.yaml;
        manifest = "config/settings_user.yml";
      };
      packages.configuration = {
        package = config.settings.yaml;
        manifest = "config/settings_user.yml";
      };
    };
  };
}
