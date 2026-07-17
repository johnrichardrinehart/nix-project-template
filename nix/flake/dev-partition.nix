{ inputs, self, ... }:
{
  imports = [
    inputs.git-hooks.flakeModule
    inputs.treefmt-nix.flakeModule
  ];

  perSystem =
    {
      config,
      pkgs,
      system,
      ...
    }:
    {
      # One definition drives `nix fmt`, the sandboxed treefmt check, and the
      # formatting hook. Add every committed text format or explicitly exclude it.
      treefmt = {
        projectRootFile = "flake.nix";
        programs = {
          actionlint.enable = true;
          nixfmt.enable = true;
          prettier.enable = true;
          shellcheck.enable = true;
          shfmt.enable = true;
          taplo.enable = true;
        };
        settings.formatter = {
          shellcheck.includes = [
            "*.sh"
            ".envrc"
          ];
          shfmt.includes = [
            "*.sh"
            ".envrc"
          ];
        };
      };

      pre-commit.settings.hooks = {
        treefmt.enable = true;
        deadnix.enable = true;
        statix.enable = true;
        check-added-large-files.enable = true;
        check-merge-conflicts.enable = true;

        flake-check-before-push = {
          enable = true;
          name = "authoritative Nix checks";
          entry = "${pkgs.nix}/bin/nix flake check --print-build-logs";
          always_run = true;
          pass_filenames = false;
          require_serial = true;
          stages = [ "pre-push" ];
        };
      };

      checks = import ../checks {
        inherit self system;
      };

      devShells.default = pkgs.mkShell {
        packages = [
          pkgs.nixd
          pkgs.secretspec
        ];
        shellHook = config.pre-commit.installationScript;
      };
    };
}
