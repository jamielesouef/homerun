#!/bin/zsh
# Typechecks docs/templates as one unit, including the test templates.
#
# The README promises that every type one template references exists in
# another. Nothing checked it, so a signature change or a typo could leave the
# templates out of step with each other unnoticed.
#
# The test templates `@testable import ExampleApp`, a module that does not
# exist. They are copied to a temp folder with that line removed, so they
# typecheck against the app templates directly.

set -euo pipefail

root="${0:A:h:h}"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

cp -R "$root/docs/templates/." "$work"
find "$work" -name '*.swift' -exec sed -i '' '/^@testable import ExampleApp$/d' {} +

developer="$(xcode-select -p)"
platform="$developer/Platforms/MacOSX.platform/Developer"
plugins="$developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/host/plugins/testing"

xcrun swiftc -typecheck \
    -swift-version 6 \
    -target arm64-apple-macos15 \
    -F "$platform/Library/Frameworks" \
    -I "$platform/usr/lib" \
    -plugin-path "$plugins" \
    $(find "$work" -name '*.swift') \
    2>&1 | sed "s|$work/|docs/templates/|g"
