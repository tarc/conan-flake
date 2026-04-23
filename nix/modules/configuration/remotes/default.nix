# Definition of the `conan` submodule's `config`
configuration@{ lib, pkgs, relativePathType, ... }:
let
  inherit (lib)
    attrValues
    concatStringsSep
    filterAttrs
    filter
    map
    mkOption
    optionalString
    types;

  remoteSubmodule = import ./remote.nix { inherit configuration lib pkgs; };

  remoteAdd = package: remote: ''
    ${lib.getExe package} remote add ${remote.name} ${remote.url} ${
      optionalString (!remote.verifySsl) "--insecure"
    } ${optionalString (remote.local) "--type local-recipes-index"} ${
      optionalString (
        remote.allowedPackages != null
      ) ''--allowed-packages="${concatStringsSep "," remote.allowedPackages}"''
    } --force
  '';

  cfg = filterAttrs (_: remote: remote.enable) configuration.config.remotes;

  online = (filter (remote: !remote.local) (attrValues cfg));

  local = (filter (remote: remote.local) (attrValues cfg));

  onlineCommands = (map (remote: (remoteAdd configuration.config.package) remote) online);

  localCommands = (map (remote: (remoteAdd configuration.config.package) remote) local);

  onlineConanRemoteAdds = concatStringsSep "\n" onlineCommands;

  localConanRemoteAdds = concatStringsSep "\n" localCommands;

  setupCommands = ''
    ${optionalString (configuration.config.hasImplicitConancenterRemote && configuration.config.offline) ''
      ${lib.getExe configuration.config.package} remote disable conancenter
    ''}
    ${optionalString (configuration.config.hasImplicitConancenterRemote && !configuration.config.offline) ''
      ${lib.getExe configuration.config.package} remote enable conancenter
    ''}
  ''
  + (optionalString (!configuration.config.offline) onlineConanRemoteAdds)
  + localConanRemoteAdds;

  localRecipeIndexHookFiles = map (
    remote:
    "${configuration.config.conanHome}/.local_recipes_index/${remote.name}/.conan/extensions/hooks/hook_trim_conandata.py"
  ) local;
in
{
  options = {
    remotes = mkOption {
      type = types.lazyAttrsOf (types.submodule remoteSubmodule);
      default = { };
      description = ''
        Conan remote repositories.
      '';
    };
  };

  config = {
    outputs = {
      commands.remotes = {
        enterShell = lib.mkAfter setupCommands;
        kind = "configuration";
      };

      links.remotes = {
        relativePaths = localRecipeIndexHookFiles;
        kind = "configuration";
      };
    };
  };
}
