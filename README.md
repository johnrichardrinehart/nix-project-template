# Opinionated Nix project template

This repository is a template for projects whose maintainers support, use, and deeply understand Nix. It treats the flake as the project's executable interface rather than as an optional development convenience.

The result is one definition of how to build, run, format, lint, test, and enter the development environment. Local tools, Git hooks, and CI consume that definition instead of reimplementing it.

## Design goals

- **Consumer-clean outputs.** Development-only inputs are isolated in a flake-parts partition. Consumers of packages, overlays, libraries, or NixOS modules do not fetch formatter and hook inputs.
- **One formatting and linting policy.** treefmt-nix defines file-oriented formatters and linters once; `nix fmt` and the treefmt Git hook consume that definition, while the sandboxed git-hooks check exercises the same hook for CI.
- **Fast feedback without weak release gates.** Pre-commit runs cheap checks; pre-push runs the authoritative flake checks; CI runs the same flake checks in a clean environment.
- **Reproducible commands.** Custom shell programs use `writeShellApplication` with explicit `runtimeInputs`, making dependencies visible, enabling build-time ShellCheck, and making the command directly `nix run`-able.
- **Thin CI configuration.** CI files provision Nix, credentials, and caching, then invoke a one-line repository command. Project logic remains runnable outside any particular CI service.
- **Stable source hashes.** Packages select source files with `lib.fileset` rather than copying the entire checkout. Unrelated documentation, editor state, and build artifacts therefore do not cause package hash churn.
- **Automatic development environments.** nix-direnv activates and caches the default development shell when entering the repository.
- **Explicit secret contracts.** SecretSpec declares which secrets a command needs while allowing developers, CI, and production to use different providers.
- **Small top-level Nix surface.** The root `flake.nix` and lock file expose the project; implementation details live below `nix/` and development inputs below `dev/`.

This template deliberately optimizes for Nix-native projects. It is not intended to conceal Nix from maintainers or preserve workflows that install an independent toolchain outside the flake.

## Project interface

```console
nix fmt                         # apply the repository formatting policy
nix flake check                 # run authoritative sandboxed checks
nix develop                     # enter the development environment
nix run                         # run the default app
nix run .#ci                    # run the same command used by CI
```

With direnv and nix-direnv installed, `direnv allow` activates `nix develop` automatically and reuses the evaluated environment until watched inputs change.

## Layout

```text
.
├── flake.nix
├── flake.lock
├── README.md
├── dev/
│   ├── flake.nix
│   └── flake.lock
├── nix/
│   ├── flake/
│   │   └── dev-partition.nix
│   ├── checks/
│   │   └── default.nix
│   ├── packages/
│   │   └── default.nix
│   ├── scripts/
│   │   └── ci.sh
│   ├── examples/
│   │   └── secretspec.toml
│   ├── apps/                 # add when app wiring becomes substantial
│   ├── overlays/             # add only when exported
│   ├── nixosModules/         # add only when exported
│   └── lib/                  # add only for genuinely shared Nix logic
├── .envrc
├── .editorconfig
├── .gitignore
└── .github/workflows/ci.yml
```

Directories are added when they carry real behavior; empty abstraction layers are not required. A real project should replace the demonstration `ci` package with its deliverables while retaining a packaged CI entry point.

## Development partition

The root flake imports the flake-parts partitions module and routes `checks`, `devShells`, and `formatter` to `./dev`. The nested flake owns treefmt-nix and git-hooks.nix inputs and has its own lock file.

This separation matters for reusable flakes: changing a linter should not alter the input graph fetched by someone who only imports a NixOS module or builds a package. Runtime and consumer inputs remain in the root flake; authoring-only inputs belong in `dev/flake.nix`.

## Formatting and linting

Every committed text format must be classified as one of:

1. formatted;
2. linted but not safely auto-formatted;
3. generated;
4. vendored and integrity-checked; or
5. intentionally excluded with a documented reason.

The template covers its Nix, shell, TOML, JSON, Markdown, YAML, and GitHub Actions files. Projects must update the treefmt configuration when introducing another file type.

Formatting and file-oriented linting are intentionally defined once in treefmt-nix. git-hooks.nix invokes the treefmt wrapper; it must not redefine individual treefmt-managed tools such as deadnix, statix, or ShellCheck. Do not recreate those tools or their command lines in a task runner, hook, or CI file. Hooks that are not file-oriented formatting or linting—such as large-file, merge-conflict, or pre-push checks—remain direct git-hooks.nix concerns.

The automatic `checks.treefmt` output is disabled because `checks.pre-commit` already runs the treefmt hook against the repository in a pure Nix build, alongside the other pre-commit hooks. Keeping both would execute the same formatting and linting policy twice during `nix flake check`. The pre-commit check therefore remains enabled and is the sandboxed integration point for treefmt.

## Check tiers

| Tier              | Expected work                                                                                 |
| ----------------- | --------------------------------------------------------------------------------------------- |
| `nix fmt`         | Mutating formatters outside the Nix sandbox                                                   |
| pre-commit        | Changed-file formatting, syntax, and inexpensive static analysis                              |
| pre-push          | Full `nix flake check` and other deterministic release gates                                  |
| `nix flake check` | Authoritative sandboxed package, test, formatting, and policy checks                          |
| CI                | A clean execution of the same flake contract                                                  |
| explicit apps     | Networked, credentialed, destructive, hardware, deployment, or unusually expensive operations |

A check should be moved out of `nix flake check` only when sandboxing or cost makes that necessary, not merely because packaging it is inconvenient. Exceptions should still be packaged as flake apps so they remain reproducible and CI-independent.

## CI philosophy

CI has two layers:

1. **Platform adaptation:** checkout, provision the selected Nix version, expose narrowly scoped credentials, enable builders, and connect a binary cache.
2. **Project execution:** invoke one repository-owned command, normally `nix flake check --print-build-logs` or `nix run .#ci`.

Complicated build, test, matrix, deployment, retry, and artifact logic does not belong in a CI-specific YAML language. Put it in Nix checks or package an Ertt-style shell application with explicit runtime dependencies. The same operation can then be run locally, from another CI service, or during incident diagnosis.

The included workflow pins its actions, installs a known Nix release, and connects a cache that persists Nix store paths across workflow runs. Hosted or self-hosted environments may instead use Cachix, FlakeHub Cache, Attic, a native binary cache, or remote builders. Cache credentials belong to the platform-adaptation layer; cacheable build behavior belongs in Nix derivations.

See [docs/ci.md](docs/ci.md) for the boundary and provider requirements.

## Shell applications

Use `writeShellApplication` for user-facing scripts and CI entry points:

```nix
pkgs.writeShellApplication {
  name = "example";
  runtimeInputs = [
    pkgs.coreutils
    pkgs.curl
    pkgs.jq
  ];
  text = builtins.readFile ../scripts/example.sh;
}
```

The script receives strict shell settings, a dependency-complete `PATH`, and ShellCheck during the build. Keep the shell source readable and testable; use Nix to supply dependencies rather than interpolating every executable path into the script.

Private, tiny glue whose complete environment is controlled by its caller may use `writeShellScript`. Independently invoked behavior should not.

## Secrets

Do not require secrets to evaluate the flake, build ordinary derivations, or enter the general development shell. Declare runtime requirements in a committed `secretspec.toml`, then expose secrets only to the command that needs them:

```console
secretspec run -- nix run .#deploy
```

SecretSpec decouples the contract from storage. A developer can use a system keyring, CI can use environment variables, and production can use a managed secret service without changing application-facing names. Use file-valued secrets for private keys and certificates where possible.

SecretSpec complements deployment-time systems such as sops-nix or agenix; it does not require replacing host activation secrets with shell environment variables. See [docs/secrets.md](docs/secrets.md).

## Source closure discipline

Package source should be an explicit fileset:

```nix
src = lib.fileset.toSource {
  root = ../..;
  fileset = lib.fileset.unions [
    ../../src
    ../../Cargo.toml
    ../../Cargo.lock
  ];
};
```

Besides avoiding hash churn, this prevents accidental inclusion of credentials, test output, editor state, and unrelated generated files. Include only inputs needed to produce the derivation.

## Repository maintenance

- Keep `flake.lock` committed and update it automatically on a schedule.
- Use Renovate or an equivalent service for flake inputs and CI action pins.
- Add flake-lock health policy when supported-branch or input-age guarantees matter.
- Use Nix unit tests for nontrivial pure Nix logic; do not rely exclusively on expensive VM tests.
- Add language-specific audit and supply-chain checks to pre-push or CI when relevant.
- Pin CI adapters and let dependency automation propose updates.
- Prefer deletion and direct flake outputs over wrappers that merely rename standard Nix commands.

## Adapting the template

See [docs/customizing.md](docs/customizing.md). The first changes should be:

1. replace the description and supported systems;
2. define real packages and apps;
3. select package sources with filesets;
4. inventory all committed file types;
5. add deterministic checks;
6. decide which secret declarations, if any, are required;
7. select CI provisioning and binary-cache adapters.

The architecture is opinionated; the enabled language tools are examples. Keep the invariants even when replacing the implementation details.
