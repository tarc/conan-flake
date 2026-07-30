{
  fetchFromGitHub,
  mdsh,
  rustPlatform,
}:
let
  name = "mdsh";
  version = "0.9.3";
  versionHash = "sha256-W9znh93RokghlqIjRRjIUJmkXxUAtLZtpZfGceTPK14=";
  versionCargoHash = "sha256-JbmHwAn3oXUUXsiQgCcZSBBS9o9Kam66MWHnbo25Fxg=";
  src = fetchFromGitHub {
    owner = "tarc";
    repo = name;
    rev = "cd7d2374b551fbe5bf02367398cf6d6b140fca38";
    hash = versionHash;
  };
in
mdsh.overrideAttrs (finalAttrs: rec {
  inherit version src;
  cargoDeps = rustPlatform.fetchCargoVendor {
    inherit src;
    name = "${finalAttrs.pname}-${finalAttrs.version}-vendor";
    hash = versionCargoHash;
  };
})
