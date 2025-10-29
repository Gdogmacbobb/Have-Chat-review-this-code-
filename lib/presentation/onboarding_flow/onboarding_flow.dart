import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ynfny/utils/responsive_scale.dart';

import '../../core/app_export.dart';
import './widgets/navigation_controls_widget.dart';
import './widgets/onboarding_slide_widget.dart';
import './widgets/page_indicator_widget.dart';

class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key});

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _autoAdvanceTimer;

  final List<Map<String, dynamic>> _onboardingData = [
    {
      "imageUrl":
          "https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?fm=jpg&q=60&w=3000&ixlib=rb-4.0.3",
      "title": "Discover NYC Street Culture",
      "description":
          "Experience authentic street performances across all five boroughs. Swipe through endless talent from subway musicians to breakdancers.",
    },
    {
      "imageUrl":
          "https://images.pexels.com/photos/164527/pexels-photo-164527.jpeg?auto=compress&cs=tinysrgb&w=1260&h=750&dpr=2",
      "title": "Support Local Artists",
      "description":
          "Send instant donations to performers you love. Every tip goes directly to the artist, helping NYC's creative community thrive.",
    },
    {
      "imageUrl":
          "https://cdn.pixabay.com/photo/2016/01/09/18/27/camera-1130731_1280.jpg",
      "title": "Find Performances Near You",
      "description":
          "Location-based discovery shows you what's happening in your neighborhood. Never miss amazing street art in your area.",
    },
  ];

  @override
  void initState() {
    super.initState();
    _startAutoAdvanceTimer();
  }

  @override
  void dispose() {
    _autoAdvanceTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoAdvanceTimer() {
    _autoAdvanceTimer?.cancel();
    _autoAdvanceTimer = Timer.periodic(const Duration(seconds: 8), (timer) {
      if (_currentPage < _onboardingData.length - 1) {
        _nextPage();
      } else {
        timer.cancel();
      }
    });
  }

  void _nextPage() {
    if (_currentPage < _onboardingData.length - 1) {
      HapticFeedback.lightImpact();
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _navigateToAccountSelection();
    }
  }

  void _skipOnboarding() {
    HapticFeedback.lightImpact();
    _autoAdvanceTimer?.cancel();
    _navigateToAccountSelection();
  }

  void _navigateToAccountSelection() {
    Navigator.pushReplacementNamed(context, '/account-type-selection');
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
    _startAutoAdvanceTimer();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: SafeArea(
        child: Stack(
          children: [
            // Page View
            PageView.builder(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              itemCount: _onboardingData.length,
              itemBuilder: (context, index) {
                final slideData = _onboardingData[index];
                return OnboardingSlideWidget(
                  imageUrl: slideData["imageUrl"] as String,
                  title: slideData["title"] as String,
                  description: slideData["description"] as String,
                  isLastSlide: index == _onboardingData.length - 1,
                );
              },
            ),

            // Page Indicator
            Positioned(
              bottom: 12.h,
              left: 0,
              right: 0,
              child: PageIndicatorWidget(
                currentPage: _currentPage,
                totalPages: _onboardingData.length,
              ),
            ),

            // Navigation Controls
            Positioned(
              bottom: 4.h,
              left: 0,
              right: 0,
              child: NavigationControlsWidget(
                currentPage: _currentPage,
                totalPages: _onboardingData.length,
                onSkip: _skipOnboarding,
                onNext: _nextPage,
                onGetStarted: _navigateToAccountSelection,
              ),
            ),

            // YNFNY Logo (Top Left)
            Positioned(
              top: 6.h,
              left: 6.w,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
                decoration: AppTheme.glassmorphismDecoration(
                  backgroundColor:
                      AppTheme.backgroundDark.withOpacity(0.8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CustomIconWidget(
                      iconName: 'location_city',
                      color: AppTheme.primaryOrange,
                      size: 24,
                    ),
                    SizedBox(width: 2.w),
                    Text(
                      'YNFNY',
                      style: AppTheme.darkTheme.textTheme.titleLarge?.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
