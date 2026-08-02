{
  pkgs,
  lib,
  config,
  inputs,
  ...
}:
let
  cfg = config.languages.cplusplus.conan.config;
  checks = lib.optionalAttrs (inputs.conan-flake.lib.contains "checks" cfg.autoWire) cfg.outputs.checks;
  packages = lib.optionalAttrs (inputs.conan-flake.lib.contains "packages" cfg.autoWire) cfg.outputs.packages;
  tests = lib.strings.concatStringsSep "\n" (lib.attrValues checks);
  conan = inputs.conan-flake.lib.packages.conan pkgs;
in
{
  name = "conan-flake-dev";

  claude.code = {
    enable = true;
    mcpServers = {
      # Local devenv MCP server
      devenv = {
        type = "stdio";
        command = "devenv";
        args = [ "mcp" ];
        env = {
          DEVENV_ROOT = config.devenv.root;
        };
      };
    };
    permissions = {
      WebFetch = {
        allow = [
          "domain:github.com"
          "domain:docs.anthropic.com"
        ];
      };
      Bash = {
        allow = [
          "nix search:*"
          "devenv-run-tests:*"
          "nix-instantiate:*"
        ];
      };
    };
  };

  languages = {
    haskell = {
      enable = true;
    };
  };

  env = {
    LD_LIBRARY_PATH = "/usr/lib/wsl/lib";
    MESA_D3D12_DEFAULT_ADAPTER_NAME = "NVIDIA";
    GALLIUM_DRIVER = "d3d12";
  };

  languages.javascript = {
    enable = true;
    npm.enable = true;
  };

  languages.cplusplus = {
    enable = true;

    directory = "./dev";

    conan = {
      enable = true;

      package = conan;

      install.enable = true;

      config = {
        configRoot = builtins.path {
          path = inputs.conan-flake;
          name = "source";
        };

        devShell.tools = {
          conan = config.languages.cplusplus.conan.package;
          cmake = config.languages.cplusplus.cmake.package;
        };

        remotes.local = {
          url = "./dev/repo";
          local = true;
          allowedPackages = [
            "hello-world/0.0.1.cci.20260428"
          ];
        };

        offline = true;

        checks.test = {
          enable = true;
          drv =
            inputs.conan-flake.lib.runCommandWithInSimulatedShell pkgs cfg.stdenv cfg.outputs.devShell
              cfg.info.configRoot
              "./config"
              "dev"
              { }
              ''
                (
                set -x
                echo "Testing dev..."

                echo "Checking local development pipeline..."

                echo "CONAN_FLAKE_ROOT:''${CONAN_FLAKE_ROOT@Q}" \
                  | grep -F "CONAN_FLAKE_ROOT:'$HOME/config'"
                echo "CONAN_FLAKE_HOME:''${CONAN_FLAKE_HOME@Q}" \
                  | grep -F "CONAN_FLAKE_HOME:'$(realpath -m "$HOME/config/"${lib.escapeShellArg cfg.homeDirectory})'"
                echo "CONAN_FLAKE_CONFIG:''${CONAN_FLAKE_CONFIG@Q}" \
                  | grep -F "CONAN_FLAKE_CONFIG:'$(realpath -m "$HOME/config/"${lib.escapeShellArg cfg.homeDirectory}"/"${lib.escapeShellArg cfg.configLocal})'"
                echo "CONAN_HOME:''${CONAN_HOME@Q}" \
                  | grep -F "CONAN_HOME:'$(realpath -m "$HOME/config/"${lib.escapeShellArg cfg.homeDirectory}"/"${lib.escapeShellArg cfg.conanHome})'"

                echo "CONAN_FLAKE_ROOT:''${CONAN_FLAKE_ROOT@Q}" \
                  | grep -F "CONAN_FLAKE_ROOT:'$HOME/config'"
                echo "CONAN_FLAKE_HOME:''${CONAN_FLAKE_HOME@Q}" \
                  | grep -F "CONAN_FLAKE_HOME:'$(realpath -m "$HOME/config/dev")'"
                echo "CONAN_FLAKE_CONFIG:''${CONAN_FLAKE_CONFIG@Q}" \
                  | grep -F "CONAN_FLAKE_CONFIG:'$(realpath -m "$HOME/config/dev/config")'"
                echo "CONAN_HOME:''${CONAN_HOME@Q}" \
                  | grep -F "CONAN_HOME:'$(realpath -m "$HOME/config/dev/.conan2")'"

                conan install . --build=missing
                conan build . --build=missing
                ./build/Release/foo | grep -F "foo/1.0 test_package"

                touch $out
                )
              '';
        };
      };
    };
  };

  enterTest = lib.mkIf (inputs.conan-flake.lib.contains "checks" cfg.autoWire) (
    lib.mkAfter ''
      ${tests}
    ''
  );

  outputs = {
    inherit packages;
  };

  packages = with pkgs; [
    ccls
    embedmd
    jq
    just
    mdsh
    nixfmt
    woodpecker-cli
    htop

    autoconf
    libtool
  ];

  overlays = [
    (_final: _prev: {
      embedmd = inputs.conan-flake.lib.packages.embedmd pkgs;
      mdsh = inputs.conan-flake.lib.packages.mdsh_0_9_3 pkgs;
      woodpecker-cli = inputs.conan-flake.lib.packages.woodpecker-cli pkgs;
    })
  ];

  git-hooks = {
    hooks = {
      embedmd = {
        enable = true;
        name = "Embed code snippets in README";
        entry = "embedmd ${config.env.DEVENV_ROOT}/README.md";
        types = [
          "text"
          "nix"
        ];
        pass_filenames = false;
      };
    };
  };

  treefmt = {
    enable = true;
    config = ./treefmt.nix;
  };
}
