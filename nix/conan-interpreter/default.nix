{ pkgs
, lib
, throwError ? builtins.throw
, ...
}:
{
  inspect =
    projectRoot:
    let
      conanInspect = builtins.fromJSON (
        builtins.readFile (
          pkgs.runCommandCC "recipe"
            {
              src = projectRoot;
            } "CONAN_HOME=$TMP ${pkgs.conan}/bin/conan inspect $src --format=json > $out"
        )
      );
    in
    conanInspect;

  profile =
    projectRoot:
    let
      conanProfile = builtins.fromJSON (
        builtins.readFile (
          pkgs.runCommandCC "profile" { src = projectRoot; }
            "export CONAN_HOME=$TMP && ${pkgs.conan}/bin/conan profile detect && ${pkgs.conan}/bin/conan profile show --format=json > $out"
        )
      );
    in
    conanProfile;

  graph =
    projectRoot: prb: prh:
    let
      conanGraph = builtins.fromJSON (
        builtins.unsafeDiscardStringContext (
          builtins.readFile (
            pkgs.runCommandCC "graph" { src = projectRoot; }
              "export CONAN_HOME=$TMP && ${pkgs.conan}/bin/conan graph info $src -pr:b ${prb} -pr:h ${prh} --format=json > $out"
          )
        )
      );
    in
    conanGraph;
}
