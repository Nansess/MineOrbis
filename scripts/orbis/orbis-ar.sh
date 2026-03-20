#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
default_bundle_root="$(cd "${script_dir}/../../third_party/orbis-wine" && pwd)"
tool_bin="${ORBIS_TOOLCHAIN_BIN:-${default_bundle_root}/toolchain/sdk/host_tools/bin}"

if [[ $# -ge 4 && "$1" == "qc" ]]; then
  archive_path="$2"
  shift 2

  rsp_file="$(mktemp "${TMPDIR:-/tmp}/orbis-ar-XXXXXX.rsp")"
  cleanup() {
    rm -f "$rsp_file"
  }
  trap cleanup EXIT

  {
    for obj in "$@"; do
      printf '%s\n' "$obj"
    done
  } >"$rsp_file"

  exec "${script_dir}/orbis-driver-common.sh" "${tool_bin}/orbis-ar.exe" qc "$archive_path" "@$rsp_file"
fi

exec "${script_dir}/orbis-driver-common.sh" "${tool_bin}/orbis-ar.exe" "$@"
