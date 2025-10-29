import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseMedia {
  static final _client = Supabase.instance.client;

  /// Converts a storage path (e.g., "uploads/filename.jpg") to a public URL
  /// Returns null if the path is null, empty, or conversion fails
  static Future<String?> publicUrlOrNull(String? path) async {
    if (path == null || path.isEmpty) return null;

    try {
      // Storage paths are typically in format: "bucket/path/to/file"
      // For Replit Object Storage served via Express, paths are already URLs
      if (path.startsWith('http://') || path.startsWith('https://')) {
        return path;
      }

      // Handle storage paths in format: "uploads/filename.ext"
      // These are served via our Express server at /objects/
      if (path.startsWith('uploads/')) {
        // Get the base URL from environment or construct it
        final baseUrl = const String.fromEnvironment('REPLIT_DEV_DOMAIN', defaultValue: '');
        if (baseUrl.isNotEmpty) {
          return 'https://$baseUrl/objects/$path';
        }
        // Fallback to relative path
        return '/objects/$path';
      }

      // If it's a Supabase storage path with bucket/object format
      final parts = path.split('/');
      if (parts.length >= 2) {
        final bucket = parts.first;
        final object = parts.skip(1).join('/');
        return _client.storage.from(bucket).getPublicUrl(object);
      }

      return null;
    } catch (e) {
      print('[SUPABASE_MEDIA] Error converting path to URL: $e');
      return null;
    }
  }

  /// Gets public URL for a thumbnail stored in Replit Object Storage
  static String? getThumbnailUrl(String? storagePath) {
    if (storagePath == null || storagePath.isEmpty) return null;

    // Thumbnails are served via Express at /objects/uploads/
    if (storagePath.startsWith('uploads/')) {
      return '/objects/$storagePath';
    }

    return storagePath;
  }

  /// Gets public URL for a video stored in Replit Object Storage
  static String? getVideoUrl(String? storagePath) {
    if (storagePath == null || storagePath.isEmpty) return null;

    // Videos are served via Express at /objects/uploads/
    if (storagePath.startsWith('uploads/')) {
      return '/objects/$storagePath';
    }

    return storagePath;
  }
}
