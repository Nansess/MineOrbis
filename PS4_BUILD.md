# PS4 Build Flow

This repo contains the scripts and project wiring needed for a PS4 build.

Expected local inputs:

- an ORBIS SDK at `SCE_ORBIS_SDK_DIR`
- optional fake PKG tools at `PS4_FPKG_TOOLS_DIR`
- `Minecraft.World/Minecraft.World.vcxproj` builds the world static lib
- `Minecraft.Client/Minecraft.Client.vcxproj` builds the client ELF/SELF
- `Minecraft.Client/PS4_GAME/` is the staged app folder used for packaging

The helper scripts default to repo-local bundles when present:

- `third_party/orbis-wine/sdk/sdk`
- `third_party/orbis-wine/toolchain`
- `PS4_Fake_PKG_Tools_3.87_V7/`

## Commands

From the repo root:

```bash
./scripts/ps4.sh build Release
./scripts/ps4.sh stage Release
./scripts/ps4.sh pkg
./scripts/ps4.sh all Release
```

`all` does:

1. Build `Minecraft.World` for `ORBIS`
2. Build `Minecraft.Client` for `ORBIS`
3. Copy the newest client artifact into `Minecraft.Client/PS4_GAME/eboot.bin`
4. Copy `PS4_GAME` into `build/ps4/<TITLE_ID>-app`
5. Generate `build/ps4/<TITLE_ID>.gp4`
6. Build `build/ps4/<TITLE_ID>.pkg`

## Required Tooling

The scripts expect an ORBIS-capable MSBuild plus `wine` for the fake PKG tools.

If MSBuild is not detected, set:

```bash
export PS4_MSBUILD="$HOME/.wine/drive_c/Program Files (x86)/MSBuild/14.0/Bin/MSBuild.exe"
export PS4_MSBUILD_MODE=wine
```

If you are not using the repo-local defaults, override the tool paths explicitly:

```bash
export SCE_ORBIS_SDK_DIR="/path/to/orbis-sdk"
export PS4_FPKG_TOOLS_DIR="/path/to/PS4_Fake_PKG_Tools"
```

## Notes

- The packaging step reads `CONTENT_ID` and `TITLE_ID` from `Minecraft.Client/PS4_GAME/sce_sys/param.sfo`.
- Output names are derived from the staged `param.sfo`, not hardcoded in the docs.
- The GP4 is generated locally by `scripts/generate_ps4_gp4.py`, so you do not need `gengp4_app.exe`.
- If your ORBIS toolchain emits a different client filename, `stage` searches the expected `ORBIS_<Config>` output directory and copies the newest `.elf`, `.self`, or `eboot.bin`.
