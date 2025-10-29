const express = require('express');
const path = require('path');
const fs = require('fs');

const app = express();
const PORT = 5000;

// Enable CORS for all routes
app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  res.header('Access-Control-Allow-Headers', 'Origin, X-Requested-With, Content-Type, Accept');
  
  if (req.method === 'OPTIONS') {
    res.sendStatus(200);
  } else {
    next();
  }
});

// Parse JSON and text bodies
app.use(express.json({ limit: '10mb' }));
app.use(express.text({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Video upload API endpoints
app.post('/api/videos/upload-url', async (req, res) => {
  // Return a simple presigned URL for now - in production this would use Object Storage
  const uploadURL = `http://localhost:${PORT}/upload/video_${Date.now()}`;
  res.json({ uploadURL });
});

app.post('/api/thumbnails/upload-url', async (req, res) => {
  // Return a simple presigned URL for now
  const uploadURL = `http://localhost:${PORT}/upload/thumb_${Date.now()}`;
  res.json({ uploadURL });
});

app.put('/upload/:filename', async (req, res) => {
  // Accept the upload
  console.log(`[UPLOAD] Received upload for ${req.params.filename}`);
  res.sendStatus(200);
});

app.post('/api/videos', async (req, res) => {
  const { 
    videoURL, 
    thumbnailURL, 
    caption, 
    performanceType,
    location,
    duration,
    title
  } = req.body;

  console.log('[VIDEO] Creating video metadata:', { title, caption, performanceType });
  
  // Return mock response for now
  res.status(201).json({
    id: `video_${Date.now()}`,
    videoURL,
    thumbnailURL,
    caption,
    performanceType,
    location,
    duration,
    title,
    created_at: new Date().toISOString()
  });
});

// API routes for feeds
app.get('/api/feeds/discovery', async (req, res) => {
  // Return empty array for now - will be populated when videos are uploaded
  res.json({ videos: [] });
});

app.get('/api/feeds/following', async (req, res) => {
  res.json({ videos: [], isDiscoveryFallback: true });
});

app.get('/api/performers/:id/videos', async (req, res) => {
  res.json({ videos: [] });
});

// /__log endpoint - capture camera preview logs
app.post('/__log', (req, res) => {
  try {
    let logMessage = '';
    
    if (typeof req.body === 'string') {
      logMessage = req.body;
    } else if (req.body && req.body.message) {
      logMessage = req.body.message;
    } else if (req.body) {
      logMessage = JSON.stringify(req.body);
    } else {
      logMessage = 'Empty log message';
    }
    
    // Print to stdout (will appear in workflow logs)
    console.log(`[WEB_LOG] ${new Date().toISOString()} - ${logMessage}`);
    
    res.status(204).send(); // No content response
  } catch (error) {
    console.log(`[WEB_LOG_ERROR] ${new Date().toISOString()} - Failed to process log: ${error.message}`);
    res.status(204).send(); // Never crash, always return 204
  }
});

// Handle GET requests to /__log (for URL-encoded logs)
app.get('/__log', (req, res) => {
  try {
    const message = req.query.m || req.query.message || 'Empty log message';
    const decodedMessage = decodeURIComponent(message);
    
    console.log(`[WEB_LOG] ${new Date().toISOString()} - ${decodedMessage}`);
    
    res.status(204).send();
  } catch (error) {
    console.log(`[WEB_LOG_ERROR] ${new Date().toISOString()} - Failed to process GET log: ${error.message}`);
    res.status(204).send();
  }
});

// Serve static files from build/web
const buildPath = path.join(__dirname, 'build', 'web');

// Check if build directory exists
if (!fs.existsSync(buildPath)) {
  console.log(`[SERVER_ERROR] Build directory not found: ${buildPath}`);
  process.exit(1);
}

app.use(express.static(buildPath, {
  // Disable caching for immediate updates
  setHeaders: (res, path) => {
    res.set('Cache-Control', 'no-cache, no-store, must-revalidate');
    res.set('Pragma', 'no-cache');
    res.set('Expires', '0');
  }
}));

// Specific route for root
app.get('/', (req, res) => {
  res.sendFile(path.join(buildPath, 'index.html'));
});

// Fallback for unmatched routes (Flutter web SPA routing)
app.use((req, res) => {
  res.sendFile(path.join(buildPath, 'index.html'));
});

// Start server
app.listen(PORT, '0.0.0.0', () => {
  console.log(`[SERVER] YNFNY Flutter server running on http://0.0.0.0:${PORT}`);
  console.log(`[SERVER] Serving Flutter build from: ${buildPath}`);
  console.log(`[SERVER] /__log endpoint ready for camera preview logs`);
  console.log(`[SERVER] CORS enabled for all origins`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('[SERVER] Received SIGTERM, shutting down gracefully');
  process.exit(0);
});

process.on('SIGINT', () => {
  console.log('[SERVER] Received SIGINT, shutting down gracefully');
  process.exit(0);
});