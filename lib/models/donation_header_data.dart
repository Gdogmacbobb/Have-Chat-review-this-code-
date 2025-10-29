class DonationHeaderData {
  final String performerId;
  final String displayName;
  final String handle;
  final String? avatarUrl;
  final String? location;
  final String videoId;
  final String? videoTitle;
  final String? thumbnailUrl;

  const DonationHeaderData({
    required this.performerId,
    required this.displayName,
    required this.handle,
    this.avatarUrl,
    this.location,
    required this.videoId,
    this.videoTitle,
    this.thumbnailUrl,
  });

  factory DonationHeaderData.fromJson(Map<String, dynamic> json) {
    return DonationHeaderData(
      performerId: json['performerId'] as String,
      displayName: json['displayName'] as String,
      handle: json['handle'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      location: json['location'] as String?,
      videoId: json['videoId'] as String,
      videoTitle: json['videoTitle'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'performerId': performerId,
      'displayName': displayName,
      'handle': handle,
      'avatarUrl': avatarUrl,
      'location': location,
      'videoId': videoId,
      'videoTitle': videoTitle,
      'thumbnailUrl': thumbnailUrl,
    };
  }
}
