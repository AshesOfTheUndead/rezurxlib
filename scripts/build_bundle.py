#!/usr/bin/env python3
"""RezurXLib build script.

Concatenates the src/ modules (lexicographic order) into the single-file
RezurXLib.lua bundle for loadstring consumption.

CONVENTION: every module file ends with a trailing newline. The bundle is
the exact concatenation MINUS the final file's trailing newline, so the
output is byte-identical to the canonical monolith.

Usage:
    python3 scripts/build.py            # emits RezurXLib.lua next to src/
    python3 scripts/build.py --check    # verify the bundle is up to date
"""
import pathlib
import sys

HERE = pathlib.Path(__file__).resolve().parent
# ROOT = the directory containing src/ (script may sit beside it or in a
# scripts/ subdirectory).
ROOT = HERE if (HERE / "src").is_dir() else HERE.parent
SRC = ROOT / "src"
OUT = ROOT / "RezurXLib.lua"


def build() -> str:
    modules = sorted(SRC.glob("*.luau"))
    if not modules:
        raise SystemExit("no modules found in src/")
    parts = [m.read_text(encoding="utf-8") for m in modules]
    bundle = "".join(parts)
    # Strip exactly the final trailing newline (see convention above).
    if bundle.endswith("\n"):
        bundle = bundle[:-1]
    return bundle


def main() -> None:
    bundle = build()
    if "--check" in sys.argv:
        current = OUT.read_text(encoding="utf-8") if OUT.exists() else ""
        if current == bundle:
            print("bundle up to date")
        else:
            print("bundle OUT OF DATE — rebuild required")
            sys.exit(1)
        return
    OUT.write_text(bundle, encoding="utf-8")
    print(f"wrote {OUT} ({len(bundle)} bytes, {bundle.count(chr(10))} lines)")


if __name__ == "__main__":
    main()
