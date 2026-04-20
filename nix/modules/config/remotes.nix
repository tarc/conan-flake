# Definition of the `conan` submodule's configuration
{ config, lib, pkgs, relativePathType, ... }:

let
  inherit (lib)
    mkOption
    optionalString
    types;

  singleRemoteSubmodule = types.submodule (
    { name, config, ... }:
    {
      options = {
        enable = mkOption {
          type = types.bool;
          description = "Enable this Conan remote.";
          default = true;
        };
        name = mkOption {
          type = types.str;
          description = "Name of the remote.";
          default = name;
          defaultText = lib.literalMD "remote name";
        };
        url = mkOption {
          type = types.str;
          description = "Remote URL.";
        };
        verifySsl = mkOption {
          type = types.bool;
          description = "Verify SSL.";
          default = true;
        };
        allowedPackages = mkOption {
          type = types.nullOr (types.listOf types.str);
          description = "Allowed packages.";
          default = null;
        };
        local = mkOption {
          type = types.bool;
          description = "Whether the remote is local.";
          default = false;
        };
      };
    }
  );

  remoteAdd = package: remote: ''
    ${lib.getExe package} remote add ${remote.name} ${remote.url} ${
      optionalString (!remote.verifySsl) "--insecure"
    } ${optionalString (remote.local) "--type local-recipes-index"} ${
      optionalString (
        remote.allowedPackages != null
      ) ''--allowed-packages="${lib.concatStringsSep "," remote.allowedPackages}"''
    } --force
  '';

  remotesSubmodule = types.submodule (
    { name, config, ... }:
    let
      enabled = (lib.filter (remote: remote.enable) (lib.attrValues config.remotes));
      online = (lib.filter (remote: !remote.local) enabled);
      local = (lib.filter (remote: remote.local) enabled);
      onlineCommands = (lib.map (remote: (remoteAdd config.package) remote) online);
      localCommands = (lib.map (remote: (remoteAdd config.package) remote) local);
      onlineConanRemoteAdds = lib.concatStringsSep "\n" onlineCommands;
      localConanRemoteAdds = lib.concatStringsSep "\n" localCommands;
    in
    {
      options = {
        package = mkOption {
          type = lib.types.package;
          default = pkgs.conan;
          description = "The Conan package to use.";
          defaultText = lib.literalExpression "pkgs.conan";
        };

        remotes = mkOption {
          type = types.attrsOf singleRemoteSubmodule;
          description = "Conan remotes.";
          default = { };
        };

        conanHome = mkOption {
          type = relativePathType;
          description = "Relative path for the local Conan home.";
          default = "./.conan2";
        };

        hasImplicitConancenterRemote = mkOption {
          type = types.bool;
          description = ''
            Whether to consider the implicit conancenter remote
            (https://center2.conan.io) during the initial Conan setup or not.
          '';
          default = true;
        };

        setupCommands = mkOption {
          type = types.lines;
          description = ''
            Commands required to configure this Conan instance.
          '';
          readOnly = true;
        };

        localRecipeIndexHookFiles = mkOption {
          type = types.listOf relativePathType;
          description = ''
            Relative paths of the local recipe index hooks scripts.
          '';
          readOnly = true;
        };
      };

      config = {
        setupCommands = ''
          ${optionalString (config.hasImplicitConancenterRemote && config.offline) ''
            ${lib.getExe config.package} remote disable conancenter
          ''}
          ${optionalString (config.hasImplicitConancenterRemote && !config.offline) ''
            ${lib.getExe config.package} remote enable conancenter
          ''}
        ''
        + (optionalString (!config.offline) onlineConanRemoteAdds)
        + localConanRemoteAdds;

        localRecipeIndexHookFiles = lib.map (
          remote:
          "${config.conanHome}/.local_recipes_index/${remote.name}/.conan/extensions/hooks/hook_trim_conandata.py"
        ) local;
      };
    }
  );

in
{
  options.remotes = mkOption {
    type = remotesSubmodule;
    description = ''
      Conan remotes.
    '';
  };

  config = {
    outputs = {
      commands.remotes = {
        enterShell = lib.mkAfter config.remotes.setupCommands;
        kind = "configuration";
      };
    };
  };
}
