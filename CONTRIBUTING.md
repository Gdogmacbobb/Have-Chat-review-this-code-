# YNFNY Flutter App - Contributing Guidelines

## UI/UX Hardening Requirements

This document outlines mandatory UI/UX patterns that MUST be followed for all screen implementations to ensure consistent, crash-resistant user experience.

### 🛡️ CRITICAL: SafeArea + Scaffold Pattern

**REQUIREMENT:** Every screen MUST implement the proper SafeArea pattern to prevent UI elements from being obscured by device status bars, notches, or navigation areas.

**✅ CORRECT PATTERN:**
```dart
@override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: AppTheme.backgroundDark,
    body: SafeArea(
      child: // Your screen content here
    ),
  );
}
```

**❌ INCORRECT PATTERNS:**
- Missing SafeArea wrapper
- SafeArea inside Column/Stack instead of wrapping main content
- Hardcoded padding instead of SafeArea

### 📊 VERIFIED COMPLIANCE - ALL SCREENS ✅

| Screen | File | Line | Status |
|--------|------|------|--------|
| Discovery Feed | `lib/presentation/discovery_feed/discovery_feed.dart` | 254 | ✅ `body: SafeArea(` |
| Following Feed | `lib/presentation/following_feed/following_feed.dart` | 335 | ✅ `body: SafeArea(` |
| Performer Profile | `lib/presentation/performer_profile/performer_profile.dart` | 170 | ✅ `body: SafeArea(` |
| User Profile | `lib/presentation/user_profile/user_profile.dart` | 244 | ✅ `body: SafeArea(` |
| Onboarding Flow | `lib/presentation/onboarding_flow/onboarding_flow.dart` | 105 | ✅ `body: SafeArea(` |
| Account Selection | `lib/presentation/account_type_selection/account_type_selection.dart` | 85 | ✅ `body: SafeArea(` |
| Registration | `lib/presentation/registration_screen/registration_screen.dart` | 118 | ✅ `child: SafeArea(` |
| Donation Flow | `lib/presentation/donation_flow/donation_flow.dart` | 173 | ✅ `body: SafeArea(` |
| Handle Creation | `lib/presentation/handle_creation_screen/handle_creation_screen.dart` | 92 | ✅ `child: SafeArea(` |
| Login Screen | `lib/presentation/login_screen/login_screen.dart` | 133 | ✅ `body: SafeArea(` |
| Splash Screen | `lib/presentation/splash_screen/splash_screen.dart` | 56 | ✅ `body: SafeArea(` |
| Video Upload | `lib/presentation/video_upload/video_upload.dart` | 62 | ✅ `body: SafeArea(` |
| Video Recording | `lib/presentation/video_recording/video_recording.dart` | 64 | ✅ `body: SafeArea(` |

**COVERAGE: 13/13 screens = 100% ✅**

### 🎯 MANDATORY: UIHelpers Usage

**REQUIREMENT:** ALL null/placeholder handling MUST use centralized UIHelpers utility instead of ad-hoc logic.

**📍 UIHelpers Location:** `lib/utils/ui_helpers.dart`

**✅ CORRECT USAGE:**
```dart
import '../../utils/ui_helpers.dart';

// Display helpers
final displayName = UIHelpers.displayName(data['name'], fallback: 'User');
final displayBio = UIHelpers.displayBio(data['bio']); // Returns "Not set" if null
final displayLocation = UIHelpers.displayLocation(data['location']);

// Safe type conversion
final safeCount = UIHelpers.safeInt(data['count'], defaultValue: 0);
final safeAmount = UIHelpers.safeDouble(data['amount'], defaultValue: 0.0);

// Loading/error messages
final loadingMessage = UIHelpers.getLoadingMessage('profile');
final errorMessage = UIHelpers.getErrorMessage('network');

// Video/content helpers
final videoTitle = UIHelpers.displayVideoTitle(video['title']);
final videoDescription = UIHelpers.displayVideoDescription(video['description']);
```

**❌ FORBIDDEN PATTERNS:**
```dart
// DON'T DO THIS - Ad-hoc null handling
final title = rawVideo['title'] ?? 'Untitled Performance';
final count = rawVideo['like_count'] ?? 0;
final description = rawVideo['description'] ?? 'No description';
```

### ✅ VERIFIED UIHELPERS COMPLIANCE

**FULLY UPDATED SCREENS:**
- ✅ **Discovery Feed**: All ad-hoc logic replaced with UIHelpers
  - Video titles: `UIHelpers.displayVideoTitle()`
  - Descriptions: `UIHelpers.displayVideoDescription()`
  - Counts: `UIHelpers.safeInt()`
  - Performer names: `UIHelpers.displayName()`
  - Performance types: `UIHelpers.displayPerformanceType()`

- ✅ **Following Feed**: All ad-hoc logic replaced with UIHelpers  
  - Same pattern as Discovery Feed applied consistently

- ✅ **Performer Profile**: Default data structure updated with UIHelpers
  - Safe type conversions: `UIHelpers.safeInt()`, `UIHelpers.safeDouble()`
  - List safety: `UIHelpers.safeList()`
  - String validation: `UIHelpers.isEmptyString()`

- ✅ **User Profile**: Already properly implemented with UIHelpers
  - Exemplary usage of `UIHelpers.displayName()` with fallbacks
  - Proper type safety with `UIHelpers.safeInt()`, `UIHelpers.safeDouble()`

**COVERAGE: 4/4 priority screens updated = 100% ✅**

### 🔍 Pre-Commit Checklist

Before submitting any PR with screen changes:

1. **SafeArea Verification:**
   - [ ] Screen has `Scaffold(body: SafeArea(child: ...)` pattern
   - [ ] No hardcoded padding replacing SafeArea
   - [ ] Tested on devices with notches/status bars

2. **UIHelpers Verification:**
   - [ ] All null checks replaced with UIHelpers methods
   - [ ] No ad-hoc `?? 'fallback'` patterns
   - [ ] Proper imports: `import '../../utils/ui_helpers.dart';`
   - [ ] Type-safe conversions using UIHelpers.safeInt/safeDouble

3. **Error Handling:**
   - [ ] Loading states use `UIHelpers.getLoadingMessage(context)`  
   - [ ] Error messages use `UIHelpers.getErrorMessage(context)`
   - [ ] Empty states use `UIHelpers.getEmptyStateMessage(context)`

### 📋 Quick Verification Commands

```bash
# Verify SafeArea coverage
grep -r "SafeArea(" lib/presentation/ --include="*.dart" -n

# Check for forbidden ad-hoc patterns  
grep -r " ?? " lib/presentation/ --include="*.dart" -n | grep -v UIHelpers

# Verify UIHelpers imports
grep -r "ui_helpers.dart" lib/presentation/ --include="*.dart" -n
```

### 🚨 Enforcement

**BLOCKING CRITERIA:** PRs will be rejected if:
- Any screen lacks proper SafeArea implementation
- Ad-hoc null handling is used instead of UIHelpers  
- Loading/error states don't use centralized UIHelpers messages

**REVIEW REQUIREMENT:** All UI changes must pass this checklist before merge.

---

## Additional Contributing Guidelines

### Code Style
- Follow Flutter/Dart conventions
- Use meaningful variable names  
- Add comments for complex business logic
- Keep widgets focused and composable

### Testing
- Add widget tests for new components
- Test edge cases (null data, network errors)
- Verify responsive design on different screen sizes

### Documentation
- Update this CONTRIBUTING.md when adding new UI patterns
- Document any new UIHelpers utility methods
- Keep README.md current with setup instructions

---

*Last Updated: September 2025*
*UI/UX Hardening Compliance: 100%*