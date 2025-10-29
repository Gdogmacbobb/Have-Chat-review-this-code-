#!/bin/bash

echo "[CLEANUP] Starting nuclear service worker elimination..."

# Ensure build directory exists
if [ ! -d "build/web" ]; then
    echo "[CLEANUP] ERROR: build/web directory not found!"
    exit 1
fi

# 1. Remove all service worker related files
echo "[CLEANUP] Removing service worker files..."
rm -f build/web/flutter_service_worker.js
rm -f build/web/manifest.json
rm -f build/web/version.json

# 2. Safe, precise service worker loader replacement
echo "[CLEANUP] Replacing service worker loader with safe call..."
if [ -f "build/web/flutter_bootstrap.js" ]; then
    # Single, precise replacement: Remove service worker settings block
    sed -i '/_flutter\.loader\.load({/,/});/c\_flutter.loader.load();' build/web/flutter_bootstrap.js
    echo "[CLEANUP] Service worker loader safely replaced"
fi

# 3. Replace cache-busting version strings with fresh timestamps
echo "[CLEANUP] Updating cache-busting version strings..."
TIMESTAMP=$(date +%s)
find build/web -name "*.js" -exec sed -i "s/?v=[0-9]*/?v=${TIMESTAMP}/g" {} \;
find build/web -name "*.html" -exec sed -i "s/?v=[0-9]*/?v=${TIMESTAMP}/g" {} \;

# 4. Verify flutter_service_worker.js is gone
if [ -f "build/web/flutter_service_worker.js" ]; then
    echo "[CLEANUP] WARNING: flutter_service_worker.js still exists, force removing..."
    rm -f build/web/flutter_service_worker.js
fi

# 5. Update index.html to disable any remaining service worker hints
echo "[CLEANUP] Hardening index.html against service workers..."
if [ -f "build/web/index.html" ]; then
    # Remove any service worker meta tags or script references
    sed -i '/service.*worker/Id' build/web/index.html
    sed -i '/manifest\.json/d' build/web/index.html
fi

echo "[CLEANUP] ✅ Nuclear service worker elimination complete!"
echo "[CLEANUP] Files removed: flutter_service_worker.js, manifest.json, version.json"
echo "[CLEANUP] Registration code stripped from flutter_bootstrap.js"
echo "[CLEANUP] Cache-busting updated with timestamp: ${TIMESTAMP}"