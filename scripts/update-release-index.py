#!/usr/bin/env python3
"""Merge newly built .deb packages into an existing signed SoryOS Release index."""

from __future__ import annotations

import json
import os
import re
import subprocess
import sys
from pathlib import Path

DEB_NAME = re.compile(
    r"^(?P<package>[A-Za-z0-9+.-]+)_(?P<version>[^_]+)_(?P<arch>[A-Za-z0-9-]+)\.deb$"
)


def fail(message: str) -> "NoReturn":
    print(f"error: {message}", file=sys.stderr)
    raise SystemExit(1)


def blake3(path: Path) -> str:
    try:
        result = subprocess.run(
            ["b3sum", "--no-names", str(path)],
            check=True,
            capture_output=True,
            text=True,
        )
    except FileNotFoundError:
        fail("b3sum is required; refusing to update a non-BLAKE3 index")
    except subprocess.CalledProcessError as exc:
        fail(f"cannot hash {path}: {exc}")
    return result.stdout.strip()


def make_asset(release_base: str, path: Path) -> dict:
    size = path.stat().st_size
    if size >= (1 << 30):
        fail(f"asset is not below the 1 GiB policy: {path} ({size} bytes)")
    return {
        "name": path.name,
        "url": f"{release_base}/{path.name}",
        "size": size,
        "blake3": blake3(path),
    }


def package_name(path: Path) -> str:
    match = DEB_NAME.match(path.name)
    if not match:
        fail(f"unexpected .deb filename: {path.name}")
    return match.group("package")


def main() -> int:
    if len(sys.argv) != 5:
        print(
            f"usage: {sys.argv[0]} <existing-index> <new-packages-dir> "
            "<output-index> <release-tag>",
            file=sys.stderr,
        )
        return 2

    index_path = Path(sys.argv[1]).resolve()
    packages_dir = Path(sys.argv[2]).resolve()
    output = Path(sys.argv[3]).resolve()
    tag = sys.argv[4]

    if not index_path.is_file():
        fail(f"existing index does not exist: {index_path}")
    if not packages_dir.is_dir():
        fail(f"new packages dir does not exist: {packages_dir}")
    if not tag or "/" in tag or ".." in tag:
        fail("release tag must be a non-empty immutable tag name")

    try:
        document = json.loads(index_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        fail(f"existing index is not valid JSON: {exc}")

    if document.get("schema") != 1:
        fail("existing index is not a schema 1 document")
    if document.get("format") != "deb":
        fail("existing index is not a deb-format document")
    if not document.get("release", {}).get("immutable"):
        fail("existing index is not marked immutable")

    repository = document.get("repository")
    if not repository or repository.count("/") != 1:
        fail("existing index has an invalid repository field")

    release_base = f"https://github.com/{repository}/releases/download/{tag}"

    new_debs = sorted(packages_dir.glob("*.deb"))
    if not new_debs:
        fail("no new .deb packages found in the build directory")

    assets = document.setdefault("assets", [])
    packages = document.setdefault("packages", {})
    changed = []

    for path in new_debs:
        deb_asset = make_asset(release_base, path)
        replaced = False
        for existing in assets:
            if existing["name"] == deb_asset["name"]:
                existing.update(deb_asset)
                replaced = True
                break
        if not replaced:
            assets.append(deb_asset)

        name = package_name(path)
        packages.setdefault(name, {})["deb"] = deb_asset
        changed.append(name)

    output.parent.mkdir(parents=True, exist_ok=True)
    temporary = output.with_suffix(output.suffix + ".tmp")
    temporary.write_text(
        json.dumps(document, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    os.replace(temporary, output)
    print(
        f"updated {output} with {len(assets)} assets; "
        f"changed packages: {', '.join(changed)}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
