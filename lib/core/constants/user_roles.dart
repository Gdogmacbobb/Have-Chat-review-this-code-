/// User role constants and utilities for YNFNY app
class UserRoles {
  // Canonical role values stored in Supabase user metadata
  static const String performer = 'street_performer';
  static const String newYorker = 'new_yorker';
  
  // Display labels for UI
  static const String performerLabel = 'Street Performer';
  static const String newYorkerLabel = 'New Yorker';
  
  /// Check if a role string represents a performer
  static bool isPerformer(String? role) {
    if (role == null) return false;
    
    // Handle various formats that might come from different sources
    final normalizedRole = role.toLowerCase().replaceAll(' ', '_');
    return normalizedRole == 'street_performer' || 
           normalizedRole == 'performer';
  }
  
  /// Get canonical role value for storage
  static String getCanonicalRole(String displayRole) {
    if (displayRole == performerLabel || displayRole.toLowerCase().contains('performer')) {
      return performer;
    }
    return newYorker;
  }
  
  /// Get display label from canonical role
  static String getDisplayLabel(String? canonicalRole) {
    if (isPerformer(canonicalRole)) {
      return performerLabel;
    }
    return newYorkerLabel;
  }
  
  /// Safe fallback role when role is unknown or null
  static String getDefaultRole() => newYorker;
}