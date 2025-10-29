import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:universal_html/html.dart' as html;

class FeedRefreshService {
  static final FeedRefreshService _instance = FeedRefreshService._internal();
  factory FeedRefreshService() => _instance;
  FeedRefreshService._internal();

  final StreamController<String> _refreshController = StreamController<String>.broadcast();
  
  // Subscribe to refresh events
  Stream<String> get refreshStream => _refreshController.stream;
  
  // Trigger refresh for all feeds
  void refreshAllFeeds() {
    if (kIsWeb) {
      html.window.console.log('[FEED_REFRESH] 🔄 Triggering global feed refresh');
    }
    _refreshController.add('discovery');
    _refreshController.add('following');
    _refreshController.add('profile');
  }
  
  // Trigger refresh for specific feed
  void refreshFeed(String feedName) {
    if (kIsWeb) {
      html.window.console.log('[FEED_REFRESH_$feedName] 🔄 Triggering refresh');
    }
    _refreshController.add(feedName);
  }
  
  void dispose() {
    _refreshController.close();
  }
}
