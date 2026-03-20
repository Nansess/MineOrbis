#!/usr/bin/env python3

from __future__ import annotations

import argparse
import os
import xml.etree.ElementTree as ET
from pathlib import Path

NS = {"m": "http://schemas.microsoft.com/developer/msbuild/2003"}


def xml_text(elem: ET.Element | None, name: str) -> str:
    if elem is None:
        return ""
    child = elem.find(f"m:{name}", NS)
    return child.text.strip() if child is not None and child.text else ""


def matching_condition(condition: str, config: str, platform: str) -> bool:
    return f"'$(Configuration)|$(Platform)'=='{config}|{platform}'" in condition


def normalize_path(value: str) -> str:
    return value.replace("\\", "/")


def split_semicolon_list(value: str) -> list[str]:
    parts = []
    for item in value.split(";"):
        item = item.strip()
        if not item or item.startswith("%("):
            continue
        parts.append(item)
    return parts


def cmake_quote(value: str) -> str:
    return value.replace("\\", "\\\\").replace('"', '\\"')


def collect_sources(root: ET.Element, config: str, platform: str) -> list[str]:
    sources: list[str] = []
    seen: set[str] = set()
    for elem in root.findall(".//m:ClCompile", NS):
        include = elem.attrib.get("Include")
        if not include:
            continue
        excluded = False
        for ex in elem.findall("m:ExcludedFromBuild", NS):
            cond = ex.attrib.get("Condition", "")
            text = (ex.text or "").strip().lower()
            if matching_condition(cond, config, platform) and text == "true":
                excluded = True
                break
        if excluded:
            continue
        include = normalize_path(include)
        if include not in seen:
            sources.append(include)
            seen.add(include)
    return sources


def collect_include_dirs(root: ET.Element, config: str, platform: str) -> list[str]:
    includes: list[str] = []
    seen: set[str] = set()

    for pg in root.findall(".//m:PropertyGroup", NS):
        cond = pg.attrib.get("Condition", "")
        if matching_condition(cond, config, platform):
            for item in split_semicolon_list(xml_text(pg, "IncludePath")):
                if item not in seen:
                    includes.append(item)
                    seen.add(item)

    for idg in root.findall(".//m:ItemDefinitionGroup", NS):
        cond = idg.attrib.get("Condition", "")
        if not matching_condition(cond, config, platform):
            continue
        cc = idg.find("m:ClCompile", NS)
        for item in split_semicolon_list(xml_text(cc, "AdditionalIncludeDirectories")):
            if item not in seen:
                includes.append(item)
                seen.add(item)

    return includes


def collect_defines(root: ET.Element, config: str, platform: str) -> list[str]:
    defines: list[str] = []
    seen: set[str] = set()
    for idg in root.findall(".//m:ItemDefinitionGroup", NS):
        cond = idg.attrib.get("Condition", "")
        if not matching_condition(cond, config, platform):
            continue
        cc = idg.find("m:ClCompile", NS)
        for item in split_semicolon_list(xml_text(cc, "PreprocessorDefinitions")):
            if item not in seen:
                defines.append(item)
                seen.add(item)
    return defines


def collect_link_dependencies(root: ET.Element, config: str, platform: str) -> list[str]:
    deps: list[str] = []
    seen: set[str] = set()
    for idg in root.findall(".//m:ItemDefinitionGroup", NS):
        cond = idg.attrib.get("Condition", "")
        if not matching_condition(cond, config, platform):
            continue
        link = idg.find("m:Link", NS)
        for item in split_semicolon_list(xml_text(link, "AdditionalDependencies")):
            if item not in seen:
                deps.append(item)
                seen.add(item)
    return deps


def collect_compile_settings(root: ET.Element, config: str, platform: str) -> dict[str, str]:
    settings: dict[str, str] = {}
    wanted = (
        "RuntimeTypeInfo",
        "ExceptionHandling",
        "OptimizationLevel",
        "FastMath",
        "AdditionalOptions",
    )
    for idg in root.findall(".//m:ItemDefinitionGroup", NS):
        cond = idg.attrib.get("Condition", "")
        if not matching_condition(cond, config, platform):
            continue
        cc = idg.find("m:ClCompile", NS)
        if cc is None:
            continue
        for name in wanted:
            value = xml_text(cc, name)
            if value:
                settings[name] = value
    return settings


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", required=True)
    parser.add_argument("--config", default="Release")
    parser.add_argument("--platform", default="ORBIS")
    parser.add_argument("--output", required=True)
    parser.add_argument("--var-prefix", required=True)
    args = parser.parse_args()

    project = Path(args.project).resolve()
    project_dir = project.parent
    root = ET.parse(project).getroot()

    sources = collect_sources(root, args.config, args.platform)
    include_dirs = collect_include_dirs(root, args.config, args.platform)
    defines = collect_defines(root, args.config, args.platform)
    link_deps = collect_link_dependencies(root, args.config, args.platform)
    compile_settings = collect_compile_settings(root, args.config, args.platform)

    out = Path(args.output).resolve()
    out.parent.mkdir(parents=True, exist_ok=True)

    prefix = args.var_prefix.upper()
    lines = [
        f"set({prefix}_PROJECT_DIR \"{cmake_quote(str(project_dir))}\")",
        f"set({prefix}_SOURCES",
    ]
    for src in sources:
        lines.append(f'  "${{{prefix}_PROJECT_DIR}}/{cmake_quote(src)}"')
    lines.append(")")

    lines.append(f"set({prefix}_INCLUDE_DIRS")
    for inc in include_dirs:
        lines.append(f'  "{cmake_quote(inc)}"')
    lines.append(")")

    lines.append(f"set({prefix}_DEFINES")
    for define in defines:
        lines.append(f'  "{cmake_quote(define)}"')
    lines.append(")")

    lines.append(f"set({prefix}_LINK_DEPS")
    for dep in link_deps:
        lines.append(f'  "{cmake_quote(dep)}"')
    lines.append(")")

    lines.append(f"set({prefix}_COMPILE_SETTINGS")
    for key, value in compile_settings.items():
        lines.append(f'  "{cmake_quote(key)}={cmake_quote(value)}"')
    lines.append(")")
    lines.append("")

    out.write_text("\n".join(lines), encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
