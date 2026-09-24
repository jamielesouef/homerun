#!/bin/zsh
# PostToolUse hook: lints the Swift file Claude just wrote or edited.
#
# Exit 2 hands the violations back to Claude as feedback, so a broken rule is
# fixed in the same turn instead of surfacing in CI. Anything that is not a
# Swift file, or a file SwiftLint excludes, passes through untouched.

set -uo pipefail

file="$(jq -r '.tool_input.file_path // empty')"

[[ "$file" == *.swift ]] || exit 0
[[ -f "$file" ]] || exit 0
command -v swiftlint > /dev/null || exit 0

cd "$CLAUDE_PROJECT_DIR" || exit 0

violations="$(swiftlint lint --quiet --force-exclude "$file" 2>/dev/null)"

[[ -z "$violations" ]] && exit 0

print -u2 -- "SwiftLint found violations in $file. Fix them before moving on:"
print -u2 -- "$violations"
exit 2
