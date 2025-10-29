import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:ynfny/utils/responsive_scale.dart';

import '../core/app_export.dart';
import '../presentation/performer_profile/performer_profile.dart';

class FeedNavigationBottomWidget extends StatelessWidget {
  final String currentFeed; // 'following', 'discovery', or 'for_you'
  final bool showSearch;
  final int unreadCount;
  final VoidCallback? onRefresh;

  const FeedNavigationBottomWidget({
    Key? key,
    required this.currentFeed,
    this.showSearch = true,
    this.unreadCount = 0,
    this.onRefresh,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: Color(0xFF1C1C1E),
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Search Button
            GestureDetector(
              onTap: () => _showSearchOverlay(context),
              child: Icon(
                Icons.search,
                size: 28,
                color: Colors.white,
              ),
            ),

            // Camera Button - Always orange, no glow
            GestureDetector(
              onTap: () => _navigateToCamera(context),
              child: Icon(
                Icons.camera_alt,
                size: 28,
                color: Color(0xFFFF8C00),
              ),
            ),

            // Home Button
            GestureDetector(
              onTap: () => _navigateToHome(context),
              child: Icon(
                Icons.home,
                size: 28,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToCamera(BuildContext context) {
    Navigator.pushNamed(context, AppRoutes.videoRecording);
  }

  void _navigateToHome(BuildContext context) {
    // Navigate to user's own profile page with Edit button visible
    // Passing null for performerId loads current user's profile
    debugPrint('[NAV_HOME] Navigating to current user profile');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PerformerProfile(
          performerId: null, // null = current user's profile
        ),
      ),
    );
  }

  void _showSearchOverlay(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SearchOverlayWidget(
        currentFeed: currentFeed,
      ),
    );
  }
}

class _SearchOverlayWidget extends StatefulWidget {
  final String currentFeed;

  const _SearchOverlayWidget({
    Key? key,
    required this.currentFeed,
  }) : super(key: key);

  @override
  State<_SearchOverlayWidget> createState() => _SearchOverlayWidgetState();
}

class _SearchOverlayWidgetState extends State<_SearchOverlayWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;

  final TextEditingController _searchController = TextEditingController();
  String? _selectedPerformanceType;
  String? _selectedBorough;
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;

  final List<String> _performanceTypes = [
    'Music',
    'Dance',
    'Magic',
    'Comedy',
    'Art',
    'Acrobatics',
    'Poetry',
    'Theater',
  ];

  final List<String> _boroughs = [
    'Manhattan',
    'Brooklyn',
    'Queens',
    'Bronx',
    'Staten Island',
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _animationController.forward();
    
    if (kDebugMode) {
      print('[OMEGA_UI_LOG] SearchOverlay_OptimizedPadding overlay_height:72% filter_section:32% spacing:1%');
      print('[OMEGA_VERIFY] OverlayPadding_Reduced FilterSection_32h_213px_AllFiltersVisible');
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleClose() {
    _animationController.reverse().then((_) {
      Navigator.pop(context);
    });
  }

  void _performSearch(String query) {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    // Simulate search results - In real implementation, this would call a service
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _searchResults = _getMockSearchResults(query);
          _isSearching = false;
        });
      }
    });
  }

  List<Map<String, dynamic>> _getMockSearchResults(String query) {
    // Mock search results - In real implementation, this would come from a service
    final mockResults = [
      {
        'type': 'performer',
        'name': 'Jazz Marcus',
        'username': '@jazzy_marcus',
        'avatar':
            'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150&h=150&fit=crop&crop=face',
        'performanceType': 'Music',
        'location': 'Washington Square Park',
        'isFollowing': true,
      },
      {
        'type': 'performer',
        'name': 'Brooklyn Beats',
        'username': '@brooklyn_beats',
        'avatar':
            'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=150&h=150&fit=crop&crop=face',
        'performanceType': 'Music',
        'location': 'Brooklyn Bridge',
        'isFollowing': true,
      },
      {
        'type': 'location',
        'name': 'Times Square',
        'borough': 'Manhattan',
        'activePerformers': 12,
      },
      {
        'type': 'location',
        'name': 'Central Park',
        'borough': 'Manhattan',
        'activePerformers': 8,
      },
    ];

    return mockResults
        .where((result) =>
            result['name']
                .toString()
                .toLowerCase()
                .contains(query.toLowerCase()) ||
            (result['username']
                    ?.toString()
                    .toLowerCase()
                    .contains(query.toLowerCase()) ??
                false))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value * 100.h),
          child: Container(
            width: 100.w,
            height: 72.h,
            decoration: BoxDecoration(
              color: AppTheme.surfaceDark,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.shadowDark,
                  blurRadius: 8,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // Handle indicator
                  Container(
                    width: 40,
                    height: 4,
                    margin: EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.borderSubtle,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // Header with close button
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4.w),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Search ${widget.currentFeed == 'following' ? 'Following' : 'Discovery'}',
                          style:
                              AppTheme.darkTheme.textTheme.titleLarge?.copyWith(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        GestureDetector(
                          onTap: _handleClose,
                          child: Container(
                            padding: EdgeInsets.all(2.w),
                            decoration: BoxDecoration(
                              color: AppTheme.borderSubtle,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.close,
                              color: AppTheme.textPrimary,
                              size: 5.w,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 3.h),

                  // Search bar
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4.w),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.inputBackground,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.borderSubtle,
                          width: 1,
                        ),
                      ),
                      child: TextField(
                        controller: _searchController,
                        style:
                            AppTheme.darkTheme.textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search performers, locations...',
                          hintStyle:
                              AppTheme.darkTheme.textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                          prefixIcon: Padding(
                            padding: EdgeInsets.all(3.w),
                            child: Icon(
                              Icons.search,
                              color: AppTheme.textSecondary,
                              size: 5.w,
                            ),
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 4.w,
                            vertical: 3.h,
                          ),
                        ),
                        onChanged: _performSearch,
                      ),
                    ),
                  ),

                  SizedBox(height: 3.h),

                  // Filter chips
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4.w),
                    child: SizedBox(
                      height: 32.h,
                      child: Row(
                        children: [
                          // Performance type filter
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Performance Type',
                                  style: AppTheme
                                      .darkTheme.textTheme.labelMedium
                                      ?.copyWith(
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                                SizedBox(height: 1.h),
                                Expanded(
                                  child: SingleChildScrollView(
                                    child: Wrap(
                                      spacing: 2.w,
                                      runSpacing: 1.h,
                                      children: _performanceTypes.map((type) {
                                        final isSelected =
                                            _selectedPerformanceType == type;
                                        return GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              _selectedPerformanceType =
                                                  isSelected ? null : type;
                                            });
                                          },
                                          child: Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 3.w,
                                              vertical: 1.h,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? AppTheme.primaryOrange
                                                  : AppTheme.borderSubtle,
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              type,
                                              style: AppTheme.darkTheme
                                                  .textTheme.labelSmall
                                                  ?.copyWith(
                                                color: isSelected
                                                    ? AppTheme.backgroundDark
                                                    : AppTheme.textSecondary,
                                                fontWeight: isSelected
                                                    ? FontWeight.w500
                                                    : FontWeight.w400,
                                              ),
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          SizedBox(width: 4.w),

                          // Borough filter
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Borough',
                                  style: AppTheme
                                      .darkTheme.textTheme.labelMedium
                                      ?.copyWith(
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                                SizedBox(height: 1.h),
                                Expanded(
                                  child: SingleChildScrollView(
                                    child: Column(
                                      children: _boroughs.map((borough) {
                                        final isSelected =
                                            _selectedBorough == borough;
                                        return GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              _selectedBorough =
                                                  isSelected ? null : borough;
                                            });
                                          },
                                          child: Container(
                                            width: double.infinity,
                                            margin:
                                                EdgeInsets.only(bottom: 1.h),
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 3.w,
                                              vertical: 1.h,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? AppTheme.primaryOrange
                                                  : AppTheme.borderSubtle,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              borough,
                                              style: AppTheme.darkTheme
                                                  .textTheme.labelSmall
                                                  ?.copyWith(
                                                color: isSelected
                                                    ? AppTheme.backgroundDark
                                                    : AppTheme.textSecondary,
                                                fontWeight: isSelected
                                                    ? FontWeight.w500
                                                    : FontWeight.w400,
                                              ),
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 1.h),

                  // Search results
                  Expanded(
                    child: _isSearching
                        ? Center(
                            child: CircularProgressIndicator(
                              color: AppTheme.primaryOrange,
                            ),
                          )
                        : _searchResults.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.search,
                                      size: 12.w,
                                      color: AppTheme.textSecondary,
                                    ),
                                    SizedBox(height: 2.h),
                                    Text(
                                      _searchController.text.isEmpty
                                          ? 'Start typing to search...'
                                          : 'No results found',
                                      style: AppTheme
                                          .darkTheme.textTheme.bodyLarge
                                          ?.copyWith(
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: EdgeInsets.symmetric(horizontal: 4.w),
                                itemCount: _searchResults.length,
                                itemBuilder: (context, index) {
                                  final result = _searchResults[index];
                                  return _SearchResultTile(
                                    result: result,
                                    onTap: () => _handleResultTap(result),
                                  );
                                },
                              ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _handleResultTap(Map<String, dynamic> result) {
    if (result['type'] == 'performer') {
      Navigator.pop(context);
      Navigator.pushNamed(
        context,
        AppRoutes.performerProfile,
        arguments: result['username'],
      );
    } else if (result['type'] == 'location') {
      // Handle location tap - could navigate to discovery feed with location filter
      Navigator.pop(context);
      Navigator.pushNamed(context, AppRoutes.discoveryFeed);
    }
  }
}

class _SearchResultTile extends StatelessWidget {
  final Map<String, dynamic> result;
  final VoidCallback onTap;

  const _SearchResultTile({
    Key? key,
    required this.result,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: 2.h),
        padding: EdgeInsets.all(3.w),
        decoration: BoxDecoration(
          color: AppTheme.inputBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.borderSubtle,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Avatar or icon
            Container(
              width: 12.w,
              height: 12.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.borderSubtle,
              ),
              child: result['type'] == 'performer'
                  ? ClipOval(
                      child: Image.network(
                        result['avatar'] ?? '',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.person,
                            color: AppTheme.textSecondary,
                            size: 6.w,
                          );
                        },
                      ),
                    )
                  : Icon(
                      Icons.location_on,
                      color: AppTheme.primaryOrange,
                      size: 6.w,
                    ),
            ),

            SizedBox(width: 3.w),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result['name'] ?? '',
                    style: AppTheme.darkTheme.textTheme.titleSmall?.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (result['username'] != null) ...[
                    SizedBox(height: 0.5.h),
                    Text(
                      result['username'],
                      style: AppTheme.darkTheme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                  if (result['performanceType'] != null ||
                      result['location'] != null) ...[
                    SizedBox(height: 0.5.h),
                    Text(
                      result['performanceType'] != null
                          ? '${result['performanceType']} • ${result['location']}'
                          : '${result['borough']} • ${result['activePerformers']} active',
                      style: AppTheme.darkTheme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Action indicator
            Icon(
              Icons.arrow_forward_ios,
              color: AppTheme.textSecondary,
              size: 4.w,
            ),
          ],
        ),
      ),
    );
  }
}
