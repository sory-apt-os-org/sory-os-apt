#!/usr/bin/env python3
"""Generate a deterministic SoryOS Release index for Debian packages.

Binary .deb assets live on GitHub Releases. The signed index is published
alongside them on the same immutable Release tag.
"""

from __future__ import annotations

import json
import os
import re
import subprocess
import sys
from pathlib import Path

MAX_ASSET_SIZE = 1 << 30
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
        fail("b3sum is required; refusing to generate a non-BLAKE3 index")
    except subprocess.CalledProcessError as exc:
        fail(f"cannot hash {path}: {exc}")
    return result.stdout.strip()


def package_name(path: Path) -> str:
    match = DEB_NAME.match(path.name)
    if not match:
        fail(f"unexpected .deb filename: {path.name}")
    return match.group("package")


def main() -> int:
    if len(sys.argv) not in (5, 6, 7):
        print(
            f"usage: {sys.argv[0]} <asset-root> <release-tag> "
            "<release-repository> <output-index> [base-url] [apt-public-key]",
            file=sys.stderr,
        )
        return 2

    root = Path(sys.argv[1]).resolve()
    tag = sys.argv[2]
    repository = sys.argv[3]
    output = Path(sys.argv[4]).resolve()
    base_url = sys.argv[5].rstrip("/") if len(sys.argv) >= 6 else ""
    if not root.is_dir():
        fail(f"asset root does not exist: {root}")
    if not tag or "/" in tag or ".." in tag:
        fail("release tag must be a non-empty immutable tag name")
    if not repository.count("/") == 1:
        fail("release repository must have the form owner/name")
    if not base_url:
        base_url = f"https://github.com/{repository}/releases/download/{tag}"

    assets = []
    packages: dict[str, dict] = {}
    for path in sorted(root.rglob("*.deb")):
        size = path.stat().st_size
        if size >= MAX_ASSET_SIZE:
            fail(f"asset is not below the 1 GiB policy: {path} ({size} bytes)")
        relative = path.relative_to(root).as_posix()
        asset = {
            "name": path.name,
            "url": f"{base_url}/{path.name}",
            "size": size,
            "blake3": blake3(path),
        }
        assets.append(asset)
        packages.setdefault(package_name(path), {})["deb"] = asset

    extra_files = [
        path
        for path in sorted(root.iterdir())
        if path.is_file() and path.suffix not in {".deb", ".tmp"}
        and path.name not in {"index.json", "index.json.sig"}
    ]
    for path in extra_files:
        size = path.stat().st_size
        if size >= MAX_ASSET_SIZE:
            fail(f"asset is not below the 1 GiB policy: {path} ({size} bytes)")
        assets.append(
            {
                "name": path.name,
                "url": f"{base_url}/{path.name}",
                "size": size,
                "blake3": blake3(path),
            }
        )

    if not assets:
        fail("release contains no assets")
    if len(assets) > 1000:
        fail("release contains more than GitHub's 1000-asset limit")

    apt_public_key = None
    if len(sys.argv) >= 7:
        key_path = Path(sys.argv[6]).resolve()
    else:
        key_path = root / "soryos-archive-keyring.gpg"
    if key_path.is_file():
        apt_public_key = {
            "name": key_path.name,
            "url": f"{base_url}/{key_path.name}",
            "size": key_path.stat().st_size,
            "blake3": blake3(key_path),
        }

    document = {
        "schema": 1,
        "format": "deb",
        "repository": repository,
        "release": {"tag": tag, "immutable": True},
        "assets": assets,
        "packages": packages,
        "apt_public_key": apt_public_key,
        "signature": {
            "url": f"{base_url}/index.json.sig",
            "public_key_url": f"{base_url}/index-signing-key.pub.pem",
            "runtime_public_key_url": f"{base_url}/index-signing-key.pub.hex",
        },
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    temporary = output.with_suffix(output.suffix + ".tmp")
    temporary.write_text(
        json.dumps(document, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    os.replace(temporary, output)
    print(f"generated {output} with {len(assets)} assets and {len(packages)} packages")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
