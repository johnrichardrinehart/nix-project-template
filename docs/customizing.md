# Customizing the template

## Outputs

Replace the demonstration `ci` package with project deliverables. Keep a `ci` app when checks alone cannot represent all required CI behavior.

Move substantial output wiring into the matching directory under `nix/`:

- `packages/` for build products and packaged commands;
- `checks/` for deterministic release gates;
- `apps/` for nontrivial app definitions;
- `overlays/` and `nixosModules/` only when exported to consumers;
- `lib/` only for logic reused by multiple expressions.

Keep consumer inputs in the root flake. Keep formatters, hooks, language servers, and authoring utilities in the development subflake.

## Systems

The template explicitly lists Linux systems. Change the list to the platforms actually supported and checked. A shared `nix-systems` input can be appropriate when several flakes intentionally follow one system policy; a literal list better communicates deliberately narrow support.

## Source filesets

Do not use the whole checkout as package source by default. Select the source directory, manifests, lock files, generated inputs, and build metadata required by each derivation. A package with different inputs should have a different fileset.

## Format inventory

After adding project files, list tracked extensions and special names, then update treefmt:

```console
git ls-files | awk -F/ '{ print $NF }' | sed -n 's/.*\.//p' | sort -u
```

Classify extensionless scripts, `.envrc`, generated files, and vendored trees separately. Do not allow two mutating formatters to target the same files unless their order is intentional and stable.

## Checks

Add the cheapest precise check for each behavior:

- pure Nix unit tests for Nix functions;
- package tests in derivation check phases;
- language unit and integration tests as derivations;
- NixOS VM tests for system behavior;
- integrity hashes for vendored sources that formatters must not modify;
- policy checks for generated configuration and synchronized artifacts.

Network, hardware, secret-bearing, and destructive tests should be explicit apps. Document why they cannot be sandboxed and make their prerequisites fail clearly.

## Hooks

Pre-commit should remain fast enough that developers leave it enabled. Put complete tests and package builds in pre-push or the flake check. A custom hook command must use a Nix package path or a packaged application rather than an ambient executable.

## CI adapters

Replace the included workflow adapters when the project uses another Nix implementation, binary cache, remote builder, or CI service. Preserve the boundary: provisioning and cache setup may be provider-specific; project execution should stay one line.
