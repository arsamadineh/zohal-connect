#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
python3 - << 'EOF'
import os
import re
import sys

root = os.path.abspath(os.path.join(os.path.dirname(__file__), "..") if "__file__" in locals() else ".")

# Load allow-list
allow_list = set()
allow_file = os.path.join(root, "tools", "persian-allow.txt")
if os.path.exists(allow_file):
    with open(allow_file, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#"):
                allow_list.add(line)

targets = [
    os.path.join(root, "app", "lib", "l10n", "strings_fa.dart"),
]

# Patterns for Persian UI copy issues:
# 1. می/نمی followed directly by a Persian letter without ZWNJ (\u200c)
p_mi = re.compile(r'(?<![آ-ی])(ن?می)(?!\u200c)([آ-ی]+)')
# 2. Glued common plural/suffix patterns
p_glued = re.compile(r'([آ-ی]{2,})(ها|های)(?=[ \n\r\t.,!?:;،«»()"\']|$)')
# 3. ASCII digits in strings_fa.dart values
p_ascii_digit = re.compile(r':\s*[\'"][^\'"]*[0-9][^\'"]*[\'"]')
# 4. Em dash (—) or En dash (–)
p_dashes = re.compile(r'[—–]')
# 5. Emojis
p_emoji = re.compile(r'[\U00010000-\U0010ffff]')

errors = 0
for target in targets:
    if not os.path.exists(target):
        continue
    with open(target, "r", encoding="utf-8") as f:
        lines = f.readlines()
    for idx, line in enumerate(lines, 1):
        # Ignore comments or code keys
        text = line.strip()
        if text.startswith("//") or not text:
            continue
        # Check allow list
        if any(allowed in text for allowed in allow_list):
            continue

        # Check dashes
        if p_dashes.search(text):
            print(f"[ERROR] {target}:{idx}: Contains em/en dash: {text}")
            errors += 1

        # Check emojis
        if p_emoji.search(text):
            print(f"[ERROR] {target}:{idx}: Contains emoji: {text}")
            errors += 1

        # Check ASCII digits in string values
        if p_ascii_digit.search(text):
            # allow known version or license keys if applicable
            if "AGPL-3.0" not in text and "v2.3.0" not in text and "E100" not in text:
                print(f"[ERROR] {target}:{idx}: Contains ASCII digit: {text}")
                errors += 1

        # Check می / نمی missing ZWNJ
        m_mi = p_mi.search(text)
        if m_mi:
            word = m_mi.group(0)
            if word not in allow_list:
                print(f"[ERROR] {target}:{idx}: Missing ZWNJ after می/نمی in '{word}': {text}")
                errors += 1

if errors > 0:
    print(f"Persian lint failed with {errors} error(s).")
    sys.exit(1)
print("Persian lint passed.")
EOF
