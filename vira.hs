-- CI configuration <https://vira.nixos.asia/>
\ctx pipeline ->
  let
    isMain = ctx.branch == "main"
    cf = [("conan-flake", ".")]
  in pipeline
     { build.systems =
        [ "x86_64-linux"
        , "aarch64-darwin"
        ]
     , build.flakes =
         [ "./examples/flake-parts" { overrideInputs = cf }
         , "./test/flake-parts" { overrideInputs = cf }
         , "./test/standalone" { overrideInputs = cf }
         ]
     , signoff.enable = True
     , cache.url = Nothing
     }
