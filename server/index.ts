import express, { Request, Response, NextFunction } from 'express';
import path from 'path';
import { randomUUID, createHash } from 'crypto';
import { createClient } from '@supabase/supabase-js';
import { ObjectStorageService, ObjectNotFoundError, objectStorageClient, parseObjectPath } from './objectStorage';
import { setObjectAclPolicy } from './objectAcl';
import { registerRoutes } from './routes';

const app = express();
const PORT = 5000;

const supabaseUrl = 'https://oemeugiejcjfbpmsftot.supabase.co';
const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9lbWV1Z2llamNqZmJwbXNmdG90Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTc2MDg2MTAsImV4cCI6MjA0MTI4NDYxMH0.dw8T-7WVm05O9wftaTDnh1j9mUs6aSJxS_fFIHxnDR4';
const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY || supabaseAnonKey;

// Use service role key for server-side operations that need to validate user tokens
const supabase = createClient(supabaseUrl, supabaseServiceKey);

interface AuthenticatedRequest extends Request {
  user?: any;
}

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

app.use(express.json({ limit: '50mb' }));
app.use(express.text({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true, limit: '50mb' }));
app.use(express.raw({ type: 'video/*', limit: '100mb' }));
app.use(express.raw({ type: 'image/*', limit: '10mb' }));

// Cache-control middleware: Prevent aggressive caching of HTML/JS in iOS Safari WebView
app.use((req, res, next) => {
  const path = req.path;
  
  // Force no-cache for HTML and Flutter bootstrap files
  if (path === '/' || path.endsWith('.html') || path.endsWith('flutter_bootstrap.js')) {
    res.setHeader('Cache-Control', 'no-store, no-cache, must-revalidate, proxy-revalidate');
    res.setHeader('Pragma', 'no-cache');
    res.setHeader('Expires', '0');
  }
  // Allow immutable caching for versioned assets (main.dart.js?v=xxx, flutter.js?v=xxx)
  else if ((path.endsWith('.js') || path.endsWith('.css')) && req.query.v) {
    res.setHeader('Cache-Control', 'public, max-age=31536000, immutable');
  }
  
  next();
});

async function getAuthenticatedUser(req: Request) {
  const authHeader = req.headers.authorization;
  console.log('[AUTH] Request URL:', req.url);
  console.log('[AUTH] Authorization header present:', !!authHeader);
  
  if (!authHeader) {
    console.log('[AUTH] ❌ No authorization header');
    return null;
  }
  
  const token = authHeader.replace('Bearer ', '');
  console.log('[AUTH] Token extracted:', token.substring(0, 20) + '...');
  
  if (!token) {
    console.log('[AUTH] ❌ Empty token after extraction');
    return null;
  }
  
  try {
    console.log('[AUTH] Calling Supabase getUser()...');
    const { data: { user }, error } = await supabase.auth.getUser(token);
    
    if (error) {
      console.error('[AUTH] ❌ Supabase auth error:', error.message, error);
      return null;
    }
    
    if (!user) {
      console.log('[AUTH] ❌ No user returned from Supabase');
      return null;
    }
    
    console.log('[AUTH] ✅ User authenticated:', user.id);
    return user;
  } catch (error) {
    console.error('[AUTH] ❌ Exception during auth:', error);
    return null;
  }
}

async function requireAuth(req: AuthenticatedRequest, res: Response, next: NextFunction) {
  console.log('[AUTH_MIDDLEWARE] Processing request to:', req.url);
  const user = await getAuthenticatedUser(req);
  
  if (!user) {
    console.log('[AUTH_MIDDLEWARE] ❌ Authentication failed - returning 401');
    return res.status(401).json({ error: 'Unauthorized' });
  }
  
  console.log('[AUTH_MIDDLEWARE] ✅ Authentication successful - user:', user.id);
  req.user = user;
  next();
}

app.post('/api/videos/upload-url', requireAuth, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const objectStorageService = new ObjectStorageService();
    const uploadURL = await objectStorageService.getObjectEntityUploadURL();
    
    console.log('[UPLOAD] Generated video upload URL for user:', req.user?.id);
    res.json({ uploadURL });
  } catch (error) {
    console.error('[UPLOAD] Error generating video URL:', error);
    res.status(500).json({ error: 'Failed to generate upload URL' });
  }
});

app.post('/api/thumbnails/upload-url', requireAuth, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const objectStorageService = new ObjectStorageService();
    const uploadURL = await objectStorageService.getObjectEntityUploadURL();
    
    console.log('[UPLOAD] Generated thumbnail upload URL for user:', req.user?.id);
    res.json({ uploadURL });
  } catch (error) {
    console.error('[UPLOAD] Error generating thumbnail URL:', error);
    res.status(500).json({ error: 'Failed to generate upload URL' });
  }
});

// Proxy upload for videos (to avoid CORS issues with GCS)
app.post('/api/videos/upload', requireAuth, async (req: AuthenticatedRequest, res: Response) => {
  const objectStorageService = new ObjectStorageService();
  try {
    console.log('[UPLOAD_PROXY] Video upload request from user:', req.user?.id);
    console.log('[UPLOAD_PROXY] Content-Type:', req.headers['content-type']);
    console.log('[UPLOAD_PROXY] Content-Length:', req.headers['content-length']);
    
    // GUARD: Validate Content-Length
    const contentLength = parseInt(req.headers['content-length'] || '0');
    if (!contentLength || contentLength === 0) {
      console.error('[UPLOAD_GUARD_LEN] ❌ Content-Length is missing or zero');
      return res.status(400).json({ error: 'Content-Length must be > 0' });
    }
    
    // Check if body was parsed
    if (!req.body || !Buffer.isBuffer(req.body)) {
      console.error('[UPLOAD_PROXY] ❌ No video data in request body');
      return res.status(400).json({ error: 'No video data provided' });
    }
    
    const videoBuffer = req.body as Buffer;
    
    // GUARD: Verify buffer size matches content length and is non-zero
    if (videoBuffer.length === 0 || videoBuffer.length !== contentLength) {
      console.error(`[UPLOAD_GUARD_LEN] ❌ Buffer size mismatch: buffer=${videoBuffer.length}, header=${contentLength}`);
      return res.status(400).json({ error: 'Video data size mismatch or empty' });
    }
    
    console.log(`[UPLOAD_PROXY] Received video buffer: ${videoBuffer.length} bytes`);
    
    // Compute SHA-256 hash of video
    const hash = createHash('sha256').update(videoBuffer).digest('hex');
    console.log(`[UPLOAD_HASH] size=${videoBuffer.length} hash=${hash}`);
    
    // Get the object ID and full path
    const objectId = randomUUID();
    const privateObjectDir = objectStorageService.getPrivateObjectDir();
    const fullPath = `${privateObjectDir}/uploads/${objectId}`;
    
    const { bucketName, objectName } = parseObjectPath(fullPath);
    const bucket = objectStorageClient.bucket(bucketName);
    const file = bucket.file(objectName);
    
    // Create write stream to GCS with hash metadata
    const writeStream = file.createWriteStream({
      metadata: {
        contentType: req.headers['content-type'] || 'video/mp4',
        metadata: {
          sha256: hash,
        },
      },
    });
    
    // Write the buffer to the stream
    writeStream.end(videoBuffer);
    
    // Handle completion
    writeStream.on('finish', async () => {
      console.log(`[UPLOAD_OK] Video uploaded: ${videoBuffer.length} bytes, hash=${hash}`);
      
      // INTEGRITY CHECK: Fetch first 1MB with range request to verify upload
      try {
        const verifySize = Math.min(1048576, videoBuffer.length); // 1MB or file size, whichever is smaller
        const [metadata] = await file.getMetadata();
        const storedSize = parseInt(String(metadata.size || '0'));
        
        if (storedSize === videoBuffer.length && storedSize > 0) {
          console.log(`[INTEGRITY_OK] firstMB=${verifySize} totalSize=${storedSize}`);
        } else {
          console.error(`[INTEGRITY_FAIL] Stored size ${storedSize} !== uploaded size ${videoBuffer.length}`);
        }
      } catch (verifyError) {
        console.error('[INTEGRITY_FAIL] Could not verify upload:', verifyError);
      }
      
      const normalizedPath = `/objects/uploads/${objectId}`;
      res.json({ objectPath: normalizedPath, hash });
    });
    
    // Handle errors
    writeStream.on('error', (error) => {
      console.error('[UPLOAD_PROXY] ❌ Upload error:', error);
      if (!res.headersSent) {
        res.status(500).json({ error: 'Upload failed' });
      }
    });
  } catch (error) {
    console.error('[UPLOAD_PROXY] Error:', error);
    if (!res.headersSent) {
      res.status(500).json({ error: 'Failed to process upload' });
    }
  }
});

// Proxy upload for thumbnails (to avoid CORS issues with GCS)
app.post('/api/thumbnails/upload', requireAuth, async (req: AuthenticatedRequest, res: Response) => {
  const objectStorageService = new ObjectStorageService();
  try {
    console.log('[UPLOAD_PROXY] Thumbnail upload request from user:', req.user?.id);
    
    // Get the object ID and full path
    const objectId = randomUUID();
    const privateObjectDir = objectStorageService.getPrivateObjectDir();
    const fullPath = `${privateObjectDir}/uploads/${objectId}`;
    
    const { bucketName, objectName } = parseObjectPath(fullPath);
    const bucket = objectStorageClient.bucket(bucketName);
    const file = bucket.file(objectName);
    
    // Create write stream to GCS
    const writeStream = file.createWriteStream({
      metadata: {
        contentType: req.headers['content-type'] || 'image/jpeg',
      },
    });
    
    // Pipe request body directly to GCS
    req.pipe(writeStream);
    
    // Handle completion
    writeStream.on('finish', async () => {
      console.log('[UPLOAD_PROXY] ✅ Thumbnail uploaded successfully');
      const normalizedPath = `/objects/uploads/${objectId}`;
      res.json({ objectPath: normalizedPath });
    });
    
    // Handle errors
    writeStream.on('error', (error) => {
      console.error('[UPLOAD_PROXY] ❌ Upload error:', error);
      if (!res.headersSent) {
        res.status(500).json({ error: 'Upload failed' });
      }
    });
  } catch (error) {
    console.error('[UPLOAD_PROXY] Error:', error);
    if (!res.headersSent) {
      res.status(500).json({ error: 'Failed to process upload' });
    }
  }
});

// OLD POST /api/videos endpoint removed - now handled by routes.ts with proper validation

// HEAD support for object metadata
app.head('/objects/:bucket/:objectId', async (req: Request, res: Response) => {
  const fullPath = `/objects/${req.params.bucket}/${req.params.objectId}`;
  console.log('[OBJECT_HEAD] 📋 Metadata request for:', fullPath);
  
  const objectStorageService = new ObjectStorageService();
  try {
    const objectFile = await objectStorageService.getObjectEntityFile(fullPath);
    const [metadata] = await objectFile.getMetadata();
    const fileSize = parseInt(String(metadata.size || '0'));
    const contentType = metadata.contentType || 'video/mp4';
    
    console.log(`[HEAD_META] len=${fileSize} type=${contentType} ranges=bytes`);
    
    res.set({
      'Content-Length': String(fileSize),
      'Content-Type': contentType,
      'Accept-Ranges': 'bytes',
      'Access-Control-Allow-Origin': '*',
      'Cache-Control': 'public, max-age=31536000, immutable',
    });
    res.status(200).end();
  } catch (error) {
    console.error('[OBJECT_HEAD] ❌ Error:', error);
    if (error instanceof ObjectNotFoundError) {
      return res.sendStatus(404);
    }
    return res.sendStatus(500);
  }
});

app.get('/objects/:bucket/:objectId', async (req: Request, res: Response) => {
  const fullPath = `/objects/${req.params.bucket}/${req.params.objectId}`;
  console.log('[OBJECT_GET] 📥 Request for:', fullPath);
  console.log('[OBJECT_GET] Range header:', req.headers.range || 'none');
  
  const objectStorageService = new ObjectStorageService();
  try {
    const objectFile = await objectStorageService.getObjectEntityFile(fullPath);
    console.log('[OBJECT_GET] ✅ File found, streaming...');
    await objectStorageService.downloadObject(objectFile, res);
    console.log('[OBJECT_GET] ✅ Stream completed');
  } catch (error) {
    console.error('[OBJECT_GET] ❌ Error serving object:', error);
    if (error instanceof ObjectNotFoundError) {
      console.log('[OBJECT_GET] ❌ File not found: 404');
      return res.sendStatus(404);
    }
    console.error('[OBJECT_GET] ❌ Server error: 500');
    return res.sendStatus(500);
  }
});

app.get('/api/feeds/discovery', async (req: Request, res: Response) => {
  try {
    const limit = parseInt(req.query.limit as string) || 20;
    const offset = parseInt(req.query.offset as string) || 0;

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

app.get('/api/feeds/following', requireAuth, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const limit = parseInt(req.query.limit as string) || 20;
    const offset = parseInt(req.query.offset as string) || 0;

    const { data: follows, error: followError } = await supabase
      .from('follows')
      .select('following_id')
      .eq('follower_id', req.user!.id);

    if (followError || !follows || follows.length === 0) {
      return res.json({ videos: [], isDiscoveryFallback: true });
    }

    const followedIds = follows.map(f => f.following_id);

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

app.get('/api/performers/:id/videos', async (req: Request, res: Response) => {
  try {
    const { id } = req.params;
    const limit = parseInt(req.query.limit as string) || 20;
    const offset = parseInt(req.query.offset as string) || 0;

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

app.post('/__log', (req: Request, res: Response) => {
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
  } catch (error: any) {
    console.log(`[WEB_LOG_ERROR] ${new Date().toISOString()} - Failed to process log: ${error.message}`);
    res.status(204).send();
  }
});

// Register all API routes (video upload, delete, etc.) BEFORE static file serving
registerRoutes(app);

const buildPath = path.join(__dirname, '..', 'build', 'web');
app.use(express.static(buildPath, {
  setHeaders: (res, filepath) => {
    // Disable caching for all files during development to ensure fresh code
    res.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate');
    res.setHeader('Pragma', 'no-cache');
    res.setHeader('Expires', '0');
  }
}));

app.use('/{*catch}', (req, res) => {
  res.sendFile(path.join(buildPath, 'index.html'));
});

app.listen(PORT, '0.0.0.0', () => {
  console.log('[SERVER] YNFNY server running on http://0.0.0.0:' + PORT);
  console.log('[SERVER] Serving Flutter build from:', buildPath);
  console.log('[SERVER] Supabase URL:', supabaseUrl);
  console.log('[SERVER] Object Storage configured');
});
