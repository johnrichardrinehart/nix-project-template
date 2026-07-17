{
  description = "An opinionated, consumer-clean Nix project template";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{ self, flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      imports = [ inputs.flake-parts.flakeModules.partitions ];

      # Development tools do not enter the input closure of package, module,
      # overlay, or library consumers.
      partitionedAttrs = {
        checks = "dev";
        devShells = "dev";
        formatter = "dev";
      };

      partitions.dev = {
        extraInputsFlake = ./dev;
        module = import ./nix/flake/dev-partition.nix;
      };

      perSystem =
        { pkgs, system, ... }:
        let
          packages = import ./nix/packages { inherit pkgs; };
        in
        {
          inherit packages;

          apps = {
            default = {
              type = "app";
              program = "${packages.ci}/bin/ci";
              meta.description = "Run the repository's authoritative CI command";
            };
            ci = self.apps.${system}.default;
          };
        };
    };
}
