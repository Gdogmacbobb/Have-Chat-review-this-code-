import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import './supabase_service.dart';

class DonationService {
  final SupabaseService _supabaseService = SupabaseService();
  final Dio _dio = Dio();

  // Create donation record and initiate Stripe payment
  Future<Map<String, dynamic>?> createDonation({
    required String performerId,
    required double amount,
    String? videoId,
    String? message,
  }) async {
    try {
      final client = await _supabaseService.client;
      final userId = _supabaseService.currentUser?.id;
      
      if (userId == null) throw Exception('User not authenticated');
      if (amount <= 0) throw Exception('Donation amount must be greater than 0');

      // Create donation record
      final donationResponse = await client
          .from('donations')
          .insert({
            'donor_id': userId,
            'performer_id': performerId,
            if (videoId != null) 'video_id': videoId,
            'amount': amount,
            'currency': 'USD',
            if (message != null) 'message': message,
            'transaction_status': 'pending',
          })
          .select()
          .single();

      // Call Stripe Edge Function to create payment intent
      final paymentResponse = await _createStripePaymentIntent(
        amount: amount,
        donationId: donationResponse['id'],
      );

      // Update donation with Stripe payment intent ID
      await client
          .from('donations')
          .update({
            'stripe_payment_intent_id': paymentResponse['payment_intent_id'],
          })
          .eq('id', donationResponse['id']);

      return {
        ...donationResponse,
        'client_secret': paymentResponse['client_secret'],
      };
    } catch (error) {
      debugPrint('Create donation error: $error');
      rethrow;
    }
  }

  // Confirm donation payment
  Future<void> confirmDonationPayment(String donationId) async {
    try {
      final client = await _supabaseService.client;
      
      await client
          .from('donations')
          .update({
            'transaction_status': 'completed',
            'completed_at': DateTime.now().toIso8601String(),
          })
          .eq('id', donationId);

      // Update performer's total donations
      await _updatePerformerDonations(donationId);
      
      // Create notification for performer
      await _createDonationNotification(donationId);
    } catch (error) {
      debugPrint('Confirm donation payment error: $error');
      rethrow;
    }
  }

  // Get performer's donations
  Future<List<Map<String, dynamic>>> getPerformerDonations(
    String performerId, {
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final client = await _supabaseService.client;
      
      final response = await client
          .from('donations')
          .select('''
            *,
            donor:user_profiles!donor_id(
              username, full_name, profile_image_url
            ),
            video:videos(title, thumbnail_url)
          ''')
          .eq('performer_id', performerId)
          .eq('transaction_status', 'completed')
          .order('completed_at', ascending: false)
          .range(offset, offset + limit - 1);

      return List<Map<String, dynamic>>.from(response);
    } catch (error) {
      debugPrint('Get performer donations error: $error');
      return [];
    }
  }

  // Get user's donation history
  Future<List<Map<String, dynamic>>> getUserDonations(
    String userId, {
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final client = await _supabaseService.client;
      
      final response = await client
          .from('donations')
          .select('''
            *,
            performer:user_profiles!performer_id(
              username, full_name, profile_image_url, performance_type
            ),
            video:videos(title, thumbnail_url)
          ''')
          .eq('donor_id', userId)
          .inFilter('transaction_status', ['completed', 'pending'])
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return List<Map<String, dynamic>>.from(response);
    } catch (error) {
      debugPrint('Get user donations error: $error');
      return [];
    }
  }

  // Get donation statistics for performer
  Future<Map<String, dynamic>> getPerformerDonationStats(String performerId) async {
    try {
      final client = await _supabaseService.client;
      
      // Get total donations and count
      final statsResponse = await client
          .from('donations')
          .select('amount, performer_amount')
          .eq('performer_id', performerId)
          .eq('transaction_status', 'completed');

      double totalReceived = 0;
      double totalEarned = 0;
      int donationCount = statsResponse.length;

      for (final donation in statsResponse) {
        totalReceived += (donation['amount'] as num).toDouble();
        totalEarned += (donation['performer_amount'] as num).toDouble();
      }

      // Get recent donors count (last 30 days)
      final recentDonorsResponse = await client
          .from('donations')
          .select('donor_id')
          .eq('performer_id', performerId)
          .eq('transaction_status', 'completed')
          .gte('completed_at', DateTime.now().subtract(const Duration(days: 30)).toIso8601String());

      final uniqueDonors = <String>{};
      for (final donation in recentDonorsResponse) {
        uniqueDonors.add(donation['donor_id'] as String);
      }

      return {
        'total_received': totalReceived,
        'total_earned': totalEarned,
        'total_donations': donationCount,
        'recent_donors_count': uniqueDonors.length,
        'platform_fee_rate': 0.05,
      };
    } catch (error) {
      debugPrint('Get performer donation stats error: $error');
      return {
        'total_received': 0.0,
        'total_earned': 0.0,
        'total_donations': 0,
        'recent_donors_count': 0,
        'platform_fee_rate': 0.05,
      };
    }
  }

  // Call Stripe Edge Function to create payment intent
  Future<Map<String, dynamic>> _createStripePaymentIntent({
    required double amount,
    required String donationId,
  }) async {
    try {
      const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
      const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
      final edgeFunctionUrl = '$supabaseUrl/functions/v1/create-payment-intent';
      
      final response = await _dio.post(
        edgeFunctionUrl,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $anonKey',
          },
        ),
        data: {
          'amount': (amount * 100).round(), // Stripe expects cents
          'currency': 'usd',
          'donation_id': donationId,
        },
      );

      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception('Failed to create payment intent: ${response.statusMessage}');
      }
    } catch (error) {
      debugPrint('Create Stripe payment intent error: $error');
      rethrow;
    }
  }

  // Update performer's total donations
  Future<void> _updatePerformerDonations(String donationId) async {
    try {
      final client = await _supabaseService.client;
      
      // Get donation details
      final donation = await client
          .from('donations')
          .select('performer_id, performer_amount')
          .eq('id', donationId)
          .single();

      // Update performer's total donations
      await client.rpc('increment_performer_donations', params: {
        'performer_id': donation['performer_id'],
        'amount': donation['performer_amount'],
      });
    } catch (error) {
      debugPrint('Update performer donations error: $error');
    }
  }

  // Create notification for donation
  Future<void> _createDonationNotification(String donationId) async {
    try {
      final client = await _supabaseService.client;
      
      // Get donation details with donor info
      final donation = await client
          .from('donations')
          .select('''
            *,
            donor:user_profiles!donor_id(username, full_name)
          ''')
          .eq('id', donationId)
          .single();

      final donorName = donation['donor']['full_name'] ?? donation['donor']['username'];
      final amount = donation['amount'];

      await client
          .from('notifications')
          .insert({
            'user_id': donation['performer_id'],
            'type': 'donation',
            'title': 'New Donation Received!',
            'message': '$donorName just donated \$$amount to support your performances!',
            'data': {
              'donation_id': donationId,
              'donor_id': donation['donor_id'],
              'amount': amount,
            },
          });
    } catch (error) {
      debugPrint('Create donation notification error: $error');
    }
  }
}