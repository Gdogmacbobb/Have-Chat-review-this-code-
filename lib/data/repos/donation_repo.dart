import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/donation_header_data.dart';

class DonationRepo {
  final _supabase = Supabase.instance.client;

  /// Fetches donation header data using OMEGA diagnostics architecture
  /// Tries RPC first, falls back to VIEW query
  Future<DonationHeaderData> fetchHeaderData({
    required String videoId,
    required String performerId,
  }) async {
    try {
      print('[OMEGA] fetchHeader start v=$videoId p=$performerId');

      // Try RPC path first (preferred)
      try {
        final rpcResult = await _supabase
            .rpc('donation_header', params: {
              '_video_id': videoId,
              '_performer_id': performerId,
            })
            .maybeSingle()
            .timeout(const Duration(seconds: 10));

        if (rpcResult != null) {
          print('[OMEGA] RPC ok: ${rpcResult['display_name']}');
          return _parseHeaderData(rpcResult, videoId, performerId);
        }

        print('[OMEGA] RPC returned null, trying VIEW fallback');
      } catch (rpcError) {
        print('[OMEGA] RPC failed: $rpcError, trying VIEW fallback');
      }

      // Fallback: query VIEW directly
      final viewResult = await _supabase
          .from('v_donation_header')
          .select()
          .eq('video_id', videoId)
          .eq('performer_id', performerId)
          .maybeSingle()
          .timeout(const Duration(seconds: 10));

      if (viewResult == null) {
        throw Exception('No data found for video $videoId and performer $performerId');
      }

      print('[OMEGA] VIEW ok: ${viewResult['display_name']}');
      return _parseHeaderData(viewResult, videoId, performerId);
    } on TimeoutException {
      print('[OMEGA] TIMEOUT after 10s');
      throw Exception('Request timed out while loading performer information');
    } catch (e, stackTrace) {
      print('[OMEGA] ERROR: $e');
      print('[OMEGA] Stack: $stackTrace');
      rethrow;
    }
  }

  /// Parse the response from RPC or VIEW into DonationHeaderData
  DonationHeaderData _parseHeaderData(
    Map<String, dynamic> data,
    String videoId,
    String performerId,
  ) {
    final displayName = data['display_name'] as String? ?? '';
    final handle = data['handle'] as String? ?? '';
    final avatarUrl = data['avatar_url'] as String?;
    final location = data['location_line'] as String?;
    final thumbnailUrl = data['thumb_any'] as String?;

    print('[OMEGA] Parsed: display=$displayName, avatar=${avatarUrl != null ? 'YES' : 'NO'}, '
        'location=${location ?? 'NONE'}, thumb=${thumbnailUrl != null ? 'YES' : 'NO'}');

    if (avatarUrl == null || avatarUrl.isEmpty) {
      print('[OMEGA] WARNING: No avatar for performer $performerId');
    }

    if (thumbnailUrl == null || thumbnailUrl.isEmpty) {
      print('[OMEGA] WARNING: No thumbnail for video $videoId');
    }

    return DonationHeaderData(
      performerId: performerId,
      displayName: displayName.isNotEmpty ? displayName : handle,
      handle: handle.replaceAll('@', ''),
      avatarUrl: avatarUrl,
      location: location,
      videoId: videoId,
      videoTitle: null, // Not included in VIEW (not needed for donation header)
      thumbnailUrl: thumbnailUrl,
    );
  }
}
