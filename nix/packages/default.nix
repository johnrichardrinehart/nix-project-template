{ pkgs }:
let
  ci = pkgs.writeShellApplication {
    name = "ci";
    runtimeInputs = [
      pkgs.git
      pkgs.nix
    ];
    text = builtins.readFile ../scripts/ci.sh;
  };
in
{
  inherit ci;
  default = ci;
}
