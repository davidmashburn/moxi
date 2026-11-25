#!/usr/bin/env bash
set -euo pipefail

# Match the deployment target Clang actually uses for the native objects.
# Its default can differ from the running OS version used by Mojo.
target=$(clang -S -emit-llvm -x objective-c /dev/null -o - |
    sed -n 's/^target triple = "\([^"]*\)"$/\1/p')
exec mojo build --target-triple "${target:?could not determine Clang target}" "$@"
