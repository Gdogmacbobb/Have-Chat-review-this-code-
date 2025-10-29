import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ynfny/utils/responsive_scale.dart';
import 'package:ynfny/widgets/primary_button.dart';

import '../../core/app_export.dart';
import './widgets/handle_input_widget.dart';
import './widgets/handle_suggestions_widget.dart';
import './widgets/handle_validation_widget.dart';

class HandleCreationScreen extends StatefulWidget {
  const HandleCreationScreen({Key? key}) : super(key: key);

  @override
  State<HandleCreationScreen> createState() => _HandleCreationScreenState();
}

class _HandleCreationScreenState extends State<HandleCreationScreen> {
  final _handleController = TextEditingController();
  final _focusNode = FocusNode();

  // Validation state
  bool _isValidating = false;
  bool _isHandleAvailable = false;
  String? _validationError;
  List<String> _suggestions = [];

  // Debounce timer for API calls
  Timer? _debounceTimer;

  // Mock existing handles for testing
  final List<String> _existingHandles = [
    'streetperformer123',
    'nyc_dancer',
    'brooklynmusic',
    'manhattan_magic',
    'queens_artist',
    'bronx_beats',
    'admin',
    'test_user',
    'performer',
    'newyorker'
  ];

  @override
  void initState() {
    super.initState();
    _handleController.addListener(_onHandleChanged);

    // Auto-focus when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_focusNode);
    });
  }

  @override
  void dispose() {
    _handleController.dispose();
    _focusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundDark,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: CustomIconWidget(
            iconName: 'arrow_back',
            color: AppTheme.textPrimary,
            size: 24,
          ),
        ),
        title: Text(
          'Create Handle',
          style: AppTheme.darkTheme.textTheme.titleLarge?.copyWith(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Text
                Text(
                  'Choose Your Unique Handle',
                  style: AppTheme.darkTheme.textTheme.headlineSmall?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 1.h),
                Text(
                  'Your handle will be visible to other users and must be unique across all account types.',
                  style: AppTheme.darkTheme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
                SizedBox(height: 4.h),

                // Handle Input
                HandleInputWidget(
                  controller: _handleController,
                  focusNode: _focusNode,
                  isValidating: _isValidating,
                  isAvailable: _isHandleAvailable,
                  error: _validationError,
                ),
                SizedBox(height: 3.h),

                // Validation Rules
                HandleValidationWidget(
                  handle: _handleController.text,
                ),
                SizedBox(height: 2.h),

                // Suggestions (only show when handle is taken)
                if (_suggestions.isNotEmpty) ...[
                  HandleSuggestionsWidget(
                    suggestions: _suggestions,
                    onSuggestionTap: (suggestion) {
                      _handleController.text = suggestion;
                      _validateHandle(suggestion);
                    },
                  ),
                  SizedBox(height: 2.h),
                ],

                // Preview
                if (_handleController.text.isNotEmpty &&
                    _isHandleAvailable) ...[
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(4.w),
                    decoration: BoxDecoration(
                      color: AppTheme.successGreen.withAlpha(26),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.successGreen.withAlpha(77),
                      ),
                    ),
                    child: Column(
                      children: [
                        CustomIconWidget(
                          iconName: 'check_circle',
                          color: AppTheme.successGreen,
                          size: 32,
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          'Your handle will be:',
                          style:
                              AppTheme.darkTheme.textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        SizedBox(height: 1.h),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '@',
                              style: AppTheme.darkTheme.textTheme.titleLarge
                                  ?.copyWith(
                                color: AppTheme.primaryOrange,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              _handleController.text,
                              style: AppTheme.darkTheme.textTheme.titleLarge
                                  ?.copyWith(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: EdgeInsets.fromLTRB(5.w, 1.h, 5.w, 2.h),
        child: PrimaryButton(
          label: 'Confirm Handle',
          onPressed: _canConfirmHandle() ? _confirmHandle : null,
          isLoading: _isValidating,
        ),
      ),
    );
  }

  void _onHandleChanged() {
    final handle = _handleController.text;

    // Cancel previous timer
    _debounceTimer?.cancel();

    // Clear previous state
    setState(() {
      _validationError = null;
      _isHandleAvailable = false;
      _suggestions.clear();
    });

    // Don't validate empty handles
    if (handle.isEmpty) return;

    // Start new timer for debounced validation
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _validateHandle(handle);
    });
  }

  Future<void> _validateHandle(String handle) async {
    if (handle.isEmpty) return;

    setState(() {
      _isValidating = true;
      _validationError = null;
      _isHandleAvailable = false;
    });

    try {
      // Simulate API delay
      await Future.delayed(const Duration(milliseconds: 800));

      // Basic validation rules
      if (handle.length < 3) {
        setState(() {
          _validationError = 'Handle must be at least 3 characters';
          _isValidating = false;
        });
        return;
      }

      if (handle.length > 20) {
        setState(() {
          _validationError = 'Handle must be 20 characters or less';
          _isValidating = false;
        });
        return;
      }

      if (!RegExp(r'^[a-zA-Z0-9._]+$').hasMatch(handle)) {
        setState(() {
          _validationError =
              'Only letters, numbers, periods, and underscores allowed';
          _isValidating = false;
        });
        return;
      }

      if (RegExp(r'[._]{2,}').hasMatch(handle)) {
        setState(() {
          _validationError = 'No consecutive periods or underscores allowed';
          _isValidating = false;
        });
        return;
      }

      // Check availability against mock data
      final isHandleTaken = _existingHandles
          .any((existing) => existing.toLowerCase() == handle.toLowerCase());

      if (mounted) {
        if (isHandleTaken) {
          setState(() {
            _validationError = 'This handle is already taken';
            _isValidating = false;
            _suggestions = _generateSuggestions(handle);
          });
        } else {
          setState(() {
            _isHandleAvailable = true;
            _isValidating = false;
            _suggestions.clear();
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _validationError = 'Unable to verify handle availability';
          _isValidating = false;
        });
      }
    }
  }

  List<String> _generateSuggestions(String handle) {
    final suggestions = <String>[];
    final baseHandle = handle.toLowerCase();

    // Add numeric variations
    for (int i = 1; i <= 3; i++) {
      final suggestion = '$baseHandle$i';
      if (!_existingHandles.contains(suggestion)) {
        suggestions.add(suggestion);
      }
    }

    // Add underscore variations
    final underscoreVariations = [
      '${baseHandle}_nyc',
      '${baseHandle}_official',
      'nyc_$baseHandle'
    ];

    for (final variation in underscoreVariations) {
      if (!_existingHandles.contains(variation) && suggestions.length < 6) {
        suggestions.add(variation);
      }
    }

    return suggestions.take(3).toList();
  }

  bool _canConfirmHandle() {
    return _handleController.text.isNotEmpty &&
        _isHandleAvailable &&
        !_isValidating &&
        _validationError == null;
  }

  void _confirmHandle() {
    if (!_canConfirmHandle()) return;

    // Haptic feedback
    HapticFeedback.lightImpact();

    // Return the selected handle to the registration screen
    Navigator.pop(context, _handleController.text);
  }
}
