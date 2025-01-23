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
  removeByPath = pathList: set: 
    lib.updateManyAttrsByPath [ 
      { 
        path = lib.init pathList;
        update = old: 
          lib.filterAttrs (n: v: n != (lib.last pathList)) old;
        }
      ] set;
  profilesModule = types.submodule ({config, ...}: {
    options = {
      profile = mkOption {
        type = types.attrs;
        readOnly = true;
        internal = true;
      };
      toJSON = mkOption {
        type = types.path;
        readOnly = true;
        description = ''
          Path to profile in JSON format.
        '';
        default = builtins.toFile "profile" (builtins.toJSON (config.profile));
      };
      toToml = mkOption {
        type = types.path;
        readOnly = true;
        description = ''
          Path to profile.
        '';
        default = pkgs.runCommandCC "json2toml" { } ''
          ${pkgs.remarshal}/bin/json2toml ${config.toJSON} | sed 's/ = /=/g;s/\"//g' > $out
        '';
      };
    };
  });
in
{
  options = {
    name = mkOption {
      type = types.nullOr types.str;
      description = ''
        Name of the project.
      '';
      default = null;
      apply = n: if n == null then config.defaults.package.name else n;
    };
    version = mkOption {
      type = types.nullOr types.str;
      description = ''
        Version of the project.
      '';
      default = null;
      apply = v: if v == null then config.defaults.package.version else v;
    };
    ref = mkOption {
      type = types.str;
      readOnly = true;
      description = ''
        Package reference (name/version).
      '';
      default = "${config.name}/${config.version}";
    };
    profile = mkOption {
      type = types.attrs;
      description = ''Profile'';
      default = { };
      apply = pr: lib.attrsets.recursiveUpdate config.defaults.profile pr;
    };
    profiles = {
      build = mkOption {
        type = profilesModule;
        readOnly = true;
        description = ''
          Build profile
        '';
        default = {
          profile = lib.pipe config.profile.build [
            (removeByPath [ "package_settings" ])
            (removeByPath [ "build_env" ])
          ];
        };
      };
      host = mkOption {
        type = profilesModule;
        readOnly = true;
        description = ''
          Host profile
        '';
        default = {
          profile = lib.pipe config.profile.host [
            (removeByPath [ "package_settings" ])
            (removeByPath [ "build_env" ])
          ];
        };
      };
    };
    graph = mkOption {
      type = types.path;
      readOnly = true;
      description = ''
        Graph.
      '';
      default = builtins.toFile "graph" (builtins.toJSON (config.defaults.graph));
    };
  };
}
