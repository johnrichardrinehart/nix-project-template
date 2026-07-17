# shellcheck shell=bash
# `writeShellApplication` supplies strict mode and a dependency-complete PATH.
exec nix flake check --print-build-logs "$@"
