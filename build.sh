#!/bin/bash
# Install Flutter
echo "Downloading Flutter..."
git clone https://github.com/flutter/flutter.git -b stable --depth 1
export PATH="$PATH:`pwd`/flutter/bin"
flutter config --enable-web

# Generate env.json from Vercel Environment Variables
echo "Generating env.json..."
cat <<EOF > env.json
{
  "SUPABASE_URL": "${SUPABASE_URL}",
  "SUPABASE_ANON_KEY": "${SUPABASE_ANON_KEY}",
  "OPENROUTER_API_KEY": "${OPENROUTER_API_KEY}"
}
EOF

# Build Flutter Web App
echo "Building Flutter Web App..."
flutter pub get
flutter build web --no-tree-shake-icons --dart-define-from-file=env.json
