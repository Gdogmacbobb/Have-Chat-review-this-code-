import 'package:flutter/material.dart';
import '../presentation/discovery_feed/discovery_feed.dart';
import '../presentation/following_feed/following_feed.dart';
// Removed UserProfile import - Profile tab now always uses PerformerProfile for all users
import '../presentation/performer_profile/performer_profile.dart';
import '../presentation/video_upload/video_upload.dart';
import '../core/constants/user_roles.dart';

class MainNavigation extends StatefulWidget {
  final int initialIndex;
  final String userRole;

  const MainNavigation({
    Key? key, 
    this.initialIndex = 0,
    required this.userRole,
  }) : super(key: key);

  @override
  _MainNavigationState createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  late PageController _pageController;
  int _currentIndex = 0;
  String _userRole = 'new_yorker';

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _userRole = widget.userRole;
    _pageController = PageController(initialPage: _currentIndex);
    print('[NAV] MainNavigation initialized with role: $_userRole, index: $_currentIndex');
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    if (index == _currentIndex) return;
    
    print('[NAV] Tab tapped: $index');
    
    setState(() {
      _currentIndex = index;
    });
    _pageController.jumpToPage(index);
  }

  Widget _getPage(int index) {
    final isPerformer = UserRoles.isPerformer(_userRole);
    
    switch (index) {
      case 0:
        return DiscoveryFeed(); // Search/Discovery feed
      case 1:
        // Role-specific middle tab
        if (isPerformer) {
          return VideoUpload(); // Camera/Upload for performers
        } else {
          return FollowingFeed(); // Community for New Yorkers
        }
      case 2:
        // Profile tab always shows PerformerProfile for ALL users (both Performers and New Yorkers)
        return PerformerProfile();
      default:
        return DiscoveryFeed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF121212), // Exact dark theme color
      body: PageView.builder(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        itemCount: 3,
        itemBuilder: (context, index) => _getPage(index),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Color(0xFF121212), // Match exact dark theme
          border: Border(top: BorderSide(color: Colors.grey[800]!, width: 1.0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Container(
            height: 70,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.search, 'Search'),
                _buildNavItem(1, 
                  UserRoles.isPerformer(_userRole) ? Icons.camera_alt : Icons.groups, 
                  UserRoles.isPerformer(_userRole) ? 'Camera' : 'Community'),
                _buildNavItem(2, Icons.person, 'Profile'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isActive = _currentIndex == index;
    return GestureDetector(
      onTap: () => _onTabTapped(index),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? Color(0xFFFF8C00) : Colors.grey[400],
              size: 26,
            ),
            SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Color(0xFFFF8C00) : Colors.grey[400],
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}