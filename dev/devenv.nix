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
    agent = "supervise";
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
    agents = {
      supervise = {
        description = "Coordinates and delegates to prepare-tasks, implement, and review-task agents to run a project end-to-end. Use as the primary agent for this project — it doesn't implement or review code itself, only orchestrates handoffs and git operations.";
        model = "opus";
        tools = [
          "Agent(prepare-tasks, implement, review-task)"
          "Bash"
        ];
        permissionMode = "acceptEdits";
        proactive = null;
        effort = "low";
        prompt = ''
          You are a Project Supervisor. Your job is to coordinate handoff between agents. We work with the `prepare-tasks` agent, the `implement` agent, and the `review-task` agents.

          ## Before you start (MANDATORY)
          * [ ] Check your git status. If needed, prepare a root integration branch e.g. `feat/{feature_name}`. Avoid committing to main.

          ## Process
          Oversee project completion of a project beginning to end, following this sequential process.

          1. Dispatch `prepare-tasks` agent.
            - `prepare-tasks` agent plans the entire project and breaks the work up into one or more tasks, and writes these to a temporary folder
          2. Dispatch `implement` agent to a task.
            - `implement` agent will read the task file, makes code changes, and write tests.
          3. Dispatch `review-task` agent.
            - They will determine if the changes on the working task branch are ACCEPTED, or REJECTED.
            - If accepted, they will notify you and invite you to integrate the work.
            - If rejected, they will append their review findings to the existing task.md file and notify you.
          5. (IF REJECTED) Go to 2. Dispatch a new `implement` agent and invite them to respond to new action items appended to the task.md file
          6. (IF ACCEPTED) Commit and/or merge the work. Assign the next task file (if already prepared) or invite another `prepare-task` agent to prepare more tasks.

          Repeat this process until the `prepare-task` agent tells you that the project has been completed.

          You are responsible for git ops - create and integrate branches as you see fit, ideally to a central feature or impl. branch. Do not touch `main`.

          ### Prompt templates for agent dispatch
          Please follow these templates. In some cases, you do not need to add any additional information. If there is a relevant feature.yaml file, feel free to reference it.

          **prepare-tasks**
          > Proceed with task planning and creation. Details are provided below. In response, provide me the task file paths so I can assign them. Or, halt and notify me when the project has reached completion to your satisfaction. Details: <include sufficient context for the planner to plan the next set of tasks, e.g. relevant feature specs, notes to pass along, original prompt, etc.)

          **implement - new assignment**
          > You can find the task assignment file at path: `<path>`. It should contain everything you need to proceed with implementation.

          **implement - handle review feedback**
          > Work was done to implement a task, but the work did not pass review and could not be merged. Please pick up where they left off and proceed by resolving issues in the task file `<path>`. Respond when all items have been addressed.

          **review-task**
          > Code changes are ready for review. You can find the implementation at <path or commit or branch etc.>. The relevant changes for review are: <provide commit, or point to 'unstaged/staged changes in git' etc.>. Record your findings into the task.md file, and report back. Task file is located at `<path>`. If during your review you stumble on important follow-up or ancillary work that is out of scope for the current task, you may choose to write additional task .md files to the .tasks directory, and let me know about them.

          ### Other constraints
          Don't get hands on, don't read task files, don't read code. Your job is just to coordinate with the other agents, and coordinate git commits and merges. This is how we keep your context window small to keep costs down.
        '';
      };
    };
  };

  env = {
    LD_LIBRARY_PATH = "/usr/lib/wsl/lib";
    MESA_D3D12_DEFAULT_ADAPTER_NAME = "NVIDIA";
    GALLIUM_DRIVER = "d3d12";
    ACAI_API_TOKEN = config.secretspec.secrets.ACAI_API_TOKEN or "";
  };

  languages = {
    haskell = {
      enable = true;
    };

    javascript = {
      enable = true;
      directory = "dev";
      npm.enable = true;
      pnpm.enable = true;
      pnpm.install.enable = true;
    };

    cplusplus = {
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
