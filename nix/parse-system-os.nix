{ throw ? (errorMessage: builtins.throw errorMessage)
}:
system:
let
  components = builtins.split "(-)" system;
  num = builtins.length components;
  error = msg: ''
    ERROR[conan-flake] [Invalid system string "${system}"]: ${msg}"
  '';
in
if num != 3 then throw (error "#components (${toString num}) != 3")
else
  let
    s = builtins.elemAt components 2;
  in
  if s == "linux" then "Linux"
  else if s == "darwin" then "Macos"
  else if s == "freebsd" then "FreeBSD"
  else throw (error "Unknown os: ${s}")
