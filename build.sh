#!/bin/bash
set -e

echo "=== Installing Flutter SDK ==="
if [ ! -d "flutter" ]; then
  git clone https://github.com/flutter/flutter.git --depth 1 -b stable flutter
fi

export PATH="$PATH:$(pwd)/flutter/bin"

echo "=== Verifying Flutter ==="
flutter --version

echo "=== Getting dependencies ==="
flutter pub get

echo "=== Building Flutter Web ==="
flutter build web --release --no-tree-shake-icons

echo "=== Build finished successfully ==="
