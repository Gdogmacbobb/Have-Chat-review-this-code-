const express = require('express');
const path = require('path');
const fs = require('fs');
const { createClient } = require('@supabase/supabase-js');

const app = express();
const PORT = 5000;

// Initialize Supabase client with same credentials as Flutter app
const supabaseUrl = 'https://oemeugiejcjfbpmsftot.supabase.co';
const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9lbWV1Z2llamNqZmJwbXNmdG90Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTc2MDg2MTAsImV4cCI6MjA0MTI4NDYxMH0.dw8T-7WVm05O9wftaTDnh1j9mUs6aSJxS_fFIHxnDR4';
const supabase = createClient(supabaseUrl, supabaseAnonKey);

// Storage directory for uploaded files
const UPLOADS_DIR = path.join(__dirname, 'uploads');
if (!fs.existsSync(UPLOADS_DIR)) {
  fs.mkdirSync(UPLOADS_DIR, { recursive: true });
}

// Enable CORS for all routes
app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  res.header('Access-Control-Allow-Headers', 'Origin, X-Requested-With, Content-Type, Accept, Authorization');
  
  if (req.method === 'OPTIONS') {
    res.sendStatus(200);
  } else {
    next();
  }
});

// Parse JSON and text bodies
app.use(express.json({ limit: '50mb' }));
app.use(express.text({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true, limit: '50mb' }));
app.use(express.raw({ type: 'video/*', limit: '100mb' }));
app.use(express.raw({ type: 'image/*', limit: '10mb' }));

// Helper function to get authenticated user from request
async function getAuthenticatedUser(req) {
  const authHeader = req.headers.authorization;
  if (!authHeader) return null;
  
  const token = authHeader.replace('Bearer ', '');
  if (!token) return null;
  
  try {
    const { data: { user }, error } = await supabase.auth.getUser(token);
    if (error || !user) return null;
    return user;
  } catch (error) {
    console.error('[AUTH] Error:', error);
    return null;
  }
}

// Middleware to check authentication
async function requireAuth(req, res, next) {
  const user = await getAuthenticatedUser(req);
  if (!user) {
    return res.status(401).json({ error: 'Unauthorized' });
  }
  req.user = user;
  next();
}

// Generate unique filename for uploads
function generateFileName(type, userId) {
  const timestamp = Date.now();
  const random = Math.random().toString(36).substring(7);
  const extension = type === 'video' ? 'mp4' : 'jpg';
  return `${type}_${userId}_${timestamp}_${random}.${extension}`;
}

// Video upload URL endpoint
app.post('/api/videos/upload-url', requireAuth, async (req, res) => {
  try {
    const fileName = generateFileName('video', req.user.id);
    const uploadURL = `http://localhost:${PORT}/upload/video/${fileName}`;
    
    console.log('[UPLOAD] Generated video upload URL for user:', req.user.id);
    res.json({ uploadURL });
  } catch (error) {
    console.error('[UPLOAD] Error generating video URL:', error);
    res.status(500).json({ error: 'Failed to generate upload URL' });
  }
});

// Thumbnail upload URL endpoint
app.post('/api/thumbnails/upload-url', requireAuth, async (req, res) => {
  try {
    const fileName = generateFileName('thumbnail', req.user.id);
    const uploadURL = `http://localhost:${PORT}/upload/thumbnail/${fileName}`;
    
    console.log('[UPLOAD] Generated thumbnail upload URL for user:', req.user.id);
    res.json({ uploadURL });
  } catch (error) {
    console.error('[UPLOAD] Error generating thumbnail URL:', error);
    res.status(500).json({ error: 'Failed to generate upload URL' });
  }
});

// Handle video file upload
app.put('/upload/video/:filename', requireAuth, async (req, res) => {
  try {
    const { filename } = req.params;
    const filePath = path.join(UPLOADS_DIR, filename);
    
    // Save the video file
    const chunks = [];
    req.on('data', chunk => chunks.push(chunk));
    req.on('end', () => {
      const buffer = Buffer.concat(chunks);
      fs.writeFileSync(filePath, buffer);
      console.log(`[UPLOAD] Video saved: ${filename}, size: ${buffer.length} bytes`);
      res.sendStatus(200);
    });
  } catch (error) {
    console.error('[UPLOAD] Error saving video:', error);
    res.status(500).json({ error: 'Failed to save video' });
  }
});

// Handle thumbnail file upload
app.put('/upload/thumbnail/:filename', requireAuth, async (req, res) => {
  try {
    const { filename } = req.params;
    const filePath = path.join(UPLOADS_DIR, filename);
    
    // Save the thumbnail file
    const chunks = [];
    req.on('data', chunk => chunks.push(chunk));
    req.on('end', () => {
      const buffer = Buffer.concat(chunks);
      fs.writeFileSync(filePath, buffer);
      console.log(`[UPLOAD] Thumbnail saved: ${filename}, size: ${buffer.length} bytes`);
      res.sendStatus(200);
    });
  } catch (error) {
    console.error('[UPLOAD] Error saving thumbnail:', error);
    res.status(500).json({ error: 'Failed to save thumbnail' });
  }
});

// Create video metadata in database
app.post('/api/videos', requireAuth, async (req, res) => {
  try {
    const { 
      videoURL, 
      thumbnailURL, 
      caption, 
      performanceType,
      location,
      duration,
      title
    } = req.body;

    if (!videoURL || !caption) {
      return res.status(400).json({ error: 'videoURL and caption are required' });
    }

    // Validate NYC location if provided
    if (location && location.latitude && location.longitude) {
      const isInNYC = (
        location.latitude >= 40.477 && location.latitude <= 40.917 &&
        location.longitude >= -74.259 && location.longitude <= -73.700
      );

      if (!isInNYC) {
        return res.status(400).json({ 
          error: 'Videos can only be uploaded from within NYC boundaries' 
        });
      }
    }

    // Extract filename from URL for storage path
    const videoFileName = videoURL.split('/').pop();
    const thumbnailFileName = thumbnailURL ? thumbnailURL.split('/').pop() : null;

    // Save metadata to database
    const { data, error } = await supabase
      .from('videos')
      .insert({
        performer_id: req.user.id,
        title: title || caption.substring(0, 100),
        description: caption,
        video_url: `/uploads/${videoFileName}`,
        thumbnail_url: thumbnailFileName ? `/uploads/${thumbnailFileName}` : null,
        duration: duration || 0,
        location_latitude: location?.latitude || 40.7128,
        location_longitude: location?.longitude || -74.0060,
        location_name: location?.name || 'New York City',
        borough: location?.borough || 'Manhattan',
        is_approved: true, // Auto-approve for now
        is_flagged: false,
        like_count: 0,
        comment_count: 0,
        share_count: 0,
        view_count: 0
      })
      .select()
      .single();

    if (error) {
      console.error('[VIDEO] Database error:', error);
      return res.status(500).json({ error: 'Failed to save video metadata' });
    }

    console.log('[VIDEO] Metadata saved for video:', data.id);
    res.status(201).json(data);
  } catch (error) {
    console.error('[VIDEO] Error creating video:', error);
    res.status(500).json({ error: 'Failed to create video' });
  }
});

// Get discovery feed videos
app.get('/api/feeds/discovery', async (req, res) => {
  try {
    const limit = parseInt(req.query.limit) || 20;
    const offset = parseInt(req.query.offset) || 0;

    const { data, error } = await supabase
      .from('videos')
      .select(`
        *,
        performer:user_profiles!videos_performer_id_fkey(
          id,
          username,
          profile_image_url,
          performance_types,
          is_verified
        )
      `)
      .eq('is_approved', true)
      .eq('is_flagged', false)
      .order('created_at', { ascending: false })
      .range(offset, offset + limit - 1);

    if (error) {
      console.error('[FEED] Discovery feed error:', error);
      return res.json({ videos: [] });
    }

    console.log(`[FEED] Discovery feed: ${data.length} videos`);
    res.json({ videos: data || [] });
  } catch (error) {
    console.error('[FEED] Discovery feed error:', error);
    res.json({ videos: [] });
  }
});

// Get following feed videos
app.get('/api/feeds/following', requireAuth, async (req, res) => {
  try {
    const limit = parseInt(req.query.limit) || 20;
    const offset = parseInt(req.query.offset) || 0;

    // Get followed performer IDs
    const { data: follows, error: followError } = await supabase
      .from('follows')
      .select('following_id')
      .eq('follower_id', req.user.id);

    if (followError || !follows || follows.length === 0) {
      // No follows, return discovery feed as fallback
      return res.json({ videos: [], isDiscoveryFallback: true });
    }

    const followedIds = follows.map(f => f.following_id);

    // Get videos from followed performers
    const { data, error } = await supabase
      .from('videos')
      .select(`
        *,
        performer:user_profiles!videos_performer_id_fkey(
          id,
          username,
          profile_image_url,
          performance_types,
          is_verified
        )
      `)
      .eq('is_approved', true)
      .eq('is_flagged', false)
      .in('performer_id', followedIds)
      .order('created_at', { ascending: false })
      .range(offset, offset + limit - 1);

    if (error) {
      console.error('[FEED] Following feed error:', error);
      return res.json({ videos: [], isDiscoveryFallback: true });
    }

    console.log(`[FEED] Following feed: ${data.length} videos`);
    res.json({ videos: data || [], isDiscoveryFallback: false });
  } catch (error) {
    console.error('[FEED] Following feed error:', error);
    res.json({ videos: [], isDiscoveryFallback: true });
  }
});

// Get performer videos
app.get('/api/performers/:id/videos', async (req, res) => {
  try {
    const { id } = req.params;
    const limit = parseInt(req.query.limit) || 20;
    const offset = parseInt(req.query.offset) || 0;

    const { data, error } = await supabase
      .from('videos')
      .select('*')
      .eq('performer_id', id)
      .eq('is_approved', true)
      .eq('is_flagged', false)
      .order('created_at', { ascending: false })
      .range(offset, offset + limit - 1);

    if (error) {
      console.error('[PERFORMER] Videos error:', error);
      return res.json({ videos: [] });
    }

    console.log(`[PERFORMER] Videos for ${id}: ${data.length} videos`);
    res.json({ videos: data || [] });
  } catch (error) {
    console.error('[PERFORMER] Videos error:', error);
    res.json({ videos: [] });
  }
});

// Serve uploaded files
app.use('/uploads', express.static(UPLOADS_DIR));

// /__log endpoint for debugging
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
    
    console.log(`[WEB_LOG] ${new Date().toISOString()} - ${logMessage}`);
    res.status(204).send();
  } catch (error) {
    console.log(`[WEB_LOG_ERROR] ${new Date().toISOString()} - Failed to process log: ${error.message}`);
    res.status(204).send();
  }
});

// Serve static files from build/web
const buildPath = path.join(__dirname, 'build', 'web');
app.use(express.static(buildPath, {
  maxAge: '1h',
  setHeaders: (res, filepath) => {
    if (filepath.endsWith('.html')) {
      res.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate');
    } else if (filepath.endsWith('.js') || filepath.endsWith('.css')) {
      res.setHeader('Cache-Control', 'public, max-age=3600');
    }
  }
}));

// Catch all route for Flutter web app (SPA fallback)
app.use((req, res) => {
  res.sendFile(path.join(buildPath, 'index.html'));
});

app.listen(PORT, '0.0.0.0', () => {
  console.log('[SERVER] YNFNY server running on http://0.0.0.0:' + PORT);
  console.log('[SERVER] Serving Flutter build from:', buildPath);
  console.log('[SERVER] Uploads directory:', UPLOADS_DIR);
  console.log('[SERVER] Supabase URL:', supabaseUrl);
});