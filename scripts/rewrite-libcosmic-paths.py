#!/usr/bin/env python3
"""Rewrite pop-os/sory-os-org libcosmic git deps to local path deps."""

from __future__ import annotations

import os
import re
import sys
from pathlib import Path

LIBCOSMIC_GIT = re.compile(
    r"https://github\.com/(?:pop-os|sory-os-org)/libcosmic(?:\.git)?/?"
)

CRATE_DIRS: dict[str, str] = {
    "libcosmic": "",
    "cosmic-config": "cosmic-config",
    "cosmic-theme": "cosmic-theme",
    "iced_futures": "iced/futures",
    "iced_winit": "iced/winit",
}


def crate_dir(libcosmic: Path, dep_name: str) -> Path:
    sub = CRATE_DIRS.get(dep_name, dep_name.replace("_", "-"))
    if dep_name == "libcosmic":
        return libcosmic
    return libcosmic / sub


def rel_path(cargo_file: Path, target: Path) -> str:
    return os.path.relpath(target, cargo_file.parent).replace("\\", "/")


def strip_git_keys(inner: str) -> str:
    inner = LIBCOSMIC_GIT.sub("", inner)
    inner = re.sub(r',?\s*(?:git|branch|rev|tag)\s*=\s*(?:"[^"]*"|\'[^\']*\')', "", inner)
    inner = re.sub(r",\s*,", ",", inner)
    return inner.strip().strip(",")


def rewrite_inline_tables(text: str, cargo_file: Path, libcosmic: Path) -> str:
    def repl(match: re.Match[str]) -> str:
        dep_name = match.group(1)
        inner = match.group(2)
        if not LIBCOSMIC_GIT.search(inner):
            return match.group(0)
        path = rel_path(cargo_file, crate_dir(libcosmic, dep_name))
        rest = strip_git_keys(inner)
        if rest:
            return f'{dep_name} = {{ path = "{path}", {rest} }}'
        return f'{dep_name} = {{ path = "{path}" }}'

    return re.sub(
        r"(?m)^([A-Za-z0-9_-]+)\s*=\s*\{([^}]*)\}\s*$",
        repl,
        text,
    )


def rewrite_table_sections(text: str, cargo_file: Path, libcosmic: Path) -> str:
    lines = text.splitlines()
    out: list[str] = []
    i = 0
    while i < len(lines):
        line = lines[i]
        header = re.match(
            r"^\[(?:dependencies|dev-dependencies|build-dependencies|workspace\.dependencies|patch\.[^\]]+)\.([A-Za-z0-9_-]+)\]\s*$",
            line,
        )
        if not header:
            out.append(line)
            i += 1
            continue

        dep_name = header.group(1)
        section = [line]
        i += 1
        while i < len(lines) and not lines[i].startswith("["):
            section.append(lines[i])
            i += 1

        body = "\n".join(section)
        if not LIBCOSMIC_GIT.search(body):
            out.extend(section)
            continue

        path = rel_path(cargo_file, crate_dir(libcosmic, dep_name))
        new_section = [section[0]]
        skip_keys = {"git", "branch", "rev", "tag"}
        inserted_path = False
        for body_line in section[1:]:
            key_match = re.match(r"^(\s*)([A-Za-z0-9_-]+)\s*=", body_line)
            if key_match and key_match.group(2) in skip_keys:
                continue
            if key_match and key_match.group(2) == "path":
                new_section.append(f'{key_match.group(1)}path = "{path}"')
                inserted_path = True
                continue
            new_section.append(body_line)
        if not inserted_path:
            indent = "    "
            if len(section) > 1:
                m = re.match(r"^(\s*)", section[1])
                if m:
                    indent = m.group(1)
            new_section.insert(1, f'{indent}path = "{path}"')
        out.extend(new_section)

    return "\n".join(out)


PATCH_SOURCES = (
    "https://github.com/pop-os/libcosmic.git",
    "https://github.com/sory-os-org/libcosmic.git",
)

PATCH_SECTION_RE = re.compile(
    r"\n\[patch\.'[^']*libcosmic[^']*'\](?:\n(?!#*\[).*)*",
    re.MULTILINE,
)


def needs_libcosmic_patches(text: str) -> bool:
    return "libcosmic" in text and (
        LIBCOSMIC_GIT.search(text) is not None
        or "/libcosmic" in text
        or "pop-os/cosmic-settings" in text
    )


def remove_libcosmic_patch_sections(text: str) -> str:
    return PATCH_SECTION_RE.sub("", text)


def patch_block(cargo_file: Path, libcosmic: Path, source_url: str) -> str:
    lines = [f"[patch.'{source_url}']"]
    for crate, sub in CRATE_DIRS.items():
        target = libcosmic / sub if sub else libcosmic
        path = rel_path(cargo_file, target)
        lines.append(f'{crate} = {{ path = "{path}" }}')
    return "\n".join(lines)


def ensure_libcosmic_patches(cargo_file: Path, libcosmic: Path) -> bool:
    original = cargo_file.read_text()
    if not needs_libcosmic_patches(original):
        return False

    updated = remove_libcosmic_patch_sections(original).rstrip()
    blocks = [patch_block(cargo_file, libcosmic, url) for url in PATCH_SOURCES]
    updated = updated + "\n\n" + "\n\n".join(blocks) + "\n"
    if updated != original:
        cargo_file.write_text(updated)
        return True
    return False


def rewrite_file(cargo_file: Path, libcosmic: Path) -> bool:
    original = cargo_file.read_text()
    updated = rewrite_inline_tables(original, cargo_file, libcosmic)
    updated = rewrite_table_sections(updated, cargo_file, libcosmic)
    changed = updated != original
    if changed:
        cargo_file.write_text(updated)
    return changed or ensure_libcosmic_patches(cargo_file, libcosmic)


def main() -> int:
    if len(sys.argv) < 2:
        print(f"usage: {sys.argv[0]} <cosmic-epoch-dir> [libcosmic-dir]", file=sys.stderr)
        return 2

    cosmic_epoch = Path(sys.argv[1]).resolve()
    libcosmic = (
        Path(sys.argv[2]).resolve()
        if len(sys.argv) > 2
        else cosmic_epoch.parent / "libcosmic"
    )
    if not libcosmic.is_dir():
        print(f"libcosmic not found: {libcosmic}", file=sys.stderr)
        return 1

    changed = 0
    for cargo_file in cosmic_epoch.rglob("Cargo.toml"):
        if "target" in cargo_file.parts:
            continue
        if rewrite_file(cargo_file, libcosmic):
            changed += 1

    for lock_file in cosmic_epoch.rglob("Cargo.lock"):
        if "target" in lock_file.parts:
            continue
        lock_file.unlink()

    print(f"rewrote libcosmic deps in {changed} Cargo.toml files under {cosmic_epoch}")
    print(f"removed Cargo.lock files under {cosmic_epoch}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
