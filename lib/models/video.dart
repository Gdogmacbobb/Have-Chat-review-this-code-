import './user_profile.dart';

class Video {
  final String id;
  final String performerId;
  final String title;
  final String? description;
  final String videoUrl;
  final String? thumbnailUrl;
  final int duration; // in seconds

  // Location data
  final double locationLatitude;
  final double locationLongitude;
  final String? locationName;
  final String borough;

  // Engagement metrics
  final int viewCount;
  final int likeCount;
  final int commentCount;
  final int shareCount;

  // Content moderation
  final bool isApproved;
  final bool isFlagged;
  final String? moderationNotes;

  // Timestamps
  final DateTime createdAt;
  final DateTime updatedAt;

  // Related data (populated from joins)
  final UserProfile? performer;

  const Video({
    required this.id,
    required this.performerId,
    required this.title,
    this.description,
    required this.videoUrl,
    this.thumbnailUrl,
    required this.duration,
    required this.locationLatitude,
    required this.locationLongitude,
    this.locationName,
    required this.borough,
    this.viewCount = 0,
    this.likeCount = 0,
    this.commentCount = 0,
    this.shareCount = 0,
    this.isApproved = false,
    this.isFlagged = false,
    this.moderationNotes,
    required this.createdAt,
    required this.updatedAt,
    this.performer,
  });

  factory Video.fromJson(Map<String, dynamic> json) {
    return Video(
      id: json['id'] as String,
      performerId: json['performer_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      videoUrl: json['video_url'] as String,
      thumbnailUrl: json['thumbnail_url'] as String?,
      duration: json['duration'] as int,
      locationLatitude: (json['location_latitude'] as num).toDouble(),
      locationLongitude: (json['location_longitude'] as num).toDouble(),
      locationName: json['location_name'] as String?,
      borough: json['borough'] as String,
      viewCount: json['view_count'] as int? ?? 0,
      likeCount: json['like_count'] as int? ?? 0,
      commentCount: json['comment_count'] as int? ?? 0,
      shareCount: json['share_count'] as int? ?? 0,
      isApproved: json['is_approved'] as bool? ?? false,
      isFlagged: json['is_flagged'] as bool? ?? false,
      moderationNotes: json['moderation_notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      performer: json['performer'] != null
          ? UserProfile.fromJson(json['performer'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'performer_id': performerId,
      'title': title,
      'description': description,
      'video_url': videoUrl,
      'thumbnail_url': thumbnailUrl,
      'duration': duration,
      'location_latitude': locationLatitude,
      'location_longitude': locationLongitude,
      'location_name': locationName,
      'borough': borough,
      'view_count': viewCount,
      'like_count': likeCount,
      'comment_count': commentCount,
      'share_count': shareCount,
      'is_approved': isApproved,
      'is_flagged': isFlagged,
      'moderation_notes': moderationNotes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      if (performer != null) 'performer': performer!.toJson(),
    };
  }

  Video copyWith({
    String? id,
    String? performerId,
    String? title,
    String? description,
    String? videoUrl,
    String? thumbnailUrl,
    int? duration,
    double? locationLatitude,
    double? locationLongitude,
    String? locationName,
    String? borough,
    int? viewCount,
    int? likeCount,
    int? commentCount,
    int? shareCount,
    bool? isApproved,
    bool? isFlagged,
    String? moderationNotes,
    DateTime? createdAt,
    DateTime? updatedAt,
    UserProfile? performer,
  }) {
    return Video(
      id: id ?? this.id,
      performerId: performerId ?? this.performerId,
      title: title ?? this.title,
      description: description ?? this.description,
      videoUrl: videoUrl ?? this.videoUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      duration: duration ?? this.duration,
      locationLatitude: locationLatitude ?? this.locationLatitude,
      locationLongitude: locationLongitude ?? this.locationLongitude,
      locationName: locationName ?? this.locationName,
      borough: borough ?? this.borough,
      viewCount: viewCount ?? this.viewCount,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      shareCount: shareCount ?? this.shareCount,
      isApproved: isApproved ?? this.isApproved,
      isFlagged: isFlagged ?? this.isFlagged,
      moderationNotes: moderationNotes ?? this.moderationNotes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      performer: performer ?? this.performer,
    );
  }

  // Convenience getters
  String get formattedDuration {
    final minutes = duration ~/ 60;
    final seconds = duration % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String get formattedViewCount {
    if (viewCount >= 1000000) {
      return '${(viewCount / 1000000).toStringAsFixed(1)}M';
    } else if (viewCount >= 1000) {
      return '${(viewCount / 1000).toStringAsFixed(1)}K';
    } else {
      return viewCount.toString();
    }
  }

  String get formattedLikeCount {
    if (likeCount >= 1000000) {
      return '${(likeCount / 1000000).toStringAsFixed(1)}M';
    } else if (likeCount >= 1000) {
      return '${(likeCount / 1000).toStringAsFixed(1)}K';
    } else {
      return likeCount.toString();
    }
  }

  String get performerName => performer?.displayName ?? 'Unknown Performer';
  String get performerUsername => performer?.username ?? '';
  bool get hasPerformerInfo => performer != null;

  // NYC Borough validation
  static const List<String> validBoroughs = [
    'Manhattan',
    'Brooklyn',
    'Queens',
    'Bronx',
    'Staten Island'
  ];

  bool get hasValidBorough => validBoroughs.contains(borough);

  // Location helpers
  String get shortLocationName {
    if (locationName == null) return borough;

    final name = locationName!;
    if (name.length > 30) {
      return '${name.substring(0, 27)}...';
    }
    return name;
  }
}
