import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_export.dart';
import '../../data/repos/donation_repo.dart';
import '../../models/donation_header_data.dart';
import '../../models/donation_route_args.dart';
import './widgets/amount_selection_widget.dart';
import './widgets/donation_success_widget.dart';
import './widgets/message_input_widget.dart';
import './widgets/omega_debug_panel.dart';
import './widgets/payment_method_widget.dart';
import './widgets/performer_info_widget.dart';
import './widgets/transaction_summary_widget.dart';

class DonationFlow extends StatefulWidget {
  const DonationFlow({Key? key}) : super(key: key);

  @override
  State<DonationFlow> createState() => _DonationFlowState();
}

class _DonationFlowState extends State<DonationFlow> {
  double _selectedAmount = 0.0;
  String _selectedPaymentMethod = '';
  String _donationMessage = '';
  bool _isNonRefundableAccepted = false;
  bool _isProcessing = false;
  bool _showSuccess = false;
  String _transactionId = '';

  // Live performer data
  DonationHeaderData? _headerData;
  bool _isLoadingHeader = true;
  String? _headerError;
  final DonationRepo _donationRepo = DonationRepo();

  // OMEGA Debug Panel
  bool _showDebugPanel = false;
  String? _debugVideoId;
  String? _debugPerformerId;

  double get _platformFee => _selectedAmount * 0.05;
  double get _netAmount => _selectedAmount - _platformFee;

  bool get _canProceed =>
      _selectedAmount > 0 &&
      _selectedPaymentMethod.isNotEmpty &&
      _isNonRefundableAccepted;

  @override
  void initState() {
    super.initState();
    // Set default payment method
    _selectedPaymentMethod = 'apple_pay';
    
    // Fetch performer and video data from route arguments
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadHeaderData();
    });
  }

  Future<void> _loadHeaderData() async {
    try {
      // Get route arguments (currently passed as Map from discovery_feed)
      final rawArgs = ModalRoute.of(context)?.settings.arguments;
      
      if (rawArgs == null) {
        print('[DONATION_BINDING] ERROR: No route arguments provided');
        setState(() {
          _headerError = 'Missing donation context';
          _isLoadingHeader = false;
        });
        return;
      }

      // Handle both Map and DonationRouteArgs types for compatibility
      String? videoId;
      String? performerId;

      if (rawArgs is Map<String, dynamic>) {
        videoId = rawArgs['videoId'] as String?;
        performerId = rawArgs['performerId'] as String?;
      } else if (rawArgs is DonationRouteArgs) {
        videoId = rawArgs.videoId;
        performerId = rawArgs.performerId;
      } else {
        print('[DONATION_BINDING] ERROR: Unknown argument type: ${rawArgs.runtimeType}');
        setState(() {
          _headerError = 'Invalid donation context';
          _isLoadingHeader = false;
        });
        return;
      }

      print('[DONATION_BINDING] Route args received: videoId=$videoId, performerId=$performerId');
      print('[OMEGA] navigate with videoId=$videoId, performerId=$performerId');

      // Store for debug panel
      setState(() {
        _debugVideoId = videoId;
        _debugPerformerId = performerId;
      });

      if (videoId == null || performerId == null || videoId.isEmpty || performerId.isEmpty) {
        setState(() {
          _headerError = 'Invalid donation context';
          _isLoadingHeader = false;
        });
        return;
      }

      // Fetch header data from repository
      final headerData = await _donationRepo.fetchHeaderData(
        videoId: videoId,
        performerId: performerId,
      );

      if (mounted) {
        setState(() {
          _headerData = headerData;
          _isLoadingHeader = false;
          _headerError = null;
        });
      }
    } catch (e) {
      print('[DONATION_BINDING] ERROR loading header data: $e');
      if (mounted) {
        setState(() {
          _headerError = 'Failed to load performer information';
          _isLoadingHeader = false;
        });
      }
    }
  }

  void _onAmountSelected(double amount) {
    setState(() {
      _selectedAmount = amount;
    });
  }

  void _onPaymentMethodSelected(String methodId) {
    setState(() {
      _selectedPaymentMethod = methodId;
    });
  }

  void _onMessageChanged(String message) {
    setState(() {
      _donationMessage = message;
    });
  }

  void _onNonRefundableChanged(bool accepted) {
    setState(() {
      _isNonRefundableAccepted = accepted;
    });
  }

  Future<void> _processDonation() async {
    if (!_canProceed) return;

    setState(() {
      _isProcessing = true;
    });

    HapticFeedback.mediumImpact();

    try {
      // Simulate Stripe payment processing
      await Future.delayed(const Duration(seconds: 2));

      // Generate mock transaction ID
      _transactionId =
          'TXN_${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

      // Simulate biometric authentication
      await _simulateBiometricAuth();

      setState(() {
        _showSuccess = true;
        _isProcessing = false;
      });

      HapticFeedback.heavyImpact();
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });

      _showErrorDialog(
          'Payment failed. Please try again or use a different payment method.');
    }
  }

  Future<void> _simulateBiometricAuth() async {
    // Simulate Face ID / Touch ID / Fingerprint authentication
    await Future.delayed(const Duration(milliseconds: 800));
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: Text(
          'Payment Error',
          style: AppTheme.darkTheme.textTheme.titleLarge?.copyWith(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          message,
          style: AppTheme.darkTheme.textTheme.bodyMedium?.copyWith(
            color: AppTheme.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  void _shareSuccess() {
    // Simulate sharing to social media
    HapticFeedback.lightImpact();

    final performerName = _headerData?.displayName ?? 'this performer';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Shared your support for $performerName!'),
        backgroundColor: AppTheme.successGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _closeFlow() {
    Navigator.pop(context);
  }

  void _toggleDebugPanel() {
    setState(() {
      _showDebugPanel = !_showDebugPanel;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: Stack(
        children: [
          SafeArea(
            child: _showSuccess ? _buildSuccessView() : _buildDonationForm(),
          ),
          // OMEGA Debug Panel Overlay
          if (_showDebugPanel)
            OmegaDebugPanel(
              videoId: _debugVideoId,
              performerId: _debugPerformerId,
              headerData: _headerData,
              error: _headerError,
              onClose: _toggleDebugPanel,
            ),
        ],
      ),
    );
  }

  Widget _buildSuccessView() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _closeFlow,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceDark,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: CustomIconWidget(
                      iconName: 'close',
                      color: AppTheme.textPrimary,
                      size: 20,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Donation Complete',
                    style: AppTheme.darkTheme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 48), // Balance the close button
              ],
            ),
          ),

          const SizedBox(height: 16),

          DonationSuccessWidget(
            donationAmount: _selectedAmount,
            performerName: _headerData?.displayName ?? 'Performer',
            transactionId: _transactionId,
            onClose: _closeFlow,
            onShareSuccess: _shareSuccess,
          ),
        ],
      ),
    );
  }

  Widget _buildDonationForm() {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceDark,
            boxShadow: [
              BoxShadow(
                color: AppTheme.shadowDark,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.inputBackground,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: CustomIconWidget(
                    iconName: 'arrow_back',
                    color: AppTheme.textPrimary,
                    size: 20,
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onLongPress: _toggleDebugPanel,
                  child: Text(
                    'Support Performer',
                    style: AppTheme.darkTheme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(width: 48), // Balance the back button
            ],
          ),
        ),

        // Form Content
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 16),

                // Performer Info
                _buildPerformerInfo(),

                // Amount Selection
                AmountSelectionWidget(
                  onAmountSelected: _onAmountSelected,
                  selectedAmount: _selectedAmount,
                ),

                // Payment Method
                PaymentMethodWidget(
                  onPaymentMethodSelected: _onPaymentMethodSelected,
                  selectedPaymentMethod: _selectedPaymentMethod,
                ),

                // Message Input
                MessageInputWidget(
                  onMessageChanged: _onMessageChanged,
                  message: _donationMessage,
                ),

                // Transaction Summary
                if (_selectedAmount > 0)
                  TransactionSummaryWidget(
                    donationAmount: _selectedAmount,
                    platformFee: _platformFee,
                    netAmount: _netAmount,
                    isNonRefundableAccepted: _isNonRefundableAccepted,
                    onNonRefundableChanged: _onNonRefundableChanged,
                  ),

                const SizedBox(height: 96),
              ],
            ),
          ),
        ),

        // Donate Button (Sticky CTA)
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceDark,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 12,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
            children: [
              if (_selectedAmount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryOrange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CustomIconWidget(
                        iconName: 'favorite',
                        color: AppTheme.primaryOrange,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Donating \$${_selectedAmount.toStringAsFixed(2)} to ${_headerData?.displayName ?? 'Performer'}',
                        style:
                            AppTheme.darkTheme.textTheme.bodyMedium?.copyWith(
                          color: AppTheme.primaryOrange,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              SizedBox(
                height: 56,
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed:
                      _canProceed && !_isProcessing ? _processDonation : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: _canProceed
                        ? AppTheme.primaryOrange
                        : AppTheme.borderSubtle,
                    foregroundColor: _canProceed
                        ? AppTheme.backgroundDark
                        : AppTheme.textSecondary,
                    elevation: _canProceed ? 4 : 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  icon: Icon(
                    Icons.favorite,
                    color: _canProceed
                        ? AppTheme.backgroundDark
                        : AppTheme.textSecondary,
                    size: 20,
                  ),
                  label: _isProcessing
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppTheme.backgroundDark,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Processing...',
                              style: AppTheme.darkTheme.textTheme.titleMedium
                                  ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppTheme.backgroundDark,
                              ),
                            ),
                          ],
                        )
                      : Text(
                          _selectedAmount > 0
                              ? 'Donate \$${_selectedAmount.toStringAsFixed(2)}'
                              : 'Select Amount to Donate',
                          style: AppTheme.darkTheme.textTheme.titleMedium
                              ?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPerformerInfo() {
    // Show loading state
    if (_isLoadingHeader) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            // Skeleton avatar
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.surfaceDark,
              ),
            ),
            const SizedBox(width: 12),
            // Skeleton text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 16,
                    width: 150,
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceDark,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 14,
                    width: 100,
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceDark,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
            // Skeleton thumbnail
            Container(
              width: 72,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: AppTheme.surfaceDark,
              ),
            ),
          ],
        ),
      );
    }

    // Show error state
    if (_headerError != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Text(
            _headerError!,
            style: AppTheme.darkTheme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.accentRed,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // Show live data
    if (_headerData != null) {
      return PerformerInfoWidget(
        performerData: {
          'name': _headerData!.displayName,
          'performanceType': '@${_headerData!.handle}',
          'location': _headerData!.location ?? '',
          'avatar': _headerData!.avatarUrl ?? 'https://cdn.pixabay.com/photo/2015/03/04/22/35/avatar-659652_640.png',
          'recentPerformance': _headerData!.thumbnailUrl ?? '',
        },
      );
    }

    // Fallback to empty state
    return const SizedBox.shrink();
  }
}
