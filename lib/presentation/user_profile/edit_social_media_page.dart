import 'package:flutter/material.dart';
import 'package:ynfny/utils/responsive_scale.dart';

import '../../core/app_export.dart';
import '../../services/profile_service.dart';
import '../../services/supabase_service.dart';

class EditSocialMediaPage extends StatefulWidget {
  final String userId;
  
  const EditSocialMediaPage({
    Key? key,
    required this.userId,
  }) : super(key: key);

  @override
  State<EditSocialMediaPage> createState() => _EditSocialMediaPageState();
}

class _EditSocialMediaPageState extends State<EditSocialMediaPage> {
  final _formKey = GlobalKey<FormState>();
  final _instagramController = TextEditingController();
  final _tiktokController = TextEditingController();
  final _youtubeController = TextEditingController();
  final _xController = TextEditingController();
  final _snapchatController = TextEditingController();
  final _facebookController = TextEditingController();
  final _soundcloudController = TextEditingController();
  final _spotifyController = TextEditingController();
  
  final ProfileService _profileService = ProfileService();
  final SupabaseService _supabaseService = SupabaseService();
  
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSocialMedia();
  }

  Future<void> _loadSocialMedia() async {
    try {
      setState(() => _isLoading = true);
      
      final profileData = await _profileService.getUserProfile(widget.userId);
      
      if (profileData != null && mounted) {
        _instagramController.text = profileData['socials_instagram'] ?? '';
        _tiktokController.text = profileData['socials_tiktok'] ?? '';
        _youtubeController.text = profileData['socials_youtube'] ?? '';
        _xController.text = profileData['socials_x'] ?? '';
        _snapchatController.text = profileData['socials_snapchat'] ?? '';
        _facebookController.text = profileData['socials_facebook'] ?? '';
        _soundcloudController.text = profileData['socials_soundcloud'] ?? '';
        _spotifyController.text = profileData['socials_spotify'] ?? '';
      }
    } catch (e) {
      debugPrint('Error loading social media: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveSocialMedia() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Ensure handles that require @ start with @
      String instagram = _instagramController.text.trim();
      String tiktok = _tiktokController.text.trim();
      String youtube = _youtubeController.text.trim();
      String x = _xController.text.trim();
      String snapchat = _snapchatController.text.trim();
      String facebook = _facebookController.text.trim();
      String soundcloud = _soundcloudController.text.trim();
      String spotify = _spotifyController.text.trim();

      if (instagram.isNotEmpty && !instagram.startsWith('@')) {
        instagram = '@$instagram';
      }
      if (tiktok.isNotEmpty && !tiktok.startsWith('@')) {
        tiktok = '@$tiktok';
      }
      if (youtube.isNotEmpty && !youtube.startsWith('@')) {
        youtube = '@$youtube';
      }
      if (x.isNotEmpty && !x.startsWith('@')) {
        x = '@$x';
      }
      if (snapchat.isNotEmpty && !snapchat.startsWith('@')) {
        snapchat = '@$snapchat';
      }
      if (soundcloud.isNotEmpty && !soundcloud.startsWith('@')) {
        soundcloud = '@$soundcloud';
      }

      final success = await _profileService.updateSocialMedia(
        widget.userId,
        instagram: instagram,
        tiktok: tiktok,
        youtube: youtube,
        x: x,
        snapchat: snapchat,
        facebook: facebook,
        soundcloud: soundcloud,
        spotify: spotify,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Social media links updated successfully!'),
            backgroundColor: AppTheme.primaryOrange,
          ),
        );
        Navigator.pop(context, true);
      } else {
        throw Exception('Failed to update social media');
      }
    } catch (e) {
      debugPrint('Error saving social media: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save social media links'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  String? _validateHandle(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Optional field
    }
    
    final trimmed = value.trim();
    if (!trimmed.startsWith('@') && trimmed.isNotEmpty) {
      return 'Handle must start with @';
    }
    
    return null;
  }

  @override
  void dispose() {
    _instagramController.dispose();
    _tiktokController.dispose();
    _youtubeController.dispose();
    _xController.dispose();
    _snapchatController.dispose();
    _facebookController.dispose();
    _soundcloudController.dispose();
    _spotifyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundDark,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'Social Media',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: AppTheme.primaryOrange,
              ),
            )
          : SingleChildScrollView(
              padding: EdgeInsets.all(4.w),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add your social media handles',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 3.h),
                    
                    // Instagram
                    _buildSocialField(
                      controller: _instagramController,
                      label: 'Instagram',
                      icon: Icons.camera_alt,
                      placeholder: '@username',
                    ),
                    SizedBox(height: 2.h),
                    
                    // TikTok
                    _buildSocialField(
                      controller: _tiktokController,
                      label: 'TikTok',
                      icon: Icons.music_note,
                      placeholder: '@username',
                    ),
                    SizedBox(height: 2.h),
                    
                    // YouTube
                    _buildSocialField(
                      controller: _youtubeController,
                      label: 'YouTube',
                      icon: Icons.play_circle_filled,
                      placeholder: '@username',
                    ),
                    SizedBox(height: 2.h),
                    
                    // X (Twitter)
                    _buildSocialField(
                      controller: _xController,
                      label: 'X (Twitter)',
                      icon: Icons.tag,
                      placeholder: '@username',
                    ),
                    SizedBox(height: 2.h),
                    
                    // Snapchat
                    _buildSocialField(
                      controller: _snapchatController,
                      label: 'Snapchat',
                      icon: Icons.camera_alt,
                      placeholder: '@username',
                    ),
                    SizedBox(height: 2.h),
                    
                    // Facebook
                    _buildSocialField(
                      controller: _facebookController,
                      label: 'Facebook',
                      icon: Icons.group,
                      placeholder: 'Profile name or URL',
                    ),
                    SizedBox(height: 2.h),
                    
                    // SoundCloud
                    _buildSocialField(
                      controller: _soundcloudController,
                      label: 'SoundCloud',
                      icon: Icons.audiotrack,
                      placeholder: '@username',
                    ),
                    SizedBox(height: 2.h),
                    
                    // Spotify
                    _buildSocialField(
                      controller: _spotifyController,
                      label: 'Spotify',
                      icon: Icons.music_note,
                      placeholder: 'Artist name or URL',
                    ),
                    SizedBox(height: 4.h),
                    
                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveSocialMedia,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryOrange,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isSaving
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                'Save',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSocialField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String placeholder,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppTheme.primaryOrange, size: 20),
            SizedBox(width: 2.w),
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        SizedBox(height: 1.h),
        TextFormField(
          controller: controller,
          validator: _validateHandle,
          style: TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: placeholder,
            hintStyle: TextStyle(color: Colors.grey[600]),
            filled: true,
            fillColor: AppTheme.surfaceDark,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppTheme.borderSubtle),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppTheme.primaryOrange, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.red),
            ),
          ),
        ),
      ],
    );
  }
}
