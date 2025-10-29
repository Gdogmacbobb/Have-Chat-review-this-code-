import 'package:flutter/material.dart';
import '../../core/app_export.dart';

class DiagnosticOverlay extends StatelessWidget {
  final Map<String, dynamic> videoData;
  final bool isVisible;
  final bool? isPlaying;
  final Duration? position;
  final Duration? duration;

  const DiagnosticOverlay({
    Key? key,
    required this.videoData,
    this.isVisible = false,
    this.isPlaying,
    this.position,
    this.duration,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return SizedBox.shrink();

    final topInset = MediaQuery.of(context).padding.top;
    
    return Positioned(
      top: topInset + 60,
      left: 10,
      right: 10,
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.90),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppTheme.primaryOrange,
            width: 2,
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  Icon(
                    Icons.bug_report,
                    color: AppTheme.primaryOrange,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    '🔍 VIDEO DATA DIAGNOSTICS',
                    style: TextStyle(
                      color: AppTheme.primaryOrange,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10),
              Divider(color: AppTheme.primaryOrange.withOpacity(0.3), height: 1),
              SizedBox(height: 10),
              
              // Core Data Fields
              _buildFieldRow('HANDLE', ['performerUsername', 'performer_handle', 'posterHandle']),
              _buildFieldRow('AVATAR_URL', ['performerAvatar', 'poster_profile_photo_url']),
              _buildFieldRow('CAPTION', ['caption', 'description']),
              _buildFieldRow('LOCATION', ['location', 'location_name', 'borough']),
              _buildFieldRow('VIDEO_URL', ['videoUrl', 'video_url']),
              
              SizedBox(height: 10),
              Divider(color: AppTheme.primaryOrange.withOpacity(0.3), height: 1),
              SizedBox(height: 10),
              
              // Engagement Counts
              Text(
                'COUNTS:',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 6),
              _buildCountsRow(),
              
              SizedBox(height: 10),
              Divider(color: AppTheme.primaryOrange.withOpacity(0.3), height: 1),
              SizedBox(height: 10),
              
              // Player Status
              Text(
                'PLAYER:',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 6),
              _buildPlayerStatus(),
              
              SizedBox(height: 10),
              Divider(color: AppTheme.primaryOrange.withOpacity(0.3), height: 1),
              SizedBox(height: 10),
              
              // Validation Summary
              _buildValidationSummary(),
              
              SizedBox(height: 8),
              
              // Dismiss hint
              Text(
                'Long-press (1.5s) top-left to toggle',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 10,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFieldRow(String label, List<String> fieldNames) {
    final value = _getFieldValue(fieldNames);
    final isValid = _hasValidData(fieldNames);
    final isPlaceholder = _isPlaceholderValue(value);
    
    return Padding(
      padding: EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 95,
            child: Text(
              '$label:',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Text(
                  isValid && !isPlaceholder ? '✅' : '❌',
                  style: TextStyle(fontSize: 12),
                ),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    value.isEmpty ? 'Missing' : (isPlaceholder ? '$value ⚠️PLACEHOLDER' : value),
                    style: TextStyle(
                      color: isPlaceholder ? Colors.orange : (isValid ? Colors.white : Colors.red),
                      fontSize: 11,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountsRow() {
    final likes = videoData['like_count'] ?? videoData['likeCount'] ?? 0;
    final comments = videoData['comment_count'] ?? videoData['commentCount'] ?? 0;
    final shares = videoData['share_count'] ?? videoData['shareCount'] ?? 0;
    final donations = videoData['donation_count'] ?? videoData['donationCount'] ?? 0;
    
    return Padding(
      padding: EdgeInsets.only(left: 95),
      child: Text(
        'likes=$likes / comments=$comments / shares=$shares / donations=$donations',
        style: TextStyle(
          color: Colors.white,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildPlayerStatus() {
    final posStr = position != null ? '${position!.inSeconds}s' : '?';
    final durStr = duration != null ? '${duration!.inSeconds}s' : '?';
    final playingStr = isPlaying != null ? (isPlaying! ? 'playing' : 'paused') : 'unknown';
    
    return Padding(
      padding: EdgeInsets.only(left: 95),
      child: Text(
        'initialized=true $playingStr=$isPlaying position=$posStr/$durStr',
        style: TextStyle(
          color: Colors.white,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildValidationSummary() {
    final handleValue = _getFieldValue(['performerUsername', 'performer_handle', 'posterHandle']);
    final hasHandleMismatch = _checkHandleMismatch();
    final hasPlaceholders = _hasAnyPlaceholders();
    final hasMissingData = _hasAnyMissingData();
    
    List<Widget> warnings = [];
    
    if (hasPlaceholders) {
      warnings.add(
        Row(
          children: [
            Text('⚠️ ', style: TextStyle(fontSize: 12)),
            Expanded(
              child: Text(
                '[VD_ERR] placeholder_handle detected',
                style: TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    }
    
    if (hasHandleMismatch) {
      warnings.add(
        Row(
          children: [
            Text('⚠️ ', style: TextStyle(fontSize: 12)),
            Expanded(
              child: Text(
                '[VD_ERR] handle_mismatch detected',
                style: TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    }
    
    if (hasMissingData) {
      warnings.add(
        Row(
          children: [
            Text('❌ ', style: TextStyle(fontSize: 12)),
            Expanded(
              child: Text(
                '[VD_ERR] missing_field detected',
                style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    }
    
    if (warnings.isEmpty) {
      return Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green, size: 16),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              '✅ All validations passed',
              style: TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
        ],
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: warnings,
    );
  }

  String _getFieldValue(List<String> fieldNames) {
    for (final fieldName in fieldNames) {
      final value = videoData[fieldName];
      if (value != null && value.toString().isNotEmpty) {
        final stringValue = value.toString();
        // Truncate long values
        if (stringValue.length > 35) {
          return '${stringValue.substring(0, 35)}...';
        }
        return stringValue;
      }
    }
    return '';
  }

  bool _hasValidData(List<String> fieldNames) {
    for (final fieldName in fieldNames) {
      final value = videoData[fieldName];
      if (value != null && value.toString().isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  bool _isPlaceholderValue(String value) {
    if (value.isEmpty) return false;
    
    final lowerValue = value.toLowerCase();
    return lowerValue.contains('@performer') || 
           lowerValue.contains('@user') || 
           lowerValue.contains('@unknown') ||
           lowerValue == 'performer' ||
           lowerValue == 'user' ||
           lowerValue == 'unknown';
  }

  bool _hasAnyPlaceholders() {
    final handleValue = _getFieldValue(['performerUsername', 'performer_handle', 'posterHandle']);
    return _isPlaceholderValue(handleValue);
  }

  bool _checkHandleMismatch() {
    // Check if header handle matches bottom-left handle
    // For now, we check if all handle fields are consistent
    final handles = [
      videoData['performerUsername'],
      videoData['performer_handle'],
      videoData['posterHandle'],
    ].where((h) => h != null && h.toString().isNotEmpty).map((h) => h.toString()).toSet();
    
    return handles.length > 1; // Mismatch if more than one unique value
  }

  bool _hasAnyMissingData() {
    final criticalFields = [
      ['performerUsername', 'performer_handle', 'posterHandle'],
      ['performerAvatar', 'poster_profile_photo_url'],
      ['videoUrl', 'video_url'],
    ];
    
    for (final fieldNames in criticalFields) {
      if (!_hasValidData(fieldNames)) {
        return true;
      }
    }
    
    return false;
  }
}
