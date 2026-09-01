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
# All secrets are passed from Vercel Environment Variables → dart-define compile-time constants
# Set OPENROUTER_API_KEY, SUPABASE_URL, SUPABASE_ANON_KEY in Vercel Project Settings → Environment Variables
flutter build web --release --no-tree-shake-icons \
  --dart-define=OPENROUTER_API_KEY="${OPENROUTER_API_KEY}" \
  --dart-define=SUPABASE_URL="${SUPABASE_URL}" \
  --dart-define=SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY}"

echo "=== Build finished successfully ==="

