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
         , "./examples/llvm-flake-parts" { overrideInputs = cf }
         , "./examples/standalone" { overrideInputs = cf }
         , "./examples/standalone-eval-conan-config" { overrideInputs = cf }
         , "./examples/standalone-submodule-with" { overrideInputs = cf }
         , "./test/flake-parts" { overrideInputs = cf }
         , "./test/flake-parts-multiple-profiles" { overrideInputs = cf }
         , "./test/flake-parts-no-defaults" { overrideInputs = cf }
         , "./test/flake-parts-override-default" { overrideInputs = cf }
         , "./test/flake-parts-override-default-cmd" { overrideInputs = cf }
         , "./test/flake-parts-profiles" { overrideInputs = cf }
         , "./test/inner-home-directory" { overrideInputs = cf }
         , "./test/outer-root-directory/dev" { overrideInputs = cf }
         , "./test/llvm-flake-parts" { overrideInputs = cf }
         , "./test/standalone" { overrideInputs = cf }
         , "./test/standalone-submodule-with" { overrideInputs = cf }
         ]
     , signoff.enable = True
     , cache.url = Nothing
     }
