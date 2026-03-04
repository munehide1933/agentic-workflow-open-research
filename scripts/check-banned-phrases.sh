#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# Phrase list covers known meta-credibility/self-justification wording across EN/ZH/JA.
PATTERN='no\s*overclaim|overclaim|no\s*exaggeration|without\s*exaggeration|hype[-\s]*free|no\s*hype|实事求是版|實事求是版|不夸大|無夸大|无夸大|誇張なし|無誇張'

TARGETS=(README.md README.zh.md README.ja.md CONTRIBUTING.md docs examples)

if rg -n -i --glob '*.md' -e "$PATTERN" "${TARGETS[@]}"; then
  echo
  echo "Banned wording detected. Remove or rewrite the matched phrases."
  exit 1
fi

echo "No banned wording detected."
