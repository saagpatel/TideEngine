#!/usr/bin/env python3
"""Check listing limits and any fastlane text against APPSTORE-METADATA.md."""

from pathlib import Path
import re
import sys


def listing_fields(root: Path) -> dict[str, str]:
    draft = (root / "APPSTORE-METADATA.md").read_text(encoding="utf-8")

    def section(title: str) -> str:
        match = re.search(rf"^## {re.escape(title)}\n(.*?)(?=^## |\Z)", draft,
                          re.MULTILINE | re.DOTALL)
        if not match:
            raise ValueError(f"Missing metadata section: {title}")
        return match.group(1).strip()

    def identity(label: str) -> str:
        match = re.search(rf"^\| {label} \| ([^|]+) \|$", section("Identity"),
                          re.MULTILINE)
        if not match:
            raise ValueError(f"Missing identity field: {label}")
        return match.group(1).strip()

    def inline(title: str) -> str:
        value = section(title)
        if not re.fullmatch(r"`[^`\n]+`", value):
            raise ValueError(f"Expected one inline value: {title}")
        return value[1:-1]

    fields = {
        "name": identity("Name"),
        "subtitle": identity("Subtitle"),
        "description": section("Description"),
        "keywords": inline("Keywords"),
        "promotional_text": inline("Promotional text"),
        "release_notes": "Initial release.",
    }
    for label, key in (("Support", "support_url"), ("Privacy", "privacy_url"),
                       ("Marketing", "marketing_url")):
        match = re.search(rf"^- {label}: (\S+)$", section("URLs"), re.MULTILINE)
        if match:
            fields[key] = match.group(1)
        elif key != "marketing_url":
            raise ValueError(f"Missing URL: {label}")
    return fields


def check(root: Path) -> list[str]:
    fields = listing_fields(root)
    errors = []
    for key, limit in (("subtitle", 30), ("promotional_text", 170),
                       ("keywords", 100), ("description", 4000)):
        if len(fields[key]) > limit:
            errors.append(f"{key}: {len(fields[key])} exceeds {limit}")

    metadata = root / "fastlane" / "metadata"
    if not metadata.exists():
        return errors
    # deliver reads localized listing text from locale directories (or default).
    locales = sorted(path for path in metadata.iterdir() if path.is_dir())
    if not locales:
        errors.append("fastlane/metadata has no locale directory")
    for locale in locales:
        for key, value in fields.items():
            if key == "marketing_url" and not (locale / f"{key}.txt").exists():
                continue
            path = locale / f"{key}.txt"
            if not path.is_file() or path.read_bytes() != (value + "\n").encode("utf-8"):
                errors.append(f"{path.relative_to(root)}: missing or differs from draft")
    for path in sorted(metadata.rglob("*.txt")):
        if path.parent not in locales or path.stem not in fields:
            errors.append(f"{path.relative_to(root)}: no corresponding draft field")
    return errors


if __name__ == "__main__":
    root = Path(__file__).resolve().parents[1]
    try:
        errors = check(root)
    except (OSError, ValueError) as error:
        errors = [str(error)]
    if errors:
        print("\n".join(errors), file=sys.stderr)
        sys.exit(1)
    print("PASS: listing limits and fastlane metadata match" if
          (root / "fastlane" / "metadata").exists() else
          "PASS: listing limits; fastlane sync not applicable (metadata absent)")
