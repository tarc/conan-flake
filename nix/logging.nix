{ name, ... }:

{
  # traceDebug uses traceVerbose; and is no-op on Nix versions below 2.10
  traceDebug =
    if builtins.compareVersions "2.10" builtins.nixVersion < 0 then
      msg: builtins.traceVerbose ("DEBUG[conan-flake] [${name}]: " + msg)
    else
      x: x;

  traceWarning = msg: builtins.trace ("WARNING[conan-flake] [${name}]: " + msg);

  throwError =
    msg:
    builtins.throw ''
      ERROR[conan-flake] [${name}]: ${msg}
    '';
}
