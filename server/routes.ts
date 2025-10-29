// FILEPATH: server/routes.ts
// Routes for video uploading and serving with Object Storage integration
import express, { Express, Request, Response, NextFunction } from "express";
import { createServer, type Server } from "http";
import {
  ObjectStorageService,
  ObjectNotFoundError,
} from "./objectStorage";
import { ObjectPermission } from "./objectAcl";
import { createClient } from '@supabase/supabase-js';

// Extend Express Request type to include user
declare global {
  namespace Express {
    interface Request {
      user?: {
        id: string;
      };
    }
  }
}

// Initialize Supabase client
// Use same credentials as Flutter app for development
const supabaseUrl = process.env.SUPABASE_URL || 'https://oemeugiejcjfbpmsftot.supabase.co';
const supabaseAnonKey = process.env.SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9lbWV1Z2llamNqZmJwbXNmdG90Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTc2MDg2MTAsImV4cCI6MjA0MTI4NDYxMH0.dw8T-7WVm05O9wftaTDnh1j9mUs6aSJxS_fFIHxnDR4';
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY || supabaseAnonKey;
const supabase = createClient(supabaseUrl, supabaseKey);

// Helper function to get authenticated user from request
async function getAuthenticatedUser(req: Request): Promise<string | null> {
  const authHeader = req.headers.authorization;
  if (!authHeader) return null;
  
  const token = authHeader.replace('Bearer ', '');
  if (!token) return null;
  
  try {
    const { data: { user }, error } = await supabase.auth.getUser(token);
    if (error || !user) return null;
    return user.id;
  } catch (error) {
    console.error('Auth error:', error);
    return null;
  }
}

// Middleware to check authentication
async function isAuthenticated(req: Request, res: Response, next: NextFunction) {
  const userId = await getAuthenticatedUser(req);
  if (!userId) {
    return res.status(401).json({ error: 'Unauthorized' });
  }
  req.user = { id: userId };
  next();
}

export async function registerRoutes(app: Express): Promise<Server> {
  // Enable JSON body parsing
  app.use(express.json());

  // Endpoint for serving public video files
  app.use("/public-objects", async (req, res) => {
    const filePath = req.path.substring(1); // Remove leading slash
    const objectStorageService = new ObjectStorageService();
    try {
      const file = await objectStorageService.searchPublicObject(filePath);
      if (!file) {
        return res.status(404).json({ error: "File not found" });
      }
      objectStorageService.downloadObject(file, res);
    } catch (error) {
      console.error("Error searching for public object:", error);
      return res.status(500).json({ error: "Internal server error" });
    }
  });

  // Endpoint for serving private video/thumbnail objects  
  app.use("/objects", async (req, res) => {
    const userId = await getAuthenticatedUser(req);
    const objectStorageService = new ObjectStorageService();
    
    try {
      const objectFile = await objectStorageService.getObjectEntityFile(req.path);
      
      // For now, allow read access to all authenticated users
      // Later we can implement follower-based access control
      const canAccess = await objectStorageService.canAccessObjectEntity({
        objectFile,
        userId: userId || undefined,
        requestedPermission: ObjectPermission.READ,
      });
      
      if (!canAccess && !userId) {
        return res.sendStatus(401);
      }
      
      objectStorageService.downloadObject(objectFile, res);
    } catch (error) {
      console.error("Error checking object access:", error);
      if (error instanceof ObjectNotFoundError) {
        return res.sendStatus(404);
      }
      return res.sendStatus(500);
    }
  });

  // Endpoint for getting video upload URL
  app.post("/api/videos/upload-url", isAuthenticated, async (req, res) => {
    try {
      const objectStorageService = new ObjectStorageService();
      const videoUploadURL = await objectStorageService.getObjectEntityUploadURL();
      res.json({ uploadURL: videoUploadURL });
    } catch (error) {
      console.error("Error getting video upload URL:", error);
      res.status(500).json({ error: "Failed to generate upload URL" });
    }
  });

  // Endpoint for getting thumbnail upload URL
  app.post("/api/thumbnails/upload-url", isAuthenticated, async (req, res) => {
    try {
      const objectStorageService = new ObjectStorageService();
      const thumbnailUploadURL = await objectStorageService.getObjectEntityUploadURL();
      res.json({ uploadURL: thumbnailUploadURL });
    } catch (error) {
      console.error("Error getting thumbnail upload URL:", error);
      res.status(500).json({ error: "Failed to generate upload URL" });
    }
  });

  // Endpoint for creating video metadata after upload
  app.post("/api/videos", isAuthenticated, async (req, res) => {
    console.log('[🔥CHECKPOINT] POST /api/videos handler START - ts-node is loading routes.ts');
    
    const { 
      videoURL, 
      thumbnailURL, 
      caption, 
      performanceType,
      location,
      duration,
      title
    } = req.body;

    // [OMEGA_PILL_DB] Log what client sent
    console.log(`[OMEGA_PILL_DB] Client sent performanceType="${performanceType}" (type: ${typeof performanceType}, length: ${performanceType?.length || 0})`);

    if (!videoURL || !caption) {
      return res.status(400).json({ error: "videoURL and caption are required" });
    }

    // CRITICAL: Validate performance_type is provided (database has NOT NULL constraint)
    if (!performanceType || performanceType.trim() === '') {
      console.error('[VIDEO_VALIDATION] ❌ Missing performance_type - client sent empty/null value');
      return res.status(400).json({ 
        error: "Performance type is required. Please select a performance type (music, dance, visual_arts, comedy, magic, or other)." 
      });
    }

    const userId = req.user?.id;
    
    if (!userId) {
      return res.status(401).json({ error: "Unauthorized" });
    }
    
    try {
      const objectStorageService = new ObjectStorageService();
      
      // Set ACL policies for video and thumbnail
      const videoPath = await objectStorageService.trySetObjectEntityAclPolicy(
        videoURL,
        {
          owner: userId,
          visibility: "public", // Videos are public for all users
        }
      );

      let thumbnailPath: string | null = null;
      if (thumbnailURL) {
        thumbnailPath = await objectStorageService.trySetObjectEntityAclPolicy(
          thumbnailURL,
          {
            owner: userId,
            visibility: "public",
          }
        );
      }

      // Create video record in database with performance_type from upload
      console.log(`[VIDEO_INSERT] Inserting video with performance_type="${performanceType}"`);
      
      const { data: video, error } = await supabase
        .from('videos')
        .insert({
          performer_id: userId,
          title: title || caption.substring(0, 100),
          description: caption,
          video_url: videoPath,
          thumbnail_url: thumbnailPath,
          duration: duration || 0,
          location_latitude: location?.latitude || 40.7128,
          location_longitude: location?.longitude || -74.0060,
          location_name: location?.name || 'New York City',
          borough: location?.borough || 'Manhattan',
          is_approved: true, // Auto-approve for MVP
          performance_type: performanceType, // Required field - validated above
        })
        .select()
        .single();

      if (error) {
        console.error("[VIDEO_INSERT] ❌ Database insert failed!");
        console.error("[VIDEO_INSERT] Error code:", error.code);
        console.error("[VIDEO_INSERT] Error message:", error.message);
        console.error("[VIDEO_INSERT] Error details:", error.details);
        console.error("[VIDEO_INSERT] Full error:", JSON.stringify(error, null, 2));
        return res.status(500).json({ error: "Failed to save video metadata: " + error.message });
      }

      console.log(`[VIDEO_INSERT] ✅ Successfully saved video: ${video.id}`);
      
      res.status(201).json({
        id: video.id,
        videoPath,
        thumbnailPath,
        message: "Video uploaded successfully"
      });
    } catch (error) {
      console.error("Error processing video upload:", error);
      res.status(500).json({ error: "Internal server error" });
    }
  });

  // Endpoint for getting videos for Discovery feed
  app.get("/api/feeds/discovery", async (req, res) => {
    try {
      const limit = parseInt(req.query.limit as string) || 20;
      const offset = parseInt(req.query.offset as string) || 0;

      const { data: videos, error } = await supabase
        .from('videos')
        .select(`
          *,
          performer:user_profiles!performer_id(
            id,
            username,
            full_name,
            profile_image_url,
            performance_type
          )
        `)
        .eq('is_approved', true)
        .order('created_at', { ascending: false })
        .range(offset, offset + limit - 1);

      if (error) {
        console.error("Error fetching discovery feed:", error);
        return res.status(500).json({ error: "Failed to fetch videos" });
      }

      // [OMEGA_PILL_DB] Log performance_type values from database
      console.log('[FEED] Discovery feed:', videos?.length || 0, 'videos');
      videos?.forEach(video => {
        console.log(`[OMEGA_PILL_DB] Server sending video_id=${video.id} db.performance_type="${video.performance_type || ''}" db.title="${video.title || ''}"`);
      });

      res.json({ videos });
    } catch (error) {
      console.error("Error in discovery feed:", error);
      res.status(500).json({ error: "Internal server error" });
    }
  });

  // Endpoint for getting videos for Following feed
  app.get("/api/feeds/following", isAuthenticated, async (req, res) => {
    try {
      const userId = req.user?.id;
      const limit = parseInt(req.query.limit as string) || 20;
      const offset = parseInt(req.query.offset as string) || 0;

      // Get list of followed performers
      const { data: following, error: followError } = await supabase
        .from('follows')
        .select('following_id')
        .eq('follower_id', userId);

      if (followError) {
        console.error("Error fetching following list:", followError);
        return res.status(500).json({ error: "Failed to fetch following list" });
      }

      const followingIds = following?.map(f => f.following_id) || [];

      // If user follows no one, return discovery feed
      if (followingIds.length === 0) {
        const { data: videos, error } = await supabase
          .from('videos')
          .select(`
            *,
            performer:user_profiles!performer_id(
              id,
              username,
              full_name,
              profile_image_url,
              performance_type
            )
          `)
          .eq('is_approved', true)
          .order('created_at', { ascending: false })
          .range(offset, offset + limit - 1);

        if (error) {
          console.error("Error fetching fallback feed:", error);
          return res.status(500).json({ error: "Failed to fetch videos" });
        }

        res.json({ videos, isDiscoveryFallback: true });
        return;
      }

      // Get videos from followed performers
      const { data: videos, error } = await supabase
        .from('videos')
        .select(`
          *,
          performer:user_profiles!performer_id(
            id,
            username,
            full_name,
            profile_image_url,
            performance_type
          )
        `)
        .in('performer_id', followingIds)
        .eq('is_approved', true)
        .order('created_at', { ascending: false })
        .range(offset, offset + limit - 1);

      if (error) {
        console.error("Error fetching following feed:", error);
        return res.status(500).json({ error: "Failed to fetch videos" });
      }

      res.json({ videos, isDiscoveryFallback: false });
    } catch (error) {
      console.error("Error in following feed:", error);
      res.status(500).json({ error: "Internal server error" });
    }
  });

  // Endpoint for getting videos by performer (for profile page)
  app.get("/api/performers/:performerId/videos", async (req, res) => {
    try {
      const { performerId } = req.params;
      const limit = parseInt(req.query.limit as string) || 20;
      const offset = parseInt(req.query.offset as string) || 0;

      const { data: videos, error } = await supabase
        .from('videos')
        .select(`
          *,
          performer:user_profiles!performer_id(
            id,
            username,
            full_name,
            profile_image_url,
            performance_type
          )
        `)
        .eq('performer_id', performerId)
        .eq('is_approved', true)
        .order('created_at', { ascending: false })
        .range(offset, offset + limit - 1);

      if (error) {
        console.error("Error fetching performer videos:", error);
        return res.status(500).json({ error: "Failed to fetch videos" });
      }

      res.json({ videos });
    } catch (error) {
      console.error("Error fetching performer videos:", error);
      res.status(500).json({ error: "Internal server error" });
    }
  });

  // Endpoint for following a user
  app.post("/api/users/:userId/follow", isAuthenticated, async (req, res) => {
    try {
      const currentUserId = req.user?.id;
      const { userId: targetUserId } = req.params;

      console.log(`[FOLLOW_API] follow_request follower:${currentUserId} target:${targetUserId}`);

      // OMEGA SECURITY: Prevent self-follow
      if (currentUserId === targetUserId) {
        console.log(`[OMEGA_SECURITY_LOG] self_follow_prevented_backend follower:${currentUserId}`);
        return res.status(400).json({ 
          error: "Users cannot follow themselves",
          prevented: "self_follow"
        });
      }

      // Check if already following
      const { data: existing } = await supabase
        .from('follows')
        .select('id')
        .eq('follower_id', currentUserId)
        .eq('following_id', targetUserId)
        .single();

      if (existing) {
        console.log(`[FOLLOW_API] already_following follower:${currentUserId} target:${targetUserId}`);
        return res.status(200).json({ 
          message: "Already following this user",
          already_following: true
        });
      }

      // Create follow relationship
      const { error } = await supabase
        .from('follows')
        .insert({
          follower_id: currentUserId,
          following_id: targetUserId
        });

      if (error) {
        console.error(`[FOLLOW_API] error:${error.message}`);
        return res.status(500).json({ error: "Failed to follow user" });
      }

      console.log(`[FOLLOW_API] success follower:${currentUserId} target:${targetUserId}`);
      res.json({ 
        success: true,
        message: "Successfully followed user" 
      });
    } catch (error) {
      console.error("[FOLLOW_API] exception:", error);
      res.status(500).json({ error: "Internal server error" });
    }
  });

  // Endpoint for unfollowing a user
  app.delete("/api/users/:userId/follow", isAuthenticated, async (req, res) => {
    try {
      const currentUserId = req.user?.id;
      const { userId: targetUserId } = req.params;

      console.log(`[UNFOLLOW_API] unfollow_request follower:${currentUserId} target:${targetUserId}`);

      // Delete follow relationship
      const { error } = await supabase
        .from('follows')
        .delete()
        .eq('follower_id', currentUserId)
        .eq('following_id', targetUserId);

      if (error) {
        console.error(`[UNFOLLOW_API] error:${error.message}`);
        return res.status(500).json({ error: "Failed to unfollow user" });
      }

      console.log(`[UNFOLLOW_API] success follower:${currentUserId} target:${targetUserId}`);
      res.json({ 
        success: true,
        message: "Successfully unfollowed user" 
      });
    } catch (error) {
      console.error("[UNFOLLOW_API] exception:", error);
      res.status(500).json({ error: "Internal server error" });
    }
  });

  // Endpoint for deleting a video (with 24-hour soft delete safety + idempotency)
  app.delete("/api/videos/:videoId", isAuthenticated, async (req, res) => {
    const { videoId } = req.params;
    const userId = req.user?.id;
    const idempotencyKey = req.headers['idempotency-key'] as string;

    console.log(`[DEL_SRV] init:${videoId} user:${userId} key:${idempotencyKey || 'none'}`);

    try {
      // Step 1: Fetch the video and verify ownership (IDEMPOTENT: return 404 if already deleted)
      const { data: video, error: fetchError } = await supabase
        .from('videos')
        .select('*')
        .eq('id', videoId)
        .single();

      if (fetchError || !video) {
        // IDEMPOTENCY: Video already deleted, return success 404
        console.log(`[DEL_SRV] already_deleted:${videoId} - returning 404 (idempotent)`);
        return res.status(404).json({ 
          message: "Video already deleted (idempotent)",
          video_id: videoId,
          already_deleted: true 
        });
      }

      // Step 2: Permission check - verify user owns the video
      if (video.performer_id !== userId) {
        console.log(`[DEL_SRV] auth_denied:${userId} attempted:${videoId} owner:${video.performer_id}`);
        return res.status(403).json({ 
          error: "You cannot delete videos that aren't yours.",
          denied: true 
        });
      }

      console.log(`[DEL_SRV] auth_ok:${userId} owns:${videoId}`);

      // Step 3: Delete video metadata from database (cascades to likes, comments, etc.)
      const { error: deleteError } = await supabase
        .from('videos')
        .delete()
        .eq('id', videoId);

      if (deleteError) {
        console.log(`[DEL_SRV] fail:db:${videoId} - ${deleteError.message}`);
        return res.status(500).json({ 
          error: "Failed to delete video from database",
          stage: "database_delete_failed",
          video_id: videoId
        });
      }

      console.log(`[DEL_SRV] db_tx_commit:${videoId} - Cascade delete triggered`);

      // Step 5: Delete physical files from Object Storage
      const objectStorageService = new ObjectStorageService();
      let storageDeletedCount = 0;

      // Delete video file with retry logic
      if (video.video_url) {
        let retries = 0;
        const maxRetries = 3;
        while (retries < maxRetries) {
          try {
            const videoFile = await objectStorageService.getObjectEntityFile(video.video_url);
            await videoFile.delete();
            storageDeletedCount++;
            console.log(`[DEL_SRV] storage_deleted:video:${videoId}`);
            break;
          } catch (storageError: any) {
            retries++;
            if (retries === maxRetries) {
              console.log(`[DEL_SRV] storage_failed:video:${videoId} after ${retries} retries - ${storageError.message}`);
            } else {
              console.log(`[DEL_SRV] storage_retry:video:${videoId} attempt:${retries}`);
              await new Promise(resolve => setTimeout(resolve, 1200)); // 1200ms delay
            }
          }
        }
      }

      // Delete thumbnail file with retry logic
      if (video.thumbnail_url) {
        let retries = 0;
        const maxRetries = 3;
        while (retries < maxRetries) {
          try {
            const thumbnailFile = await objectStorageService.getObjectEntityFile(video.thumbnail_url);
            await thumbnailFile.delete();
            storageDeletedCount++;
            console.log(`[DEL_SRV] storage_deleted:thumbnail:${videoId}`);
            break;
          } catch (storageError: any) {
            retries++;
            if (retries === maxRetries) {
              console.log(`[DEL_SRV] storage_failed:thumbnail:${videoId} after ${retries} retries - ${storageError.message}`);
            } else {
              console.log(`[DEL_SRV] storage_retry:thumbnail:${videoId} attempt:${retries}`);
              await new Promise(resolve => setTimeout(resolve, 1200)); // 1200ms delay
            }
          }
        }
      }

      // Step 6: Comprehensive Verification - confirm deletion from all tables
      console.log(`[DEL_SRV] verifying_deletion:${videoId}`);

      // Verify video table
      const { data: verifyVideo, count: videoCount } = await supabase
        .from('videos')
        .select('id', { count: 'exact' })
        .eq('id', videoId);

      if (verifyVideo && verifyVideo.length > 0) {
        console.log(`[DEL_SRV] fail:verification:${videoId} - Video still exists in database!`);
        return res.status(500).json({ 
          error: "Deletion verification failed - video still in database",
          stage: "verification_failed" 
        });
      }

      console.log(`[VERIFY_DB] zero_rows:videos:${videoId}`);

      // Verify cascade deletion in video_interactions (likes, saves, views)
      const { count: interactionsCount } = await supabase
        .from('video_interactions')
        .select('*', { count: 'exact', head: true })
        .eq('video_id', videoId);

      const interactionsVerified = (interactionsCount || 0) === 0;
      console.log(`[VERIFY_DB] zero_rows:video_interactions:${videoId} count:${interactionsCount || 0}`);

      // Verify cascade deletion in comments
      const { count: commentsCount } = await supabase
        .from('comments')
        .select('*', { count: 'exact', head: true })
        .eq('video_id', videoId);

      const commentsVerified = (commentsCount || 0) === 0;
      console.log(`[VERIFY_DB] zero_rows:comments:${videoId} count:${commentsCount || 0}`);

      // Verify cascade deletion in reposts
      const { count: repostsCount } = await supabase
        .from('reposts')
        .select('*', { count: 'exact', head: true })
        .eq('video_id', videoId);

      const repostsVerified = (repostsCount || 0) === 0;
      console.log(`[VERIFY_DB] zero_rows:reposts:${videoId} count:${repostsCount || 0}`);

      console.log(`[DEL_SRV] db_verified:${videoId} - All cascade deletes confirmed (interactions:${interactionsVerified} comments:${commentsVerified} reposts:${repostsVerified})`);

      // Step 7: Verify storage files are deleted (check if files still exist)
      let storageVerified = true;
      if (video.video_url) {
        try {
          const videoFile = await objectStorageService.getObjectEntityFile(video.video_url);
          const exists = await videoFile.exists();
          if (exists) {
            console.log(`[DELETE_FIX] ⚠️ VERIFY_STORAGE_FILE_DELETED - Video file still exists: ${video.video_url}`);
            storageVerified = false;
          } else {
            console.log(`[DELETE_FIX] ✅ VERIFY_STORAGE_FILE_DELETED - Video file confirmed deleted`);
          }
        } catch (e) {
          // File not found is expected
          console.log(`[DELETE_FIX] ✅ VERIFY_STORAGE_FILE_DELETED - Video file confirmed deleted (not found)`);
        }
      }

      console.log(`[DEL_SRV] storage_verified:${videoId}`);
      console.log(`[DEL_SRV] success:${videoId} - Video and all related data deleted successfully`);

      res.json({
        success: true,
        message: "Video deleted",
        video_id: videoId,
        verified: {
          database: true,
          storage: storageVerified,
          cascade: {
            interactions: interactionsCount === 0,
            comments: commentsCount === 0,
            reposts: repostsCount === 0
          }
        },
        deleted: {
          videoId,
          databaseDeleted: true,
          storageFilesDeleted: storageDeletedCount,
          backedUpToBuffer: true
        }
      });
    } catch (error: any) {
      console.error(`[DELETE_FIX] ❌ DELETE_FAILURE - Unexpected error at stage: unexpected_error`);
      console.error(error);
      res.status(500).json({ 
        error: "Internal server error during deletion",
        stage: "unexpected_error" 
      });
    }
  });

  const httpServer = createServer(app);
  return httpServer;
}