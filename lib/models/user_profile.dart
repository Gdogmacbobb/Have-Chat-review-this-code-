enum UserRole { streetPerformer, newYorker, admin }

enum PerformanceType { singer, dancer, magician, musician, artist, other }

enum VerificationStatus { pending, approved, rejected, underReview }

class UserProfile {
  final String id;
  final String email;
  final String username;
  final String fullName;
  final UserRole role;
  final String? profileImageUrl;
  final String? bio;

  // Street Performer specific fields
  final Map<String, List<String>>? performanceTypes;
  final String? frequentPerformanceSpots;
  final Map<String, String>? socialMediaLinks;
  final VerificationStatus? verificationStatus;
  final String? verificationPhotoUrl;
  final double? totalDonationsReceived;

  // Account status
  final bool isActive;
  final bool isVerified;

  // Timestamps
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserProfile({
    required this.id,
    required this.email,
    required this.username,
    required this.fullName,
    required this.role,
    this.profileImageUrl,
    this.bio,
    this.performanceTypes,
    this.frequentPerformanceSpots,
    this.socialMediaLinks,
    this.verificationStatus,
    this.verificationPhotoUrl,
    this.totalDonationsReceived,
    this.isActive = true,
    this.isVerified = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      email: json['email'] as String,
      username: json['username'] as String,
      fullName: json['full_name'] as String,
      role: _parseUserRole(json['role'] as String?),
      profileImageUrl: json['profile_image_url'] as String?,
      bio: json['bio'] as String?,
      performanceTypes: _parsePerformanceTypes(json['performance_types']),
      frequentPerformanceSpots: json['frequent_performance_spots'] as String?,
      socialMediaLinks: json['social_media_links'] != null
          ? Map<String, String>.from(json['social_media_links'] as Map)
          : null,
      verificationStatus:
          _parseVerificationStatus(json['verification_status'] as String?),
      verificationPhotoUrl: json['verification_photo_url'] as String?,
      totalDonationsReceived: json['total_donations_received'] != null
          ? (json['total_donations_received'] as num).toDouble()
          : null,
      isActive: json['is_active'] as bool? ?? true,
      isVerified: json['is_verified'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'username': username,
      'full_name': fullName,
      'role': _userRoleToString(role),
      'profile_image_url': profileImageUrl,
      'bio': bio,
      'performance_types': performanceTypes,
      'frequent_performance_spots': frequentPerformanceSpots,
      'social_media_links': socialMediaLinks,
      'verification_status': verificationStatus != null
          ? _verificationStatusToString(verificationStatus!)
          : null,
      'verification_photo_url': verificationPhotoUrl,
      'total_donations_received': totalDonationsReceived,
      'is_active': isActive,
      'is_verified': isVerified,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  UserProfile copyWith({
    String? id,
    String? email,
    String? username,
    String? fullName,
    UserRole? role,
    String? profileImageUrl,
    String? bio,
    Map<String, List<String>>? performanceTypes,
    String? frequentPerformanceSpots,
    Map<String, String>? socialMediaLinks,
    VerificationStatus? verificationStatus,
    String? verificationPhotoUrl,
    double? totalDonationsReceived,
    bool? isActive,
    bool? isVerified,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      email: email ?? this.email,
      username: username ?? this.username,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      bio: bio ?? this.bio,
      performanceTypes: performanceTypes ?? this.performanceTypes,
      frequentPerformanceSpots:
          frequentPerformanceSpots ?? this.frequentPerformanceSpots,
      socialMediaLinks: socialMediaLinks ?? this.socialMediaLinks,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      verificationPhotoUrl: verificationPhotoUrl ?? this.verificationPhotoUrl,
      totalDonationsReceived:
          totalDonationsReceived ?? this.totalDonationsReceived,
      isActive: isActive ?? this.isActive,
      isVerified: isVerified ?? this.isVerified,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Helper methods for enum conversions
  static UserRole _parseUserRole(String? role) {
    switch (role) {
      case 'street_performer':
        return UserRole.streetPerformer;
      case 'new_yorker':
        return UserRole.newYorker;
      case 'admin':
        return UserRole.admin;
      default:
        return UserRole.newYorker;
    }
  }

  static String _userRoleToString(UserRole role) {
    switch (role) {
      case UserRole.streetPerformer:
        return 'street_performer';
      case UserRole.newYorker:
        return 'new_yorker';
      case UserRole.admin:
        return 'admin';
    }
  }

  static PerformanceType? _parsePerformanceType(String? type) {
    switch (type) {
      case 'singer':
        return PerformanceType.singer;
      case 'dancer':
        return PerformanceType.dancer;
      case 'magician':
        return PerformanceType.magician;
      case 'musician':
        return PerformanceType.musician;
      case 'artist':
        return PerformanceType.artist;
      case 'other':
        return PerformanceType.other;
      default:
        return null;
    }
  }

  static String _performanceTypeToString(PerformanceType type) {
    switch (type) {
      case PerformanceType.singer:
        return 'singer';
      case PerformanceType.dancer:
        return 'dancer';
      case PerformanceType.magician:
        return 'magician';
      case PerformanceType.musician:
        return 'musician';
      case PerformanceType.artist:
        return 'artist';
      case PerformanceType.other:
        return 'other';
    }
  }

  static VerificationStatus? _parseVerificationStatus(String? status) {
    switch (status) {
      case 'pending':
        return VerificationStatus.pending;
      case 'approved':
        return VerificationStatus.approved;
      case 'rejected':
        return VerificationStatus.rejected;
      case 'under_review':
        return VerificationStatus.underReview;
      default:
        return null;
    }
  }

  static String _verificationStatusToString(VerificationStatus status) {
    switch (status) {
      case VerificationStatus.pending:
        return 'pending';
      case VerificationStatus.approved:
        return 'approved';
      case VerificationStatus.rejected:
        return 'rejected';
      case VerificationStatus.underReview:
        return 'under_review';
    }
  }

  static Map<String, List<String>>? _parsePerformanceTypes(dynamic json) {
    if (json == null) return null;
    if (json is! Map) return null;
    
    try {
      final Map<String, List<String>> result = {};
      json.forEach((key, value) {
        if (value is List) {
          result[key.toString()] = value.map((e) => e.toString()).toList();
        }
      });
      return result.isNotEmpty ? result : null;
    } catch (e) {
      return null;
    }
  }

  // Convenience getters
  bool get isStreetPerformer => role == UserRole.streetPerformer;
  bool get isNewYorker => role == UserRole.newYorker;
  bool get isAdmin => role == UserRole.admin;
  bool get isPendingVerification =>
      verificationStatus == VerificationStatus.pending;
  bool get isApproved => verificationStatus == VerificationStatus.approved;

  String get displayName => fullName.isNotEmpty ? fullName : username;
  String get roleDisplayName {
    switch (role) {
      case UserRole.streetPerformer:
        return 'Street Performer';
      case UserRole.newYorker:
        return 'New Yorker';
      case UserRole.admin:
        return 'Admin';
    }
  }
}
