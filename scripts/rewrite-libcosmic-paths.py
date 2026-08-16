#!/usr/bin/env python3
"""Rewrite sory-os-org libcosmic git deps to local path deps."""

from __future__ import annotations

import os
import re
import sys
from pathlib import Path

LIBCOSMIC_GIT = re.compile(
    r"https://github\.com/(?:pop-os|sory-os-org)/libcosmic(?:\.git)?/?"
)

SETTINGS_GIT = re.compile(
    r"https://github\.com/pop-os/cosmic-settings(?:-daemon)?(?:\.git)?/?"
)

SETTINGS_CRATE_DIRS: dict[str, str] = {
    "cosmic-settings-airplane-mode-subscription": "cosmic-settings/subscriptions/airplane-mode",
    "cosmic-settings-upower-subscription": "cosmic-settings/subscriptions/upower",
    "cosmic-settings-daemon-subscription": "cosmic-settings/subscriptions/settings-daemon",
    "cosmic-settings-audio-client": "cosmic-settings-daemon/audio-client",
    "cosmic-settings-accessibility-subscription": "cosmic-settings/subscriptions/accessibility",
    "cosmic-settings-a11y-manager-subscription": "cosmic-settings/subscriptions/a11y-manager",
    "cosmic-settings-bluetooth-subscription": "cosmic-settings/subscriptions/bluetooth",
}

EPOCH_CRATE_DIRS: dict[str, str] = {
    "cosmic-bg-config": "cosmic-bg/config",
    "cosmic-comp-config": "cosmic-comp/cosmic-comp-config",
    "cosmic-panel-config": "cosmic-panel/cosmic-panel-config",
    "cosmic-notifications-util": "cosmic-notifications/util",
    "cosmic-notifications-config": "cosmic-notifications/config",
    "cosmic-randr": "cosmic-randr/lib",
    "cosmic-randr-shell": "cosmic-randr/shell",
    "cosmic-settings-config": "cosmic-settings-daemon/config",
    "cosmic-idle-config": "cosmic-idle/cosmic-idle-config",
    "cosmic-settings-network-manager-subscription": "cosmic-settings/subscriptions/network-manager",
    "cosmic-app-list-config": "cosmic-applets/cosmic-app-list/cosmic-app-list-config",
    "cosmic-applets-config": "cosmic-applets/cosmic-applets-config",
    "cosmic-client-toolkit": "cosmic-protocols/client-toolkit",
    "cctk": "cosmic-protocols/client-toolkit",
    "freedesktop-icons": "freedesktop-icons",
    "cosmic-freedesktop-icons": "freedesktop-icons",
    "xdg-shell-wrapper-config": "xdg-shell-wrapper/xdg-shell-wrapper-config",
    "xdg-shell-wrapper": "xdg-shell-wrapper",
}

DBUS_SETTINGS_GIT = re.compile(
    r"https://github\.com/pop-os/dbus-settings-bindings(?:\.git)?"
)

DBUS_SETTINGS_CRATE_DIRS: dict[str, str] = {
    "cosmic-dbus-a11y": "dbus-settings-bindings/a11y",
    "bluez-zbus": "dbus-settings-bindings/bluez",
    "locale1": "dbus-settings-bindings/locale1",
    "mpris2-zbus": "dbus-settings-bindings/mpris2",
    "cosmic-dbus-networkmanager": "dbus-settings-bindings/networkmanager",
    "timedate-zbus": "dbus-settings-bindings/timedate",
    "upower_dbus": "dbus-settings-bindings/upower",
    "switcheroo-control": "dbus-settings-bindings/switcheroo-control",
    "accounts-zbus": "dbus-settings-bindings/accounts-zbus",
    "hostname1-zbus": "dbus-settings-bindings/hostname1",
    "nm-secret-agent-manager": "dbus-settings-bindings/nm-secret-agent-manager",
    "geoclue2": "dbus-settings-bindings/geoclue2",
}

VIRTUAL_EPOCH_REPOS = frozenset(
    {
        "dbus-settings-bindings",
        "cosmic-randr",
        "cosmic-applets",
        "cosmic-settings-daemon",
        "cosmic-settings",
    }
)

FREEDESKTOP_ICONS_GIT = re.compile(
    r"https://github\.com/pop-os/freedesktop-icons(?:\.git)?"
)

POP_OS_VENDOR_GIT_REPLACEMENTS: tuple[tuple[re.Pattern[str], str], ...] = (
    (re.compile(r"https://github\.com/pop-os/winit(?:\.git)?"), "https://github.com/sory-os-org/winit"),
    (
        re.compile(r"https://github\.com/pop-os/smithay-clipboard(?:\.git)?"),
        "https://github.com/sory-os-org/smithay-clipboard",
    ),
    (
        re.compile(r"https://github\.com/pop-os/dbus-settings-bindings(?:\.git)?"),
        "https://github.com/sory-os-org/dbus-settings-bindings",
    ),
    (
        re.compile(r"https://github\.com/pop-os/xdg-shell-wrapper(?:\.git)?"),
        "https://github.com/sory-os-org/xdg-shell-wrapper",
    ),
)


def migrate_pop_os_vendor_git_urls(text: str) -> str:
    for pattern, replacement in POP_OS_VENDOR_GIT_REPLACEMENTS:
        text = pattern.sub(replacement, text)
    return text


def is_workspace_root(cargo_file: Path) -> bool:
    return "[workspace]" in cargo_file.read_text() and "members" in cargo_file.read_text()


POP_OS_EPOCH_GIT = re.compile(
    r"https://github\.com/pop-os/([A-Za-z0-9_-]+)(?:\.git)?"
)

CRATE_DIRS: dict[str, str] = {
    "libcosmic": "",
    "cosmic-config": "cosmic-config",
    "cosmic-theme": "cosmic-theme",
    "iced_futures": "iced/futures",
    "iced_winit": "iced/winit",
}


def crate_dir(libcosmic: Path, dep_name: str) -> Path:
    if dep_name == "libcosmic":
        return libcosmic
    if dep_name in CRATE_DIRS:
        sub = CRATE_DIRS[dep_name]
    elif dep_name.startswith("iced_"):
        sub = "iced/" + dep_name[len("iced_") :]
    else:
        sub = dep_name.replace("_", "-")
    return libcosmic / sub


def epoch_crate_dir(cosmic_epoch: Path, dep_name: str, inner: str) -> Path | None:
    if dep_name in EPOCH_CRATE_DIRS:
        return cosmic_epoch / EPOCH_CRATE_DIRS[dep_name]
    if dep_name in SETTINGS_CRATE_DIRS:
        target = cosmic_epoch / SETTINGS_CRATE_DIRS[dep_name]
        return target if target.is_dir() else None
    if FREEDESKTOP_ICONS_GIT.search(inner):
        return cosmic_epoch / "freedesktop-icons"
    if DBUS_SETTINGS_GIT.search(inner):
        sub = DBUS_SETTINGS_CRATE_DIRS.get(dep_name)
        if not sub:
            return None
        return cosmic_epoch / sub
    match = POP_OS_EPOCH_GIT.search(inner)
    if not match:
        return None
    repo = match.group(1)
    if repo in VIRTUAL_EPOCH_REPOS:
        return None
    candidate = cosmic_epoch / repo
    if candidate.is_dir():
        return candidate
    return None


def rel_path(cargo_file: Path, target: Path) -> str:
    return os.path.relpath(target, cargo_file.parent).replace("\\", "/")


def settings_dir(cosmic_epoch: Path, dep_name: str) -> Path | None:
    sub = SETTINGS_CRATE_DIRS.get(dep_name)
    if not sub:
        return None
    return cosmic_epoch / sub


def strip_repo_git_keys(inner: str, *patterns: re.Pattern[str]) -> str:
    for pattern in patterns:
        inner = pattern.sub("", inner)
    inner = re.sub(r',?\s*(?:git|branch|rev|tag)\s*=\s*(?:"[^"]*"|\'[^\']*\')', "", inner)
    inner = re.sub(r",\s*,", ",", inner)
    return inner.strip().strip(",")


def strip_git_keys(inner: str) -> str:
    return strip_repo_git_keys(inner, LIBCOSMIC_GIT)


def rewrite_inline_tables(
    text: str, cargo_file: Path, libcosmic: Path, cosmic_epoch: Path
) -> str:
    def repl(match: re.Match[str]) -> str:
        dep_name = match.group(1)
        inner = match.group(2)
        if LIBCOSMIC_GIT.search(inner):
            path = rel_path(cargo_file, crate_dir(libcosmic, dep_name))
            rest = strip_repo_git_keys(inner, LIBCOSMIC_GIT)
        elif SETTINGS_GIT.search(inner) and dep_name in SETTINGS_CRATE_DIRS:
            target = settings_dir(cosmic_epoch, dep_name)
            if target is None or not target.is_dir():
                return match.group(0)
            path = rel_path(cargo_file, target)
            rest = strip_repo_git_keys(inner, SETTINGS_GIT)
        elif POP_OS_EPOCH_GIT.search(inner) or SETTINGS_GIT.search(inner) or DBUS_SETTINGS_GIT.search(inner) or FREEDESKTOP_ICONS_GIT.search(inner):
            target = epoch_crate_dir(cosmic_epoch, dep_name, inner)
            if target is None and SETTINGS_GIT.search(inner):
                target = settings_dir(cosmic_epoch, dep_name)
            if target is None or not target.is_dir():
                return match.group(0)
            path = rel_path(cargo_file, target)
            rest = strip_repo_git_keys(
                inner, POP_OS_EPOCH_GIT, SETTINGS_GIT, DBUS_SETTINGS_GIT, FREEDESKTOP_ICONS_GIT
            )
        else:
            return match.group(0)
        if rest:
            return f'{dep_name} = {{ path = "{path}", {rest} }}'
        return f'{dep_name} = {{ path = "{path}" }}'

    return re.sub(
        r"(?m)^([A-Za-z0-9_-]+)\s*=\s*\{([^}]*)\}\s*$",
        repl,
        text,
    )


def rewrite_table_sections(
    text: str, cargo_file: Path, libcosmic: Path, cosmic_epoch: Path
) -> str:
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
        settings_target = settings_dir(cosmic_epoch, dep_name)
        epoch_target = epoch_crate_dir(cosmic_epoch, dep_name, body)
        if LIBCOSMIC_GIT.search(body):
            path = rel_path(cargo_file, crate_dir(libcosmic, dep_name))
        elif SETTINGS_GIT.search(body) and settings_target is not None:
            path = rel_path(cargo_file, settings_target)
        elif epoch_target is not None and epoch_target.is_dir():
            path = rel_path(cargo_file, epoch_target)
        else:
            out.extend(section)
            continue

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
    "https://github.com/pop-os/libcosmic",
    "https://github.com/pop-os/libcosmic.git",
    "https://github.com/sory-os-org/libcosmic",
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
    patched: set[str] = set()
    for crate, sub in CRATE_DIRS.items():
        target = libcosmic / sub if sub else libcosmic
        path = rel_path(cargo_file, target)
        lines.append(f'{crate} = {{ path = "{path}" }}')
        patched.add(crate)
    iced_root = libcosmic / "iced"
    if iced_root.is_dir():
        for iced_crate in sorted(iced_root.iterdir()):
            if not iced_crate.is_dir():
                continue
            cargo_toml = iced_crate / "Cargo.toml"
            if not cargo_toml.is_file():
                continue
            name_match = re.search(
                r'(?m)^name\s*=\s*"([^"]+)"', cargo_toml.read_text()
            )
            if not name_match:
                continue
            crate = name_match.group(1)
            if crate in patched:
                continue
            path = rel_path(cargo_file, iced_crate)
            lines.append(f'{crate} = {{ path = "{path}" }}')
            patched.add(crate)
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


def fix_workspace_path_deps(
    text: str, cargo_file: Path, cosmic_epoch: Path
) -> str:
    def repl(match: re.Match[str]) -> str:
        dep_name = match.group(1)
        inner = match.group(2)
        sub = EPOCH_CRATE_DIRS.get(dep_name)
        if not sub or "path = " not in inner:
            return match.group(0)
        target = cosmic_epoch / sub
        if not target.is_dir():
            return match.group(0)
        path = rel_path(cargo_file, target)
        inner = re.sub(r'path\s*=\s*"[^"]*"', f'path = "{path}"', inner)
        return f"{dep_name} = {{ {inner.strip()} }}"

    return re.sub(
        r"(?m)^([A-Za-z0-9_-]+)\s*=\s*\{([^}]*)\}\s*$",
        repl,
        text,
    )


def fix_workspace_table_sections(
    text: str, cargo_file: Path, cosmic_epoch: Path
) -> str:
    lines = text.splitlines()
    out: list[str] = []
    i = 0
    while i < len(lines):
        line = lines[i]
        header = re.match(
            r"^\[(?:workspace\.dependencies|dependencies|dev-dependencies|build-dependencies)\.([A-Za-z0-9_-]+)\]\s*$",
            line,
        )
        if not header:
            out.append(line)
            i += 1
            continue

        dep_name = header.group(1)
        sub = EPOCH_CRATE_DIRS.get(dep_name)
        section = [line]
        i += 1
        while i < len(lines) and not lines[i].startswith("["):
            body_line = lines[i]
            if sub and re.match(r"^\s*path\s*=", body_line):
                target = cosmic_epoch / sub
                if target.is_dir():
                    indent = re.match(r"^(\s*)", body_line).group(1)
                    path = rel_path(cargo_file, target)
                    body_line = f'{indent}path = "{path}"'
            section.append(body_line)
            i += 1
        out.extend(section)
    return "\n".join(out)


def rewrite_file(cargo_file: Path, libcosmic: Path, cosmic_epoch: Path) -> bool:
    original = cargo_file.read_text()
    updated = migrate_pop_os_vendor_git_urls(original)
    updated = rewrite_inline_tables(updated, cargo_file, libcosmic, cosmic_epoch)
    updated = rewrite_table_sections(updated, cargo_file, libcosmic, cosmic_epoch)
    updated = fix_workspace_path_deps(updated, cargo_file, cosmic_epoch)
    updated = fix_workspace_table_sections(updated, cargo_file, cosmic_epoch)
    changed = updated != original
    if changed:
        cargo_file.write_text(updated)
    patched = False
    if is_workspace_root(cargo_file):
        patched = ensure_libcosmic_patches(cargo_file, libcosmic)
    return changed or patched


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
        if rewrite_file(cargo_file, libcosmic, cosmic_epoch):
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
