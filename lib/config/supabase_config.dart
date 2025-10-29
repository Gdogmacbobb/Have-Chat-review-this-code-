/// Single source of truth for Supabase configuration
/// 
/// This file loads Supabase credentials from environment variables for security.
/// DO NOT print the anonKey anywhere. Never log it.

class AppSupabase {
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://oemeugiejcjfbpmsftot.supabase.co',
  );
  
  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9lbWV1Z2llamNqZmJwbXNmdG90Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTc2MDg2MTAsImV4cCI6MjA3MzE4NDYxMH0.dw8T-7WVm05O9wftaTDnh1j9mUs6aSJxS_fFIHxnDR4',
  );
}