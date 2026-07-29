# Definition of the `conan` submodule's `config`
configuration@{
  lib,
  pkgs,
  config,
  ...
}:
let
  inherit (lib)
    attrValues
    concatStringsSep
    escapeShellArg
    filterAttrs
    filter
    mkOption
    optionalString
    types
    ;

  remoteSubmodule = import ./remote.nix { inherit configuration lib pkgs; };

  remoteAdd = config: remote: ''
    ${lib.getExe config.package} remote add ${remote.name} ${
      # Online remote:
      optionalString (!remote.local) remote.url
    } ${
      # Local recipes index:
      optionalString (remote.local) ''"$(realpath -m "$CONAN_FLAKE_ROOT/"${escapeShellArg remote.url})"''
    } ${
      # Disable SSL verification:
      optionalString (!remote.verifySsl) "--insecure"
    } ${
      # Local recipes index:
      optionalString (remote.local) "--type local-recipes-index"
    } ${
      # Allowed packages:
      optionalString (
        remote.allowedPackages != null
      ) ''--allowed-packages="${concatStringsSep "," remote.allowedPackages}"''
    } --force >&2
  '';

  cfg = filterAttrs (_: remote: remote.enable) config.remotes;

  online = (filter (remote: !remote.local) (attrValues cfg));

  local = (filter (remote: remote.local) (attrValues cfg));

  onlineCommands = (map (remote: (remoteAdd config) remote) online);

  localCommands = (map (remote: (remoteAdd config) remote) local);

  enableConanCenter = ''
    ${
      optionalString (config.hasImplicitConancenterRemote && config.offline) ''
        ${lib.getExe config.package} remote disable conancenter >&2
      ''
    }${
      optionalString (config.hasImplicitConancenterRemote && !config.offline) ''
        ${lib.getExe config.package} remote enable conancenter >&2
      ''
    }
  '';

  onlineConanRemoteAdds = concatStringsSep "\n" onlineCommands;

  localConanRemoteAdds = concatStringsSep "\n" localCommands;

  localRecipeIndexHookFiles = map (
    remote:
    "${config.conanHome}/.local_recipes_index/${remote.name}/.conan/extensions/hooks/hook_trim_conandata.py"
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
    wrappers.preConfigInstallHook = lib.mkAfter (
      enableConanCenter + (optionalString (!config.offline) onlineConanRemoteAdds) + localConanRemoteAdds
    );

    outputs = {
      links.remotes = {
        relativePaths = localRecipeIndexHookFiles;
        kind = "configuration";
      };
    };
  };
}
