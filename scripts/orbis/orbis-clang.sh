#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
default_bundle_root="$(cd "${script_dir}/../../third_party/orbis-wine" && pwd)"
tool_bin="${ORBIS_TOOLCHAIN_BIN:-${default_bundle_root}/toolchain/sdk/host_tools/bin}"

exec "${script_dir}/orbis-driver-common.sh" "${tool_bin}/orbis-clang.exe" "$@"
