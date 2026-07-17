{ self, system }:
{
  # Building deliverables is part of the flake contract. Add unit,
  # integration, module, and policy checks alongside this package check.
  package = self.packages.${system}.default;
}
