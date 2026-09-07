#!/bin/sh
# Build homerun in release mode and install it onto PATH.
set -eu

cd "$(dirname "$0")"

PREFIX="${PREFIX:-/usr/local/bin}"

echo "Building release binary..."
swift build -c release

BINARY=".build/release/homerun"
if [ ! -x "$BINARY" ]; then
    echo "error: build did not produce $BINARY" >&2
    exit 1
fi

if [ -w "$PREFIX" ] || [ -w "$(dirname "$PREFIX")" ]; then
    mkdir -p "$PREFIX"
    cp "$BINARY" "$PREFIX/homerun"
    chmod +x "$PREFIX/homerun"
else
    echo "$PREFIX needs admin rights, asking for sudo..."
    sudo mkdir -p "$PREFIX"
    sudo cp "$BINARY" "$PREFIX/homerun"
    sudo chmod +x "$PREFIX/homerun"
fi

echo "Installed to $PREFIX/homerun"

case ":$PATH:" in
    *":$PREFIX:"*) ;;
    *) echo "warning: $PREFIX is not on your PATH" >&2 ;;
esac

echo "Run: homerun --dry-run"
