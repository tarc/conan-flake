{ config
, lib
, pkgs
, ...
}:
let
  inherit (lib)
    mkOption
    types
    ;

  outputsSubmodule = types.submodule {
    options = {
      packages = mkOption {
        type = types.lazyAttrsOf packageInfoSubmodule;
        readOnly = true;
        description = ''
          Package information of all direct requirements of this project's Conan recipe.
          Each value here contains the following keys:

          - `package`: The package derivation for the requirement
        '';
      };
    };
  };

  packageInfoSubmodule = types.submodule {
    options = {
      package = mkOption {
        type = types.package;
        description = ''
          The package derivation.
        '';
      };
    };
  };
  conanRequires = "${config.name}/${config.version}";
in
{
  options = {
    outputs = mkOption {
      type = outputsSubmodule;
      internal = true;
      description = ''
        The flake outputs generated for this project.

        This is an internal option, not meant to be set by the user.
      '';
    };
  };
  config = {
    outputs = {
      packages.default = {
        name = config.name;
        package = pkgs.stdenv.mkDerivation {
          pname = config.name;
          version = config.version;
          src = config.package.source;
          nativeBuildInputs = [
            pkgs.coreutils
            pkgs.conan
            pkgs.cmake
          ];
          configurePhase = ''
            runHook preConfigure
            ${pkgs.coreutils}/bin/mkdir -p $TMP/.conan2
            CONAN_HOME="$TMP/.conan2"
            export CONAN_HOME
            ${pkgs.conan}/bin/conan profile detect
            runHook postConfigure
          '';
          buildPhase = ''
            runHook preBuild
            ${pkgs.conan}/bin/conan create . -pr default -pr ./build_profile -pr ./test_profile
            runHook postBuild
          '';
          installPhase = ''
            runHook preInstall
            ${pkgs.conan}/bin/conan install --deployer-folder=$out --deployer-package=${conanRequires} --requires=${conanRequires}
            runHook postInstall
          '';
        };
      };
    };
  };
}
