#!/usr/bin/env python3
"""Restore and verify the shipped Nexora APK before serving dist/."""
import hashlib
import lzma
import os
from pathlib import Path
import tempfile

ROOT = Path(__file__).resolve().parents[1]
TARGET = ROOT / "dist/downloads/Nexora-Salon-Jobs.apk"
ARCHIVE = TARGET.with_suffix(".apk.xz")
EXPECTED = "4d76532431dbcb3893c695588011d95052177c7062cd26077f4d46023362557b"

def digest(path):
    result = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            result.update(chunk)
    return result.hexdigest()

def main():
    if TARGET.exists() and digest(TARGET) == EXPECTED:
        print("APK already restored and verified:", TARGET)
        return
    handle, name = tempfile.mkstemp(prefix=".nexora-apk-", dir=TARGET.parent)
    staged = Path(name)
    try:
        with os.fdopen(handle, "wb") as output, lzma.open(ARCHIVE, "rb") as source:
            for chunk in iter(lambda: source.read(1024 * 1024), b""):
                output.write(chunk)
        if digest(staged) != EXPECTED:
            raise ValueError("APK checksum mismatch; original file was not replaced.")
        staged.chmod(0o644)
        staged.replace(TARGET)
        print("Restored and verified APK v1.0.5:", TARGET)
    finally:
        staged.unlink(missing_ok=True)

if __name__ == "__main__":
    main()
