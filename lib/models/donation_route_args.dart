class DonationRouteArgs {
  final String videoId;
  final String performerId;

  const DonationRouteArgs({
    required this.videoId,
    required this.performerId,
  });

  Map<String, dynamic> toMap() {
    return {
      'videoId': videoId,
      'performerId': performerId,
    };
  }

  factory DonationRouteArgs.fromMap(Map<String, dynamic> map) {
    return DonationRouteArgs(
      videoId: map['videoId'] as String,
      performerId: map['performerId'] as String,
    );
  }
}
