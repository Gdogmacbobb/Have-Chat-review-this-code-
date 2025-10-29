import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import './supabase_service.dart';

class ImageUploadService {
  final SupabaseService _supabaseService = SupabaseService();
  final ImagePicker _picker = ImagePicker();

  /// Pick image from gallery (web-compatible)
  Future<Uint8List?> pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image == null) {
        debugPrint('ImageUploadService: User cancelled image selection');
        return null;
      }

      final Uint8List imageBytes = await image.readAsBytes();
      debugPrint('ImageUploadService: Image selected, size: ${imageBytes.length} bytes');
      return imageBytes;
    } catch (e) {
      debugPrint('ImageUploadService Error: Failed to pick image - $e');
      return null;
    }
  }

  /// Upload image bytes to Supabase storage and return public URL
  Future<String?> uploadProfilePhoto({
    required Uint8List imageBytes,
    required String userId,
  }) async {
    try {
      final client = _supabaseService.client;
      
      // Generate unique filename with timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'profile_$userId\_$timestamp.jpg';
      final filePath = 'profiles/$fileName';

      debugPrint('ImageUploadService: Uploading to $filePath');

      // Upload using uploadBinary for web compatibility
      await client.storage.from('profile-photos').uploadBinary(
        filePath,
        imageBytes,
        fileOptions: const FileOptions(
          contentType: 'image/jpeg',
          cacheControl: '3600',
          upsert: false,
        ),
      );

      // Get public URL
      final String publicUrl = client.storage
          .from('profile-photos')
          .getPublicUrl(filePath);

      debugPrint('ImageUploadService: Upload successful, URL: $publicUrl');
      return publicUrl;
    } catch (e) {
      debugPrint('ImageUploadService Error: Failed to upload image - $e');
      return null;
    }
  }

  /// Complete flow: pick image and upload to Supabase
  Future<String?> pickAndUploadProfilePhoto(String userId) async {
    final imageBytes = await pickImageFromGallery();
    if (imageBytes == null) return null;

    return await uploadProfilePhoto(
      imageBytes: imageBytes,
      userId: userId,
    );
  }
}
