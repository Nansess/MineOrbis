#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
CLIENT_DIR="$REPO_ROOT/Minecraft.Client"
WORLD_DIR="$REPO_ROOT/Minecraft.World"
PS4_GAME_DIR="$CLIENT_DIR/PS4_GAME"
OUTPUT_DIR="${PS4_OUTPUT_DIR:-$REPO_ROOT/build/ps4}"
SDK_DIR="${SCE_ORBIS_SDK_DIR:-$REPO_ROOT/1.700}"
FPKG_TOOLS_DIR="${PS4_FPKG_TOOLS_DIR:-$REPO_ROOT/PS4_Fake_PKG_Tools_3.87_V7}"
DEFAULT_PASSCODE="GvE6xCpZxd96scOUGuLPbuLp8O800B0s"
PASSCODE="${PS4_PASSCODE:-$DEFAULT_PASSCODE}"
WINEPREFIX_PATH="${WINEPREFIX:-${PS4_WINEPREFIX:-}}"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/ps4.sh build [Debug|Release|ContentPackage|ReleaseForArt]
  ./scripts/ps4.sh stage [Debug|Release|ContentPackage|ReleaseForArt]
  ./scripts/ps4.sh pkg
  ./scripts/ps4.sh all [Debug|Release|ContentPackage|ReleaseForArt]

Environment overrides:
  SCE_ORBIS_SDK_DIR     Orbis SDK root. Default: ./1.700
  PS4_FPKG_TOOLS_DIR    Fake PKG tools root. Default: ./PS4_Fake_PKG_Tools_3.87_V7
  PS4_OUTPUT_DIR        Output workspace. Default: ./build/ps4
  PS4_PASSCODE          32-character package passcode used in the GP4
  PS4_MSBUILD           Path to MSBuild.exe or msbuild
  PS4_MSBUILD_MODE      native or wine
  PS4_WINEPREFIX        Wine prefix for MSBuild and PKG tools
EOF
}

log() {
  printf '[ps4] %s\n' "$*"
}

die() {
  printf '[ps4] error: %s\n' "$*" >&2
  exit 1
}

require_file() {
  local path="$1"
  [[ -e "$path" ]] || die "missing required path: $path"
}

find_first_existing() {
  local candidate
  for candidate in "$@"; do
    if [[ -e "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

resolve_msbuild() {
  if [[ -n "${PS4_MSBUILD:-}" ]]; then
    MSBUILD_PATH="$PS4_MSBUILD"
    MSBUILD_MODE="${PS4_MSBUILD_MODE:-wine}"
    if [[ -z "$WINEPREFIX_PATH" ]]; then
      for candidate in "$HOME/.wine-orbis" "$HOME/.wine"; do
        if [[ -d "$candidate" ]]; then
          WINEPREFIX_PATH="$candidate"
          break
        fi
      done
    fi
    return 0
  fi

  if command -v msbuild >/dev/null 2>&1; then
    MSBUILD_PATH="$(command -v msbuild)"
    MSBUILD_MODE="native"
    return 0
  fi

  local candidate
  for candidate in \
    "$HOME/.wine-orbis/drive_c/windows/Microsoft.NET/Framework64/v4.0.30319/msbuild.exe" \
    "$HOME/.wine-orbis/drive_c/windows/Microsoft.NET/Framework/v4.0.30319/msbuild.exe" \
    "$HOME/.wine-orbis/drive_c/windows/Microsoft.NET/Framework64/v3.5/msbuild.exe" \
    "$HOME/.wine-orbis/drive_c/windows/Microsoft.NET/Framework/v3.5/msbuild.exe" \
    "$HOME/.wine/drive_c/Program Files (x86)/MSBuild/14.0/Bin/MSBuild.exe" \
    "$HOME/.wine/drive_c/Program Files/Microsoft Visual Studio/2022/BuildTools/MSBuild/Current/Bin/MSBuild.exe" \
    "$HOME/.wine/drive_c/Program Files/Microsoft Visual Studio/2022/Community/MSBuild/Current/Bin/MSBuild.exe" \
    "$HOME/.wine/drive_c/Program Files (x86)/Microsoft Visual Studio/2019/BuildTools/MSBuild/Current/Bin/MSBuild.exe" \
    "$HOME/.wine/drive_c/Program Files (x86)/Microsoft Visual Studio/2019/Community/MSBuild/Current/Bin/MSBuild.exe" \
    "$HOME/.wine/drive_c/windows/Microsoft.NET/Framework64/v4.0.30319/msbuild.exe" \
    "$HOME/.wine/drive_c/windows/Microsoft.NET/Framework/v4.0.30319/msbuild.exe" \
    "$HOME/.wine/drive_c/windows/Microsoft.NET/Framework64/v3.5/msbuild.exe" \
    "$HOME/.wine/drive_c/windows/Microsoft.NET/Framework/v3.5/msbuild.exe"
  do
    if [[ -f "$candidate" ]]; then
      MSBUILD_PATH="$candidate"
      MSBUILD_MODE="wine"
      if [[ "$candidate" == "$HOME/.wine-orbis/"* ]] && [[ -z "$WINEPREFIX_PATH" ]]; then
        WINEPREFIX_PATH="$HOME/.wine-orbis"
      elif [[ "$candidate" == "$HOME/.wine/"* ]] && [[ -z "$WINEPREFIX_PATH" ]]; then
        WINEPREFIX_PATH="$HOME/.wine"
      fi
      return 0
    fi
  done

  die "could not find MSBuild. Set PS4_MSBUILD to your msbuild or MSBuild.exe path."
}

run_msbuild() {
  local project_path="$1"
  local config="$2"

  resolve_msbuild
  require_file "$project_path"
  require_file "$SDK_DIR"

  if [[ "$MSBUILD_MODE" == "native" ]]; then
    log "building $(basename "$project_path") [$config|ORBIS] with $MSBUILD_PATH"
    SCE_ORBIS_SDK_DIR="$SDK_DIR" "$MSBUILD_PATH" \
      "$project_path" \
      /t:Build \
      /p:Configuration="$config" \
      /p:Platform=ORBIS \
      /m
    return 0
  fi

  command -v wine >/dev/null 2>&1 || die "wine is required for a Windows MSBuild.exe"
  command -v winepath >/dev/null 2>&1 || die "winepath is required for a Windows MSBuild.exe"
  [[ -n "$WINEPREFIX_PATH" ]] || WINEPREFIX_PATH="$HOME/.wine"

  local project_win sdk_win
  project_win="$(WINEPREFIX="$WINEPREFIX_PATH" winepath -w "$project_path")"
  sdk_win="$(WINEPREFIX="$WINEPREFIX_PATH" winepath -w "$SDK_DIR")"

  log "building $(basename "$project_path") [$config|ORBIS] with wine MSBuild ($WINEPREFIX_PATH)"
  WINEPREFIX="$WINEPREFIX_PATH" SCE_ORBIS_SDK_DIR="$sdk_win" WINEDEBUG="${WINEDEBUG:--all}" \
    wine "$MSBUILD_PATH" \
    "$project_win" \
    /t:Build \
    /p:Configuration="$config" \
    /p:Platform=ORBIS \
    /m
}

build() {
  local config="$1"
  run_msbuild "$WORLD_DIR/Minecraft.World.vcxproj" "$config"
  run_msbuild "$CLIENT_DIR/Minecraft.Client.vcxproj" "$config"
}

find_client_artifact() {
  local config="$1"
  local dir
  for dir in \
    "$CLIENT_DIR/ORBIS_$config" \
    "$REPO_ROOT/ORBIS_$config" \
    "$REPO_ROOT/build-orbis/ORBIS_$config"
  do
    if [[ -d "$dir" ]]; then
      local artifact
      artifact="$(
        find "$dir" -maxdepth 1 -type f \
          \( -name 'eboot.bin' -o -name '*.elf' -o -name '*.self' -o -name 'Minecraft.Client' -o -name 'default' \) \
          -printf '%T@ %p\n' | sort -nr | head -n1 | cut -d' ' -f2-
      )"
      if [[ -n "$artifact" ]]; then
        printf '%s\n' "$artifact"
        return 0
      fi
    fi
  done
  return 1
}

stage() {
  local config="$1"
  mkdir -p "$PS4_GAME_DIR"
  local artifact
  artifact="$(find_client_artifact "$config")" || die "could not find a built ORBIS client artifact for $config"

  log "staging $(basename "$artifact") into PS4_GAME/eboot.bin"
  cp -f "$artifact" "$PS4_GAME_DIR/eboot.bin"

  if [[ ! -f "$PS4_GAME_DIR/sce_module/libc.prx" && -f "$SDK_DIR/target/sce_module/libc.prx" ]]; then
    mkdir -p "$PS4_GAME_DIR/sce_module"
    cp -f "$SDK_DIR/target/sce_module/libc.prx" "$PS4_GAME_DIR/sce_module/libc.prx"
  fi
  if [[ ! -f "$PS4_GAME_DIR/sce_module/libSceFios2.prx" && -f "$SDK_DIR/target/sce_module/libSceFios2.prx" ]]; then
    mkdir -p "$PS4_GAME_DIR/sce_module"
    cp -f "$SDK_DIR/target/sce_module/libSceFios2.prx" "$PS4_GAME_DIR/sce_module/libSceFios2.prx"
  fi

  if [[ -d "$CLIENT_DIR/OrbisMedia/DLC" ]]; then
    mkdir -p "$PS4_GAME_DIR/DLC"
    cp -af "$CLIENT_DIR/OrbisMedia/DLC/." "$PS4_GAME_DIR/DLC/"
  fi

  if [[ -d "$CLIENT_DIR/Orbis/DLCImages" ]]; then
    mkdir -p "$PS4_GAME_DIR/Orbis/DLCImages"
    cp -af "$CLIENT_DIR/Orbis/DLCImages/." "$PS4_GAME_DIR/Orbis/DLCImages/"
  fi
}

extract_sfo_field() {
  local field_name="$1"
  python3 - "$PS4_GAME_DIR/sce_sys/param.sfo" "$field_name" <<'PY'
import struct
import sys
from pathlib import Path

path = Path(sys.argv[1])
field = sys.argv[2]
data = path.read_bytes()

if data[:4] != b"\x00PSF":
    raise SystemExit("not a valid SFO file")

key_table_off, data_table_off, entry_count = struct.unpack_from("<III", data, 8)
entry_off = 20

for idx in range(entry_count):
    off = entry_off + idx * 16
    key_off, fmt, length, max_length, data_off = struct.unpack_from("<HHIII", data, off)
    key_end = data.index(b"\x00", key_table_off + key_off)
    key = data[key_table_off + key_off:key_end].decode("utf-8", "replace")
    if key != field:
        continue

    raw = data[data_table_off + data_off:data_table_off + data_off + max_length]
    if fmt in (0x0204, 0x0004):
        value = raw[:length].split(b"\x00", 1)[0].decode("utf-8", "replace")
    else:
        value = raw[:length].hex()
    print(value)
    break
PY
}

pkg() {
  require_file "$PS4_GAME_DIR/eboot.bin"
  require_file "$PS4_GAME_DIR/sce_sys/param.sfo"
  require_file "$FPKG_TOOLS_DIR/orbis-pub-cmd.exe"

  command -v wine >/dev/null 2>&1 || die "wine is required to run the fake PKG tools from bash"
  if [[ -z "$WINEPREFIX_PATH" ]]; then
    for candidate in "$HOME/.wine-orbis" "$HOME/.wine"; do
      if [[ -d "$candidate" ]]; then
        WINEPREFIX_PATH="$candidate"
        break
      fi
    done
  fi

  local content_id title_id
  content_id="$(extract_sfo_field CONTENT_ID)"
  title_id="$(extract_sfo_field TITLE_ID)"

  [[ -n "$content_id" ]] || die "could not extract CONTENT_ID from param.sfo"
  [[ -n "$title_id" ]] || die "could not extract TITLE_ID from param.sfo"

  mkdir -p "$OUTPUT_DIR"

  local app_dir gp4_path pkg_path
  app_dir="$OUTPUT_DIR/${title_id}-app"
  gp4_path="$OUTPUT_DIR/${title_id}.gp4"
  pkg_path="$OUTPUT_DIR/${title_id}.pkg"

  if command -v rsync >/dev/null 2>&1; then
    mkdir -p "$app_dir"
    rsync -a --delete "$PS4_GAME_DIR/" "$app_dir/"
  else
    rm -rf "$app_dir"
    mkdir -p "$app_dir"
    cp -a "$PS4_GAME_DIR/." "$app_dir/"
  fi

  "$SCRIPT_DIR/generate_ps4_gp4.py" \
    --app-dir "$app_dir" \
    --output "$gp4_path" \
    --content-id "$content_id" \
    --passcode "$PASSCODE"

  log "creating $(basename "$pkg_path")"
  (
    cd "$OUTPUT_DIR"
    WINEPREFIX="$WINEPREFIX_PATH" WINEDEBUG="${WINEDEBUG:--all}" \
      wine "$FPKG_TOOLS_DIR/orbis-pub-cmd.exe" img_create "$(basename "$gp4_path")" "$(basename "$pkg_path")"
  )

  log "pkg written to $pkg_path"
}

main() {
  local action="${1:-}"
  local config="${2:-Release}"

  case "$action" in
    build)
      build "$config"
      ;;
    stage)
      stage "$config"
      ;;
    pkg)
      pkg
      ;;
    all)
      build "$config"
      stage "$config"
      pkg
      ;;
    *)
      usage
      exit 1
      ;;
  esac
}

main "$@"
