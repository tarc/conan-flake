{
  buildGoModule,
  fetchFromGitHub,
  makeWrapper,
}:
buildGoModule (_finalAttrs: {
  pname = "embedmd";
  version = "1.0.0";

  src = fetchFromGitHub {
    owner = "veggiemonk";
    repo = "embedmd";
    rev = "2de10c3e2b97e06ca6cf63cd9601d23d02b8bbad";
    hash = "sha256-hR1PBwn0cQTEhaAzut8e3ZDHWoTktK37OQjXFe3xs38=";
  };

  doCheck = false;

  vendorHash = "sha256-uLhXMwnSHFUUiQlpDw/U6fZvNsRuB4cZhxX4qUtdknA=";

  nativeBuildInputs = [ makeWrapper ];

  postFixup = ''
    wrapProgram $out/bin/embedmd \
      --add-flags "-w"
  '';

  goSum = ./go.sum;
})
