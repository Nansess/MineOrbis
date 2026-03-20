#!/usr/bin/env python3

from __future__ import annotations

import argparse
from datetime import datetime
from pathlib import Path
from xml.sax.saxutils import escape


def xml_attr(value: str) -> str:
    return escape(value, {'"': "&quot;"})


def build_rootdir_lines(app_dir: Path, indent: str = "  ") -> list[str]:
    def walk(dir_path: Path, depth: int) -> list[str]:
        lines: list[str] = []
        for child in sorted(p for p in dir_path.iterdir() if p.is_dir()):
            pad = indent * depth
            lines.append(f'{pad}<dir targ_name="{xml_attr(child.name)}">')
            lines.extend(walk(child, depth + 1))
            lines.append(f"{pad}</dir>")
        return lines

    return walk(app_dir, 2)


def build_file_lines(app_dir: Path) -> list[str]:
    lines: list[str] = []
    prefix = app_dir.name
    for path in sorted(p for p in app_dir.rglob("*") if p.is_file()):
        rel = path.relative_to(app_dir)
        targ_path = rel.as_posix()
        orig_path = f"{prefix}\\{str(rel).replace('/', '\\')}"
        lines.append(
            f'    <file targ_path="{xml_attr(targ_path)}" '
            f'orig_path="{xml_attr(orig_path)}"/>'
        )
    return lines


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate a PS4 GP4 project file.")
    parser.add_argument("--app-dir", required=True, help="Path to the staged app directory")
    parser.add_argument("--output", required=True, help="Path to write the GP4 file")
    parser.add_argument("--content-id", required=True, help="PS4 content ID")
    parser.add_argument("--passcode", required=True, help="32-character package passcode")
    parser.add_argument(
        "--volume-ts",
        default=datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        help="Timestamp to embed in the GP4 metadata",
    )
    args = parser.parse_args()

    app_dir = Path(args.app_dir).resolve()
    output = Path(args.output).resolve()

    if not app_dir.is_dir():
        raise SystemExit(f"app dir does not exist: {app_dir}")

    file_lines = build_file_lines(app_dir)
    rootdir_lines = build_rootdir_lines(app_dir)

    lines = [
        '<?xml version="1.0" encoding="utf-8" standalone="yes"?>',
        '<psproject fmt="gp4" version="1000">',
        "  <volume>",
        "    <volume_type>pkg_ps4_app</volume_type>",
        "    <volume_id></volume_id>",
        f"    <volume_ts>{xml_attr(args.volume_ts)}</volume_ts>",
        (
            '    <package content_id="{}" passcode="{}" '
            'storage_type="bd25" app_type="full"/>'
        ).format(xml_attr(args.content_id), xml_attr(args.passcode)),
        '    <chunk_info chunk_count="1" scenario_count="1">',
        '      <chunks supported_languages="">',
        '        <chunk id="0" layer_no="0" label=""/>',
        "      </chunks>",
        '      <scenarios default_id="0">',
        '        <scenario id="0" type="sp" initial_chunk_count="1" label="Scenario #0">0</scenario>',
        "      </scenarios>",
        "    </chunk_info>",
        "  </volume>",
        '  <files img_no="0">',
        *file_lines,
        "  </files>",
        "  <rootdir>",
        *rootdir_lines,
        "  </rootdir>",
        "</psproject>",
        "",
    ]

    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text("\n".join(lines), encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
