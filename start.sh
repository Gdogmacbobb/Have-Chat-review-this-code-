#!/usr/bin/env bash
set -euxo pipefail

echo "🚀 Starting YNFNY Flutter Live Dev Server..."
echo "🔧 ARCHITECT FIX: Live rebuild enabled for video mounting testing"

# Clean caches to ensure fresh build
rm -rf build/web .dart_tool
flutter clean
flutter pub get

# Start live Flutter dev server on port 5000 (removed invalid --web-renderer flag)
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 5000 -v \
  --dart-define=SUPABASE_URL="https://oemeugiejcjfbpmsftot.supabase.co" \
  --dart-define=SUPABASE_ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9lbWV1Z2llamNqZmJwbXNmdG90Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTc2MDg2MTAsImV4cCI6MjA0MTI4NDYxMH0.dw8T-7WVm05O9wftaTDnh1j9mUs6aSJxS_fFIHxnDR4"