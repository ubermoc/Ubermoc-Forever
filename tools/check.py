#!/usr/bin/env python3
"""TOC/file consistency check and zip build for Ubermoc Forever."""
import re
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TOC = ROOT / "UbermocForever.toc"
ADDON = "UbermocForever"


def listed_files():
    files = []
    for line in TOC.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line and not line.startswith("#"):
            files.append(line.replace("\\", "/"))
    return files


def check():
    errors = []
    listed = listed_files()
    for f in listed:
        if not (ROOT / f).is_file():
            errors.append(f"TOC lists missing file: {f}")
    on_disk = {
        p.relative_to(ROOT).as_posix()
        for d in ("Core", "Input", "Locales", "UI")
        for p in (ROOT / d).rglob("*.lua")
    }
    for f in sorted(on_disk - set(listed)):
        errors.append(f"Lua file not in TOC: {f}")
    text = TOC.read_text(encoding="utf-8")
    m = re.search(r"^## Interface:\s*(.+)$", text, re.M)
    if not m or "16001" not in m.group(1) or "120105" not in m.group(1):
        errors.append("TOC Interface line must include 16001 and 120105")
    return errors


def build(version):
    out = ROOT / "dist"
    out.mkdir(exist_ok=True)
    zpath = out / f"{ADDON}-{version}.zip"
    toc_text = TOC.read_text(encoding="utf-8").replace("@project-version@", version)
    with zipfile.ZipFile(zpath, "w", zipfile.ZIP_DEFLATED) as z:
        z.writestr(f"{ADDON}/{TOC.name}", toc_text)
        for f in listed_files():
            z.write(ROOT / f, f"{ADDON}/{f}")
        for extra in ("LICENSE.txt", "CHANGELOG.md"):
            z.write(ROOT / extra, f"{ADDON}/{extra}")
    return zpath


if __name__ == "__main__":
    errs = check()
    for e in errs:
        print("ERROR:", e)
    if errs:
        sys.exit(1)
    print("TOC check passed")
    if len(sys.argv) > 2 and sys.argv[1] == "build":
        print("Built", build(sys.argv[2]))
