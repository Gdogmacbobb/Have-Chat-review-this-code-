#!/usr/bin/env bash
set -e

echo "🚀 Starting YNFNY Flutter Web Server..."

# Get dependencies
flutter pub get

# Start Flutter web server on port 5000 
# Using the Supabase credentials from env.json and start.sh
flutter run -d web-server \
  --web-hostname 0.0.0.0 \
  --web-port 5000 \
  --dart-define=SUPABASE_URL="https://oemeugiejcjfbpmsftot.supabase.co" \
  --dart-define=SUPABASE_ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9lbWV1Z2llamNqZmJwbXNmdG90Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTc2MDg2MTAsImV4cCI6MjA0MTI4NDYxMH0.dw8T-7WVm05O9wftaTDnh1j9mUs6aSJxS_fFIHxnDR4"
