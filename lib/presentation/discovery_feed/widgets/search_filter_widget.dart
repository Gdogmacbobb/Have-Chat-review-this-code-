import 'package:flutter/material.dart';
import 'package:ynfny/utils/responsive_scale.dart';

import '../../../core/app_export.dart';

class SearchFilterWidget extends StatefulWidget {
  final Function(String)? onSearchChanged;
  final Function(String?)? onPerformanceTypeChanged;
  final Function(String?)? onBoroughChanged;
  final VoidCallback? onClose;

  const SearchFilterWidget({
    Key? key,
    this.onSearchChanged,
    this.onPerformanceTypeChanged,
    this.onBoroughChanged,
    this.onClose,
  }) : super(key: key);

  @override
  State<SearchFilterWidget> createState() => _SearchFilterWidgetState();
}

class _SearchFilterWidgetState extends State<SearchFilterWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;

  final TextEditingController _searchController = TextEditingController();
  String? _selectedPerformanceType;
  String? _selectedBorough;

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
      begin: -1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleClose() {
    _animationController.reverse().then((_) {
      widget.onClose?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value * 30.h),
          child: Container(
            width: 100.w,
            height: 30.h,
            decoration: BoxDecoration(
              color: AppTheme.surfaceDark,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.shadowDark,
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.all(4.w),
                child: Column(
                  children: [
                    // Header with close button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Search & Filter',
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
                            child: CustomIconWidget(
                              iconName: 'close',
                              color: AppTheme.textPrimary,
                              size: 5.w,
                            ),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 3.h),

                    // Search bar
                    Container(
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
                            child: CustomIconWidget(
                              iconName: 'search',
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
                        onChanged: widget.onSearchChanged,
                      ),
                    ),

                    SizedBox(height: 3.h),

                    // Filter chips
                    Expanded(
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
                                            widget.onPerformanceTypeChanged
                                                ?.call(
                                                    _selectedPerformanceType);
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
                                            widget.onBoroughChanged
                                                ?.call(_selectedBorough);
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
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
