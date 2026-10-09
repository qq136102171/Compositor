#!/usr/bin/env python3
"""Diffs the keys the built app will look up against the translation.

The compiler writes one .stringsdata per source file when asked
(`-emit-localized-strings`), which is the same list Xcode exports for a String
Catalog. Anything there without an entry in Tools/zh-Hans.lproj/Localizable.strings
stays English in the interface, so this is the coverage check.
"""

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "build" / "stringsdata"
STRINGS = ROOT / "Tools" / "zh-Hans.lproj" / "Localizable.strings"


def compiled_keys():
    """Every key the compiler recorded, with the files that ask for it."""
    keys = {}
    for path in sorted(DATA.glob("*.stringsdata")):
        payload = json.loads(path.read_text(encoding="utf-8"))
        for entries in payload.get("tables", {}).values():
            for entry in entries:
                key = entry.get("key")
                if key is None:
                    continue
                keys.setdefault(key, set()).add(payload.get("source", path.name))
    return keys


def translated_keys():
    text = STRINGS.read_text(encoding="utf-8")
    found = {}
    for match in re.finditer(r'^"((?:[^"\\]|\\.)*)"\s*=\s*"((?:[^"\\]|\\.)*)";', text, re.M):
        found[match.group(1).replace('\\"', '"').replace("\\\\", "\\")] = True
    return found


def main():
    if not DATA.is_dir():
        sys.exit("no build/stringsdata — run Tools/build.sh first")
    compiled = compiled_keys()
    translated = translated_keys()

    missing = sorted(k for k in compiled if k not in translated)
    unused = sorted(k for k in translated if k not in compiled)

    print(f"keys the app looks up: {len(compiled)}")
    print(f"translated           : {len(translated)}")
    print(f"still English        : {len(missing)}")

    Path(ROOT / "Tools" / "strings_missing.txt").write_text(
        "\n".join(f"{k}\t{','.join(sorted(compiled[k]))}" for k in missing) + "\n",
        encoding="utf-8",
    )
    Path(ROOT / "Tools" / "strings_unused.txt").write_text(
        "\n".join(unused) + "\n", encoding="utf-8"
    )
    # Entries the compiler never saw are not dead: blend mode names, tool labels
    # and error text are looked up at runtime through localizedUI().
    print("wrote Tools/strings_missing.txt and Tools/strings_unused.txt")

    if "--list" in sys.argv:
        for key in missing:
            print(f"  {key}")

    runtime_missing()


RUNTIME_LITERAL = re.compile(r'localizedUI\(\s*"((?:[^"\\]|\\.)*)"')


def runtime_missing():
    """Literal arguments to localizedUI, which the compiler can't report.

    Blend mode names, tool labels, error text and status hints reach the
    interface as plain Strings, so their keys never show up in .stringsdata.
    """
    translated = translated_keys()
    wanted = {}
    for path in sorted((ROOT / "Compositor").rglob("*.swift")):
        for match in RUNTIME_LITERAL.finditer(path.read_text(encoding="utf-8")):
            key = match.group(1).replace('\\"', '"').replace("\\\\", "\\")
            wanted.setdefault(key, set()).add(str(path.relative_to(ROOT)))
    missing = sorted(k for k in wanted if k not in translated)
    print(f"\nruntime lookups       : {len(wanted)}")
    print(f"of those untranslated : {len(missing)}")
    if missing:
        Path(ROOT / "Tools" / "strings_runtime_missing.txt").write_text(
            "\n".join(missing) + "\n", encoding="utf-8"
        )
        for key in missing[:40]:
            print(f"  {key}")


if __name__ == "__main__":
    main()
