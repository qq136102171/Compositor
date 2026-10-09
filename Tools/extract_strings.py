#!/usr/bin/env python3
"""Inventory of user-facing strings in the Compositor sources.

Splits every string literal into the ones SwiftUI/Swift resolve through a
localization table (they can be translated from a .strings catalog without
touching code) and the ones that reach the UI by another route (raw enum
values, ternaries, string interpolation passed as a String), which only a
source change can translate.
"""

import json
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(sys.argv[1] if len(sys.argv) > 1 else "Compositor")

# APIs whose first argument is a LocalizedStringKey / localized title.
LOCALIZED_CALLS = {
    "Text", "Label", "Button", "Toggle", "Picker", "Menu", "TextField",
    "SecureField", "Link", "Section", "Stepper", "NavigationLink",
    "navigationTitle", "navigationSubtitle", "help", "accessibilityLabel",
    "accessibilityHint", "accessibilityValue", "alert", "confirmationDialog",
    "CommandMenu", "CommandGroup", "MenuBarExtra", "windowStyle", "contextMenu",
    "TableColumn", "DisclosureGroup", "ContentUnavailableView", "LabeledContent",
    "ProgressView", "Gauge", "TextEditor", "GroupBox", "Link",
}

# Argument labels that are localized inside an otherwise arbitrary call.
LOCALIZED_LABELS = {
    "title", "label", "message", "help", "prompt", "placeholder",
    "accessibilityLabel", "emptyView", "description",
}

# Never user-facing.
IGNORED_CALLS = {
    "Image", "systemName", "accessibilityIdentifier", "identifier", "named",
    "font", "colorSpace", "contentsOf", "fileURLWithPath", "rawValue", "ud",
}


def strip_comments(src: str) -> str:
    """Blank out comments so their quotes don't look like literals."""
    out = []
    i, n = 0, len(src)
    while i < n:
        two = src[i : i + 2]
        if two == "//":
            j = src.find("\n", i)
            j = n if j < 0 else j
            out.append(" " * (j - i))
            i = j
        elif two == "/*":
            depth, j = 1, i + 2
            while j < n and depth:
                if src[j : j + 2] == "/*":
                    depth += 1
                    j += 2
                elif src[j : j + 2] == "*/":
                    depth -= 1
                    j += 2
                else:
                    j += 1
            out.append("".join(ch if ch == "\n" else " " for ch in src[i:j]))
            i = j
        else:
            out.append(src[i])
            i += 1
    return "".join(out)


def find_literals(src: str):
    """Yield (start, end, raw_body) for every string literal."""
    i, n = 0, len(src)
    while i < n:
        if src[i] == '"':
            triple = src[i : i + 3] == '"""'
            j = i + (3 if triple else 1)
            while j < n:
                if src[j] == "\\":
                    j += 2
                    continue
                if triple and src[j : j + 3] == '"""':
                    yield i, j + 3, src[i + 3 : j]
                    i = j + 3
                    break
                if not triple and src[j] == '"':
                    yield i, j + 1, src[i + 1 : j]
                    i = j + 1
                    break
                if not triple and src[j] == "\n":
                    i = j
                    break
                j += 1
            else:
                break
        else:
            i += 1


INTERP = re.compile(r"\\\((?:[^()]|\([^()]*\))*\)")
IDENT = re.compile(r"([A-Za-z_][A-Za-z0-9_]*)\s*\($")
LABEL = re.compile(r"([A-Za-z_][A-Za-z0-9_]*)\s*:\s*$")


def classify(src: str, start: int):
    """Guess how the literal at `start` is consumed."""
    before = src[max(0, start - 80) : start]
    before = before.rstrip()
    # Walk back over an argument label or a call parenthesis.
    call = IDENT.search(before)
    label = LABEL.search(before)
    if call and call.group(1) in LOCALIZED_CALLS:
        return "localized", call.group(1)
    if call and call.group(1) in IGNORED_CALLS:
        return "ignored", call.group(1)
    if label and label.group(1) in LOCALIZED_LABELS:
        return "localized", label.group(1) + ":"
    if call:
        return "other", call.group(1)
    # Bare literal: a declaration or an argument list continuation.
    head = before.split("\n")[-1].strip()
    if re.search(r"(=|return|=|,\s*)$", head) or head.endswith(","):
        return "literal-value", ""
    return "other", ""


def main():
    buckets = defaultdict(list)
    per_file = Counter()
    for path in sorted(ROOT.rglob("*.swift")):
        text = strip_comments(path.read_text(encoding="utf-8"))
        for start, end, body in find_literals(text):
            if not body.strip():
                continue
            kind, via = classify(text, start)
            line = text.count("\n", 0, start) + 1
            key = INTERP.sub("%@", body)
            buckets[kind].append(
                {"file": str(path.relative_to(ROOT)), "line": line, "via": via,
                 "text": body, "key": key, "interpolated": bool(INTERP.search(body))}
            )
            per_file[kind] += 1

    print("literal counts by route:")
    for kind in sorted(buckets, key=lambda k: -len(buckets[k])):
        items = buckets[kind]
        distinct = len({i["key"] for i in items})
        print(f"  {kind:14s} {len(items):5d} occurrences, {distinct:5d} distinct")

    loc = buckets["localized"]
    keys = {}
    for item in loc:
        keys.setdefault(item["key"], []).append(item)
    print(f"\nlocalizable keys: {len(keys)} distinct")

    Path("Tools/strings_inventory.json").write_text(
        json.dumps(
            {
                "localizable": {k: v for k, v in sorted(keys.items())},
                "other": buckets["other"],
                "literal-value": buckets["literal-value"],
                "ignored": buckets["ignored"],
            },
            ensure_ascii=False,
            indent=1,
        )
    )
    print("wrote Tools/strings_inventory.json")


if __name__ == "__main__":
    main()
