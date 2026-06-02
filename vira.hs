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
         , "./examples/standalone" { overrideInputs = cf }
         , "./test/flake-parts" { overrideInputs = cf }
         , "./test/flake-parts-no-defaults" { overrideInputs = cf }
         , "./test/flake-parts-override-default" { overrideInputs = cf }
         , "./test/flake-parts-override-default-cmd" { overrideInputs = cf }
         , "./test/standalone" { overrideInputs = cf }
         , "./test/standalone-submodule-with" { overrideInputs = cf }
         ]
     , signoff.enable = True
     , cache.url = Nothing
     }
