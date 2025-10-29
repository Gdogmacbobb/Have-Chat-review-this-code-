#!/usr/bin/env python3
"""
Custom HTTP server with proper cache-control headers for Flutter web apps.
Prevents aggressive browser caching that causes users to see stale code.
"""

import http.server
import socketserver
import os
from pathlib import Path

PORT = 5000
DIRECTORY = "build/web"

class NoCacheHTTPRequestHandler(http.server.SimpleHTTPRequestHandler):
    """HTTP handler that sends cache-busting headers with every response."""
    
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DIRECTORY, **kwargs)
    
    def end_headers(self):
        """Add cache-control headers to prevent caching of any files."""
        # Prevent caching - force browser to always fetch fresh content
        self.send_header('Cache-Control', 'no-cache, no-store, must-revalidate, max-age=0')
        self.send_header('Pragma', 'no-cache')
        self.send_header('Expires', '0')
        
        # CORS headers for cross-origin requests
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', '*')
        
        super().end_headers()
    
    def do_OPTIONS(self):
        """Handle preflight CORS requests."""
        self.send_response(200)
        self.end_headers()
    
    def log_message(self, format, *args):
        """Custom logging format."""
        print(f"[{self.date_time_string()}] {format % args}")

def main():
    """Start the web server with no-cache headers."""
    # Verify the build directory exists
    if not Path(DIRECTORY).exists():
        print(f"Error: Directory '{DIRECTORY}' does not exist!")
        print("Please run './build_web.sh' first to build the Flutter web app.")
        return
    
    # Create and start the server
    socketserver.TCPServer.allow_reuse_address = True
    with socketserver.TCPServer(("0.0.0.0", PORT), NoCacheHTTPRequestHandler) as httpd:
        print(f"🚀 Serving Flutter web app on http://0.0.0.0:{PORT}")
        print(f"📁 Directory: {DIRECTORY}")
        print(f"🔄 Cache-Control: no-cache, no-store, must-revalidate")
        print(f"✨ Browser will always load fresh content!")
        print("-" * 60)
        
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\n👋 Server stopped")

if __name__ == "__main__":
    main()
