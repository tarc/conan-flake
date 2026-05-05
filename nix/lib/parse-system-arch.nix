{
  # Possible alternatives for `aarch64Select`'s return value: armv8, armv8_32, armv8.3, arm64ec
  aarch64Select ? (s: "armv8")
, # Possible alternatives for `armv7lSelect`'s return value: armv7, armv7hf, armv7s, armv7k
  armv7lSelect ? (s: "armv7")
, throw ? (errorMessage: builtins.throw errorMessage)
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
    s = builtins.elemAt components 0;
  in
  if s == "x86_64" then "x86_64"
  else if s == "aarch64" then (aarch64Select s)
  else if s == "armv7l" then (armv7lSelect s)
  else if s == "i686" then "x86"
  else if s == "armv6l" then "armv6"
  else if s == "riscv64" then "riscv64"
  else if s == "powerpc64le" then "ppc64le"
  else throw (error "Unknown architecture: ${s}")
