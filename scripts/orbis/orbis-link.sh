#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
default_bundle_root="$(cd "${script_dir}/../../third_party/orbis-wine" && pwd)"
tool_bin="${ORBIS_TOOLCHAIN_BIN:-${default_bundle_root}/toolchain/sdk/host_tools/bin}"
sdk_root="${ORBIS_SDK_ROOT:-${default_bundle_root}/sdk/sdk}"
sdk_lib_dir="${ORBIS_TARGET_LIB_DIR:-${sdk_root}/target/lib}"
ld_exe="${tool_bin}/orbis-ld.exe"

if [[ ! -f "${ld_exe}" ]]; then
  echo "missing Orbis linker: ${ld_exe}" >&2
  exit 1
fi

if [[ ! -d "${sdk_lib_dir}" ]]; then
  echo "missing Orbis target lib directory: ${sdk_lib_dir}" >&2
  exit 1
fi

expanded_args=()

dedupe_preserve_order() {
  local -n input_ref="$1"
  local -n output_ref="$2"
  local item
  declare -A seen=()

  output_ref=()
  for item in "${input_ref[@]}"; do
    if [[ -n "${seen[$item]+x}" ]]; then
      continue
    fi
    seen["$item"]=1
    output_ref+=("$item")
  done
}

expand_rsp_file() {
  local rsp_file="$1"
  local line
  local -a parts=()

  while IFS= read -r line || [[ -n "${line}" ]]; do
    read -r -a parts <<< "${line}"
    expanded_args+=("${parts[@]}")
  done < "${rsp_file}"
}

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

convert_link_arg() {
  local arg="$1"

  case "$arg" in
    -L/*)
      printf -- '-L%s' "$(to_windows_path "${arg#-L}")"
      ;;
    /*)
      printf '%s' "$(to_windows_path "$arg")"
      ;;
    *)
      printf '%s' "$arg"
      ;;
  esac
}

for arg in "$@"; do
  if [[ "${arg}" == @* ]]; then
    rsp_path="${arg#@}"
    if [[ -f "${rsp_path}" ]]; then
      expand_rsp_file "${rsp_path}"
      continue
    fi
  fi
  expanded_args+=("${arg}")
done

out_file=""
need_value_for=""
search_args=()
input_args=()
library_args=()
passthrough_args=()

for arg in "${expanded_args[@]}"; do
  if [[ -n "${need_value_for}" ]]; then
    case "${need_value_for}" in
      -o)
        out_file="${arg}"
        ;;
      -L)
        search_args+=("-L" "${arg}")
        ;;
      -isystem|-isysroot|-iquote|-idirafter|-include|-include-pch|-B|-resource-dir|-working-directory)
        ;;
      *)
        passthrough_args+=("${need_value_for}" "${arg}")
        ;;
    esac
    need_value_for=""
    continue
  fi

  case "${arg}" in
    -o|-L)
      need_value_for="${arg}"
      ;;
    -fPIC|-integrated-as|-m64)
      ;;
    -isystem|-isysroot|-iquote|-idirafter|-include|-include-pch|-B|-resource-dir|-working-directory)
      need_value_for="${arg}"
      ;;
    -isystem*|-isysroot=*|-iquote*|-idirafter*|-include*|-include-pch*|-resource-dir*|-working-directory*)
      ;;
    -L*)
      search_args+=("${arg}")
      ;;
    -l*)
      library_args+=("${arg}")
      ;;
    *.o|*.obj|*.a|*.so)
      input_args+=("${arg}")
      ;;
    *)
      passthrough_args+=("${arg}")
      ;;
  esac
done

deduped_input_args=()
deduped_library_args=()
dedupe_preserve_order input_args deduped_input_args
dedupe_preserve_order library_args deduped_library_args

if [[ -z "${out_file}" ]]; then
  echo "orbis-link.sh: missing -o <output>" >&2
  exit 2
fi

link_args=(
  --strip-unused-data
  --strip-duplicates
  -o "${out_file}"
  "${search_args[@]}"
  "${deduped_input_args[@]}"
  "${sdk_lib_dir}/crt1.o"
  "${sdk_lib_dir}/crti.o"
  "${sdk_lib_dir}/crtbegin.o"
  --start-group
  "${deduped_library_args[@]}"
  --end-group
  "${sdk_lib_dir}/crtend.o"
  "${sdk_lib_dir}/crtn.o"
)

if [[ ${#passthrough_args[@]} -gt 0 ]]; then
  link_args=("${passthrough_args[@]}" "${link_args[@]}")
fi

rsp_file="$(mktemp /tmp/orbis-link-XXXXXX.rsp)"
trap 'rm -f "${rsp_file}"' EXIT

converted_link_args=()
need_value_for=""

for arg in "${link_args[@]}"; do
  if [[ -n "${need_value_for}" ]]; then
    converted_link_args+=("$(convert_link_arg "${arg}")")
    need_value_for=""
    continue
  fi

  case "${arg}" in
    -o|-L)
      converted_link_args+=("${arg}")
      need_value_for="${arg}"
      ;;
    *)
      converted_link_args+=("$(convert_link_arg "${arg}")")
      ;;
  esac
done

printf '%s\n' "${converted_link_args[@]}" > "${rsp_file}"

exec "${script_dir}/orbis-driver-common.sh" "${ld_exe}" "@${rsp_file}"
