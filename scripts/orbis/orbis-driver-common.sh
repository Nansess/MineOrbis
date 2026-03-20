#!/usr/bin/env bash

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "usage: $0 <tool.exe> [args...]" >&2
  exit 2
fi

tool_exe="$1"
shift

if ! command -v wine >/dev/null 2>&1; then
  echo "wine is required to run the Orbis Windows host tools from Linux." >&2
  exit 127
fi

if [[ ! -f "$tool_exe" ]]; then
  echo "missing Orbis tool: $tool_exe" >&2
  exit 1
fi

if [[ -n "${ORBIS_TOOLCHAIN_BIN:-}" ]]; then
  export PATH="${ORBIS_TOOLCHAIN_BIN}:${PATH}"
fi

to_windows_path() {
  local path="$1"

  if [[ "$path" =~ ^[A-Za-z]:[\\/] ]]; then
    printf '%s' "$path"
    return
  fi

  if [[ "$path" != /* ]]; then
    path="$(realpath -m "$path")"
  fi

  path="${path//\//\\}"
  printf 'Z:%s' "$path"
}

convert_arg() {
  local arg="$1"

  case "$arg" in
    @/*)
      printf '@%s' "$(to_windows_path "${arg#@}")"
      ;;
    --sysroot=/*)
      printf -- '--sysroot=%s' "$(to_windows_path "${arg#--sysroot=}")"
      ;;
    -I/*)
      printf -- '-I%s' "$(to_windows_path "${arg#-I}")"
      ;;
    -L/*)
      printf -- '-L%s' "$(to_windows_path "${arg#-L}")"
      ;;
    -B/*)
      printf -- '-B%s' "$(to_windows_path "${arg#-B}")"
      ;;
    -isystem/*)
      printf -- '-isystem%s' "$(to_windows_path "${arg#-isystem}")"
      ;;
    -iquote/*)
      printf -- '-iquote%s' "$(to_windows_path "${arg#-iquote}")"
      ;;
    -idirafter/*)
      printf -- '-idirafter%s' "$(to_windows_path "${arg#-idirafter}")"
      ;;
    /*)
      printf '%s' "$(to_windows_path "$arg")"
      ;;
    *)
      printf '%s' "$arg"
      ;;
  esac
}

if [[ -n "${ORBIS_SDK_ROOT:-}" ]]; then
  export ORBIS_SDK_ROOT
  export SCE_ORBIS_SDK_DIR="$(to_windows_path "${ORBIS_SDK_ROOT}")"
fi

converted_args=()
expect_path_for=""
depfile_path=""

for arg in "$@"; do
  if [[ -n "$expect_path_for" ]]; then
    if [[ "$expect_path_for" == "-MF" ]]; then
      depfile_path="$arg"
    fi
    converted_args+=("$(convert_arg "$arg")")
    expect_path_for=""
    continue
  fi

  case "$arg" in
    -o|-I|-L|-MF|-MT|-MQ|-isystem|-isysroot|-iquote|-idirafter|-include|-include-pch|-B|-resource-dir|-fprofile-instr-generate|-fprofile-list|-working-directory)
      converted_args+=("$arg")
      expect_path_for="$arg"
      ;;
    *)
      converted_args+=("$(convert_arg "$arg")")
      ;;
  esac
done

normalize_depfile() {
  local depfile="$1"

  [[ -n "$depfile" && -f "$depfile" ]] || return 0

  perl -0pi -e '
    s{"}{}g;
    s{\bZ:(?=[\\/])}{}g;
    s{\\(?=[A-Za-z0-9_.\-/])}{/}g;
    s{//+}{/}g;
  ' "$depfile"
}

wine "$tool_exe" "${converted_args[@]}"
status=$?

if [[ -n "$depfile_path" ]]; then
  normalize_depfile "$depfile_path"
fi

exit "$status"
