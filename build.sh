#!/bin/bash
# Install Flutter
echo "Downloading Flutter..."
git clone https://github.com/flutter/flutter.git -b stable --depth 1
export PATH="$PATH:`pwd`/flutter/bin"
flutter config --enable-web

# Generate env.json from Vercel Environment Variables
echo "Generating env.json..."
if [ -n "$SUPABASE_URL" ]; then
  cat <<EOF > env.json
{
  "SUPABASE_URL": "${SUPABASE_URL}",
  "SUPABASE_ANON_KEY": "${SUPABASE_ANON_KEY}",
  "OPENROUTER_API_KEY": "${OPENROUTER_API_KEY}"
}
EOF
elif [ ! -f env.json ]; then
  echo "Warning: SUPABASE_URL not set and env.json not found."
  cat <<EOF > env.json
{
  "SUPABASE_URL": "",
  "SUPABASE_ANON_KEY": "",
  "OPENROUTER_API_KEY": ""
}
EOF
else
  echo "Using existing env.json file."
fi

# Build Flutter Web App
echo "Building Flutter Web App..."
flutter pub get
flutter build web --no-tree-shake-icons --dart-define-from-file=env.json

# Ensure static files like app-ads.txt are in build/web
echo "Copying static assets..."
if [ -f "web/app-ads.txt" ]; then
  cp web/app-ads.txt build/web/app-ads.txt
elif [ -f "app-ads.txt" ]; then
  cp app-ads.txt build/web/app-ads.txt
fi

