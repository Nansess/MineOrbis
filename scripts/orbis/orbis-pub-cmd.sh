#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
default_bundle_root="$(cd "${script_dir}/../../third_party/orbis-wine" && pwd)"

tool_exe="${ORBIS_PUB_CMD_EXE:-}"

if [[ -z "${tool_exe}" ]]; then
  if [[ -f "${default_bundle_root}/host_tools/bin/orbis-pub-cmd.exe" ]]; then
    tool_exe="${default_bundle_root}/host_tools/bin/orbis-pub-cmd.exe"
  elif [[ -n "${ORBIS_SDK_ROOT:-}" && -f "${ORBIS_SDK_ROOT}/host_tools/bin/orbis-pub-cmd.exe" ]]; then
    tool_exe="${ORBIS_SDK_ROOT}/host_tools/bin/orbis-pub-cmd.exe"
  elif [[ -n "${ORBIS_TOOLCHAIN_BIN:-}" && -f "${ORBIS_TOOLCHAIN_BIN}/orbis-pub-cmd.exe" ]]; then
    tool_exe="${ORBIS_TOOLCHAIN_BIN}/orbis-pub-cmd.exe"
  else
    echo "missing Orbis packaging tool: set ORBIS_PUB_CMD_EXE to orbis-pub-cmd.exe" >&2
    exit 1
  fi
fi

exec "${script_dir}/orbis-driver-common.sh" "${tool_exe}" "$@"
