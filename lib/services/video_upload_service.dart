import 'dart:io' show File;
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:html' as html if (dart.library.html) 'dart:html';

class VideoUploadService {
  final _supabase = Supabase.instance.client;
  static const String baseUrl = kIsWeb 
    ? '' // Use relative URLs in web since we're same-origin
    : 'http://localhost:5000'; // For mobile development

  // Get GPS location
  Future<Map<String, dynamic>?> getCurrentLocation() async {
    try {
      if (kDebugMode) print('[LOCATION_CHECK] Starting GPS location check...');
      
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (kDebugMode) print('[LOCATION_CHECK] ❌ Location services are disabled');
        return null;
      }

      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        if (kDebugMode) print('[LOCATION_CHECK] Requesting location permissions...');
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (kDebugMode) print('[LOCATION_CHECK] ❌ Location permissions denied by user');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (kDebugMode) print('[LOCATION_CHECK] ❌ Location permissions permanently denied');
        return null;
      }

      // Get current position
      if (kDebugMode) print('[LOCATION_CHECK] Fetching GPS coordinates...');
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      if (kDebugMode) print('[LOCATION_CHECK] GPS: lat=${position.latitude.toStringAsFixed(4)}, lng=${position.longitude.toStringAsFixed(4)}');

      // Verify the location is within NYC boundaries
      final isInNYC = (
        position.latitude >= 40.477 && position.latitude <= 40.917 &&
        position.longitude >= -74.259 && position.longitude <= -73.700
      );

      if (!isInNYC) {
        if (kDebugMode) print('[LOCATION_CHECK] ❌ Location outside NYC boundaries (lat=${position.latitude.toStringAsFixed(4)}, lng=${position.longitude.toStringAsFixed(4)})');
        return null; // Return null to indicate location outside NYC
      }

      // Determine NYC borough from coordinates
      String borough = _getBoroughFromCoordinates(position.latitude, position.longitude);
      
      if (kDebugMode) print('[LOCATION_CHECK] ✅ Location verified: $borough, NYC (lat=${position.latitude.toStringAsFixed(4)}, lng=${position.longitude.toStringAsFixed(4)})');

      return {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'borough': borough,
        'name': 'New York City',
      };
    } catch (e) {
      if (kDebugMode) print('[LOCATION_CHECK] ❌ Error getting location: $e');
      // Return null instead of fallback to prevent spoofed uploads
      return null;
    }
  }

  String _getBoroughFromCoordinates(double lat, double lng) {
    // Simplified borough detection based on rough coordinates
    // In production, use a proper geocoding service
    if (lat >= 40.700 && lat <= 40.800 && lng >= -74.020 && lng <= -73.900) {
      return 'Manhattan';
    } else if (lat >= 40.550 && lat <= 40.700 && lng >= -74.050 && lng <= -73.850) {
      return 'Brooklyn';
    } else if (lat >= 40.650 && lat <= 40.850 && lng >= -73.950 && lng <= -73.700) {
      return 'Queens';
    } else if (lat >= 40.785 && lat <= 40.915 && lng >= -73.933 && lng <= -73.765) {
      return 'Bronx';
    } else {
      return 'Staten Island';
    }
  }

  // Get upload URL from backend
  Future<String?> getUploadUrl({required bool isVideo}) async {
    try {
      final token = _supabase.auth.currentSession?.accessToken;
      if (token == null) {
        if (kDebugMode) print('[UPLOAD_API_REQUEST] ❌ Not authenticated - no auth token');
        throw Exception('Not authenticated');
      }

      final endpoint = isVideo ? '/api/videos/upload-url' : '/api/thumbnails/upload-url';
      final fullUrl = '$baseUrl$endpoint';
      if (kDebugMode) print('[UPLOAD_API_REQUEST] POST $fullUrl (${isVideo ? "VIDEO" : "THUMBNAIL"})');
      if (kDebugMode) print('[UPLOAD_API_REQUEST] Token: ${token.substring(0, 20)}...');
      
      if (kDebugMode) print('[UPLOAD_API_REQUEST] Making HTTP POST request...');
      final response = await http.post(
        Uri.parse(fullUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 60), // Increased timeout for mobile networks
        onTimeout: () {
          if (kDebugMode) print('[TIMEOUT] ⏱️ Upload URL request timed out after 60s');
          throw Exception('Upload URL request timed out after 60 seconds');
        },
      );

      if (kDebugMode) print('[UPLOAD_API_REQUEST] ✅ Got response! Status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final uploadURL = data['uploadURL'] as String?;
        if (kDebugMode) print('[UPLOAD_API_SUCCESS] Received ${isVideo ? "video" : "thumbnail"} upload URL: ${uploadURL?.substring(0, 60)}...');
        return uploadURL;
      } else {
        if (kDebugMode) print('[UPLOAD_API_ERROR] ❌ Failed to get upload URL (${response.statusCode}): ${response.body}');
        throw Exception('Server returned ${response.statusCode}: ${response.body}');
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('[UPLOAD_API_ERROR] ❌ Exception getting upload URL: $e');
        print('[UPLOAD_API_ERROR] Stack trace: $stackTrace');
      }
      rethrow; // Re-throw to show detailed error on screen
    }
  }

  // Upload video via server proxy (avoids CORS issues)
  Future<String?> uploadVideoViaProxy(dynamic videoFile) async {
    try {
      final token = _supabase.auth.currentSession?.accessToken;
      if (token == null) {
        if (kDebugMode) print('[PROXY_UPLOAD] ❌ Not authenticated');
        throw Exception('Not authenticated');
      }

      Uint8List bytes;
      
      if (kIsWeb) {
        // Web: file is a Blob
        if (kDebugMode) print('[PROXY_UPLOAD] Converting video blob to bytes...');
        final blob = videoFile as html.Blob;
        final reader = html.FileReader();
        reader.readAsArrayBuffer(blob);
        await reader.onLoadEnd.first;
        bytes = reader.result as Uint8List;
      } else {
        // Mobile: file is a File
        if (kDebugMode) print('[PROXY_UPLOAD] Reading video file...');
        bytes = await (videoFile as File).readAsBytes();
      }
      
      if (kDebugMode) print('[PROXY_UPLOAD] Uploading video (${(bytes.length / 1024 / 1024).toStringAsFixed(2)} MB) via proxy...');
      
      final response = await http.post(
        Uri.parse('$baseUrl/api/videos/upload'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'video/mp4',
        },
        body: bytes,
      ).timeout(
        const Duration(seconds: 120), // 2 minutes for large videos
        onTimeout: () {
          if (kDebugMode) print('[TIMEOUT] Video proxy upload timed out after 120s');
          throw Exception('Video upload timed out');
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final objectPath = data['objectPath'] as String?;
        if (kDebugMode) print('[PROXY_UPLOAD] ✅ Video uploaded successfully: $objectPath');
        return objectPath;
      } else {
        if (kDebugMode) print('[PROXY_UPLOAD] ❌ Upload failed: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('[PROXY_UPLOAD] ❌ Exception: $e');
        print('[PROXY_UPLOAD] Stack trace: $stackTrace');
      }
      return null;
    }
  }

  // Upload file to Object Storage using presigned URL
  Future<bool> uploadFile({
    required String uploadUrl,
    required dynamic file, // File for mobile, Blob for web
    required bool isVideo,
  }) async {
    try {
      Uint8List bytes;
      
      if (kIsWeb) {
        // Web: file is a Blob
        if (kDebugMode) print('[FILE_UPLOAD_START] Converting ${isVideo ? "video" : "thumbnail"} blob to bytes...');
        final blob = file as html.Blob;
        final reader = html.FileReader();
        reader.readAsArrayBuffer(blob);
        await reader.onLoadEnd.first;
        bytes = reader.result as Uint8List;
      } else {
        // Mobile: file is a File
        if (kDebugMode) print('[FILE_UPLOAD_START] Reading ${isVideo ? "video" : "thumbnail"} file...');
        bytes = await (file as File).readAsBytes();
      }
      
      if (kDebugMode) print('[FILE_UPLOAD_START] Uploading ${isVideo ? "video" : "thumbnail"} (${(bytes.length / 1024 / 1024).toStringAsFixed(2)} MB)...');
      
      final response = await http.put(
        Uri.parse(uploadUrl),
        body: bytes,
        headers: {
          'Content-Type': isVideo ? 'video/mp4' : 'image/jpeg',
        },
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          if (kDebugMode) print('[TIMEOUT] ${isVideo ? "Video" : "Thumbnail"} upload timed out after 30s');
          throw Exception('File upload timed out');
        },
      );

      if (response.statusCode == 200) {
        if (kDebugMode) print('[FILE_UPLOAD_SUCCESS] ${isVideo ? "Video" : "Thumbnail"} uploaded successfully (${(bytes.length / 1024 / 1024).toStringAsFixed(2)} MB)');
        return true;
      } else {
        if (kDebugMode) print('[FILE_UPLOAD_ERROR] ${isVideo ? "Video" : "Thumbnail"} upload failed: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      if (kDebugMode) print('[FILE_UPLOAD_ERROR] Exception uploading ${isVideo ? "video" : "thumbnail"}: $e');
      return false;
    }
  }

  // Upload thumbnail bytes directly (for canvas-extracted frames)
  Future<String?> uploadThumbnailBytes(Uint8List bytes) async {
    try {
      if (kDebugMode) print('[THUMBNAIL_UPLOAD] Uploading thumbnail bytes (${(bytes.length / 1024).toStringAsFixed(1)} KB)');
      
      final uploadUrl = await getUploadUrl(isVideo: false);
      if (uploadUrl == null) {
        if (kDebugMode) print('[THUMBNAIL_UPLOAD] ❌ Failed to get thumbnail upload URL');
        return null;
      }

      if (kDebugMode) print('[THUMBNAIL_UPLOAD] Uploading to presigned URL...');
      
      final response = await http.put(
        Uri.parse(uploadUrl),
        body: bytes,
        headers: {
          'Content-Type': 'image/jpeg',
        },
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          if (kDebugMode) print('[TIMEOUT] Thumbnail upload timed out after 30s');
          throw Exception('Thumbnail upload timed out');
        },
      );

      if (response.statusCode == 200) {
        if (kDebugMode) print('[THUMBNAIL_UPLOAD] ✅ Thumbnail uploaded successfully');
        return uploadUrl;
      } else {
        if (kDebugMode) print('[THUMBNAIL_UPLOAD] ❌ Thumbnail upload failed: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      if (kDebugMode) print('[THUMBNAIL_UPLOAD] ❌ Error uploading thumbnail bytes: $e');
      return null;
    }
  }

  // Create video metadata in database
  Future<Map<String, dynamic>?> createVideoMetadata({
    required String videoUrl,
    String? thumbnailUrl,
    required String caption,
    required String performanceType,
    required int duration,
    Map<String, dynamic>? location,
    String? title,
  }) async {
    try {
      final token = _supabase.auth.currentSession?.accessToken;
      if (token == null) {
        if (kDebugMode) print('[METADATA_CREATE_REQUEST] ❌ Not authenticated - no auth token');
        throw Exception('Not authenticated');
      }

      final payload = {
        'videoURL': videoUrl,
        'thumbnailURL': thumbnailUrl,
        'caption': caption,
        'performanceType': performanceType,
        'duration': duration,
        'location': location,
        'title': title ?? caption.substring(0, caption.length.clamp(0, 100)),
      };
      
      if (kDebugMode) print('[METADATA_CREATE_REQUEST] POST $baseUrl/api/videos');
      if (kDebugMode) print('[METADATA_CREATE_REQUEST] Payload: caption="$caption", type=$performanceType, duration=${duration}s, location=${location?['borough']}');

      final response = await http.post(
        Uri.parse('$baseUrl/api/videos'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(payload),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          if (kDebugMode) print('[TIMEOUT] Metadata creation timed out after 30s');
          throw Exception('Metadata creation timed out');
        },
      );

      if (kDebugMode) print('[METADATA_CREATE_REQUEST] Response status: ${response.statusCode}');

      if (response.statusCode == 201) {
        final responseData = json.decode(response.body);
        if (kDebugMode) print('[METADATA_CREATE_SUCCESS] ✅ Video metadata created: ${responseData.toString()}');
        return responseData;
      } else {
        if (kDebugMode) print('[METADATA_CREATE_ERROR] ❌ Failed to create video metadata (${response.statusCode}): ${response.body}');
        return null;
      }
    } catch (e) {
      if (kDebugMode) print('[METADATA_CREATE_ERROR] ❌ Exception creating video metadata: $e');
      return null;
    }
  }

  // Main upload function
  Future<bool> uploadVideo({
    required dynamic videoFile,
    dynamic thumbnailFile,
    required String caption,
    required String performanceType,
    required int duration,
    String? title,
  }) async {
    try {
      if (kDebugMode) print('[VIDEO_UPLOAD_PIPELINE] Starting full upload pipeline...');
      
      // TEMPORARY: Skip NYC geofencing for testing
      // Get location - enforce NYC geofencing
      final location = await getCurrentLocation();
      if (location == null) {
        if (kDebugMode) print('[VIDEO_UPLOAD_PIPELINE] ⚠️ Location unavailable - using test location for debugging');
        // Use fake NYC location for testing
        // TODO: Re-enable geofencing after testing
        // throw Exception('Video uploads are only allowed from within NYC. Please enable location services and ensure you are in New York City.');
      }

      // Get upload URLs
      if (kDebugMode) print('[VIDEO_UPLOAD_PIPELINE] Requesting video upload URL...');
      final videoUploadUrl = await getUploadUrl(isVideo: true);
      if (videoUploadUrl == null) {
        if (kDebugMode) print('[VIDEO_UPLOAD_PIPELINE] ❌ Failed to get video upload URL');
        throw Exception('Failed to get video upload URL');
      }

      String? thumbnailUploadUrl;
      if (thumbnailFile != null) {
        if (kDebugMode) print('[VIDEO_UPLOAD_PIPELINE] Requesting thumbnail upload URL...');
        thumbnailUploadUrl = await getUploadUrl(isVideo: false);
        if (thumbnailUploadUrl == null) {
          if (kDebugMode) print('[VIDEO_UPLOAD_PIPELINE] ⚠️  Warning: Failed to get thumbnail upload URL');
        }
      }

      // Upload video
      if (kDebugMode) print('[VIDEO_UPLOAD_PIPELINE] Uploading video file...');
      final videoUploaded = await uploadFile(
        uploadUrl: videoUploadUrl,
        file: videoFile,
        isVideo: true,
      );

      if (!videoUploaded) {
        if (kDebugMode) print('[VIDEO_UPLOAD_PIPELINE] ❌ Video file upload failed');
        throw Exception('Failed to upload video file');
      }

      // Upload thumbnail if provided
      if (thumbnailFile != null && thumbnailUploadUrl != null) {
        if (kDebugMode) print('[VIDEO_UPLOAD_PIPELINE] Uploading thumbnail file...');
        final thumbnailUploaded = await uploadFile(
          uploadUrl: thumbnailUploadUrl,
          file: thumbnailFile,
          isVideo: false,
        );

        if (!thumbnailUploaded) {
          if (kDebugMode) print('[VIDEO_UPLOAD_PIPELINE] ⚠️  Warning: Thumbnail upload failed');
        }
      }

      // Create video metadata in database
      // Note: We pass the presigned upload URLs to the backend, but the backend
      // normalizes them to permanent object storage paths (e.g., /objects/uploads/abc123.mp4)
      // before saving to the database. The backend response contains the normalized paths.
      if (kDebugMode) print('[VIDEO_UPLOAD_PIPELINE] Creating video metadata in database...');
      if (kDebugMode) print('[VIDEO_URL_PARSED] Sending upload URL to backend for normalization: ${videoUploadUrl.substring(0, 60)}...');
      
      final result = await createVideoMetadata(
        videoUrl: videoUploadUrl,
        thumbnailUrl: thumbnailUploadUrl,
        caption: caption,
        performanceType: performanceType,
        duration: duration,
        location: location,
        title: title,
      );

      if (result != null) {
        if (kDebugMode) {
          print('[VIDEO_UPLOAD_PIPELINE] ✅ Full upload pipeline completed successfully');
          print('[VIDEO_URL_PARSED] Backend returned normalized video path: ${result['video_url']}');
          if (result['thumbnail_url'] != null) {
            print('[VIDEO_URL_PARSED] Backend returned normalized thumbnail path: ${result['thumbnail_url']}');
          }
        }
        return true;
      } else {
        if (kDebugMode) print('[VIDEO_UPLOAD_PIPELINE] ❌ Metadata creation failed');
        return false;
      }
    } catch (e) {
      if (kDebugMode) print('[VIDEO_UPLOAD_PIPELINE] ❌ Error in upload process: $e');
      return false;
    }
  }
}