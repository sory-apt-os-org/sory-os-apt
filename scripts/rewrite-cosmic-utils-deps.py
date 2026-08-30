#!/usr/bin/env python3
"""Rewrite cosmic-utils git dependencies to local path deps."""

from __future__ import annotations

import os
import re
import sys
from pathlib import Path

COSMIC_UTILS_GIT = re.compile(
    r"https://(?:github\.com|gitlab\.com)/(?:cosmic-utils|sory-os-org|sory-os\.org)/([A-Za-z0-9_.-]+)(?:\.git)?"
)


def rel(cargo_file: Path, target: Path) -> str:
    return os.path.relpath(target, cargo_file.parent).replace("\\", "/")


def strip_git_keys(inner: str) -> str:
    inner = re.sub(r',?\s*(?:git|branch|rev|tag)\s*=\s*(?:"[^"]*"|\'[^\']*\')', "", inner)
    inner = re.sub(r",\s*,", ",", inner)
    return inner.strip().strip(",")


def rewrite_inline_tables(text: str, cargo_file: Path, utils_dir: Path) -> str:
    def repl(match: re.Match[str]) -> str:
        dep = match.group(1)
        inner = match.group(2)
        git_match = COSMIC_UTILS_GIT.search(inner)
        if not git_match:
            return match.group(0)
        repo = git_match.group(1)
        target = utils_dir / repo
        if not target.is_dir():
            return match.group(0)
        rest = strip_git_keys(inner)
        path = rel(cargo_file, target)
        if rest:
            return f"{dep} = {{ path = \"{path}\", {rest} }}"
        return f'{dep} = {{ path = "{path}" }}'

    return re.sub(
        r"^(\s*)([A-Za-z0-9_-]+)\s*=\s*\{([^}]*)\}\s*$",
        repl,
        text,
        flags=re.MULTILINE,
    )


def rewrite_table_sections(text: str, cargo_file: Path, utils_dir: Path) -> str:
    lines = text.splitlines()
    out: list[str] = []
    i = 0
    while i < len(lines):
        line = lines[i]
        header = re.match(r"^\[([^\]]+)\]$", line)
        if not header:
            out.append(line)
            i += 1
            continue
        section = header.group(1)
        block = [line]
        i += 1
        body: list[str] = []
        while i < len(lines) and not lines[i].startswith("["):
            body.append(lines[i])
            i += 1
        # Process sections: [dependencies.X], [target.'cfg(...)'.dependencies.X], etc.
        # Skip only [target.X] / [dev-dependencies] / other non-dependency sections.
        is_dep_section = (
            section == "dependencies"
            or section.startswith("dependencies.")
            or ".dependencies." in section
            or section.startswith("build-dependencies.")
            or ".build-dependencies." in section
            or section.startswith("dev-dependencies.")
            or ".dev-dependencies." in section
        )
        if not is_dep_section:
            out.extend(block + body)
            continue
        # For bare [dependencies] (no .X), keep as is
        bare_deps = (
            section == "dependencies"
            or section == "dev-dependencies"
            or section == "build-dependencies"
        )
        if bare_deps:
            out.extend(block + body)
            continue
        git_line = next((row for row in body if "git =" in row or "git=" in row), None)
        if not git_line:
            out.extend(block + body)
            continue
        git_match = COSMIC_UTILS_GIT.search(git_line)
        if not git_match:
            out.extend(block + body)
            continue
        repo = git_match.group(1)
        target = utils_dir / repo
        if not target.is_dir():
            out.extend(block + body)
            continue
        kept = [
            row
            for row in body
            if not re.search(r"^\s*(?:git|branch|rev|tag)\s*=", row)
        ]
        indent = "    "
        path = rel(cargo_file, target)
        kept = [f'{indent}path = "{path}"'] + [
            row for row in kept if row.strip() and not row.strip().startswith("path =")
        ]
        out.append(line)
        out.extend(kept)
    return "\n".join(out) + ("\n" if text.endswith("\n") else "")


def main() -> int:
    if len(sys.argv) < 2:
        print(f"usage: {sys.argv[0]} <cosmic-utils-dir>", file=sys.stderr)
        return 2
    utils_dir = Path(sys.argv[1]).resolve()
    changed = 0
    for cargo_file in utils_dir.rglob("Cargo.toml"):
        if "target" in cargo_file.parts:
            continue
        original = cargo_file.read_text()
        updated = rewrite_inline_tables(original, cargo_file, utils_dir)
        updated = rewrite_table_sections(updated, cargo_file, utils_dir)
        if updated != original:
            cargo_file.write_text(updated)
            changed += 1
            print(f"rewrote cosmic-utils deps in {cargo_file}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
