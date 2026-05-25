import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/models/models.dart';
import '../../core/services/firebase_services.dart';

class PaymentScreen extends StatefulWidget {
  final Property property;
  final DateTime scheduledDate;
  final String timeSlot;
  final String? notes;

  const PaymentScreen({
    super.key,
    required this.property,
    required this.scheduledDate,
    required this.timeSlot,
    this.notes,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  PaymentMethod _selectedMethod = PaymentMethod.mpesa;
  bool _isProcessing = false;
  final _mpesaController = TextEditingController();
  final _paymentService = PaymentService();
  final _bookingService = BookingService();

  // STK Push polling
  Timer? _pollTimer;
  String? _checkoutRequestId;
  int _pollCount = 0;
  static const int _maxPolls = 12; // 60 seconds total

  // Payment state
  _PaymentState _paymentState = _PaymentState.idle;

  static const double _viewingFee = 999.0;
  static const double _total = _viewingFee;

  @override
  void dispose() {
    _mpesaController.dispose();
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Show STK Push waiting UI
    if (_paymentState == _PaymentState.waitingForMpesa) {
      return _MpesaWaitingScreen(
        onCancel: _cancelPayment,
        phone: _mpesaController.text,
        pollCount: _pollCount,
        maxPolls: _maxPolls,
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Secure Payment'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildOrderSummary(),
            const SizedBox(height: 24),
            Text('Payment Method',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            _buildMpesaMethod(),
            const SizedBox(height: 10),
            _buildCardMethod(),
            const SizedBox(height: 24),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _selectedMethod == PaymentMethod.mpesa
                  ? _buildMpesaForm()
                  : _buildCardForm(),
            ),
            const SizedBox(height: 16),
            _buildSecurityNote(),
            const SizedBox(height: 24),
            _buildPayButton(),
            const SizedBox(height: 12),
            _buildRefundNote(),
          ],
        ),
      ),
    );
  }

  // ── Order Summary ────────────────────────────────────────────────────────

  Widget _buildOrderSummary() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        border: Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Booking Summary',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),

          // Property info
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                child: Image.network(
                  widget.property.imageUrls.isNotEmpty
                      ? widget.property.imageUrls.first
                      : 'https://images.unsplash.com/photo-1564013799919-ab600027ffc6?w=200',
                  width: 72,
                  height: 72,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 72,
                    height: 72,
                    color: AppTheme.surfaceVariant,
                    child: const Icon(Icons.home_outlined,
                        color: AppTheme.textTertiary),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.property.title,
                      style: Theme.of(context).textTheme.titleLarge,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.property.location.neighborhood ??
                          widget.property.location.city,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const Divider(height: 24),

          // Viewing details
          _SummaryRow(
            label: 'Viewing Date',
            value: _formatDate(widget.scheduledDate),
          ),
          _SummaryRow(
            label: 'Time',
            value: widget.timeSlot,
          ),

          const Divider(height: 20),

          _SummaryRow(label: 'Viewing Fee', value: 'KES 999'),
          const Divider(height: 16),
          _SummaryRow(
            label: 'Total',
            value: 'KES 999',
            isTotal: true,
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  // ── Payment Method Cards ─────────────────────────────────────────────────

  Widget _buildMpesaMethod() {
    return _PaymentMethodCard(
      isSelected: _selectedMethod == PaymentMethod.mpesa,
      onTap: () => setState(() => _selectedMethod = PaymentMethod.mpesa),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF00A651).withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusSM),
            ),
            child: const Center(
              child: Text(
                'M',
                style: TextStyle(
                  color: Color(0xFF00A651),
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('M-Pesa', style: Theme.of(context).textTheme.titleLarge),
              Text('Pay via M-Pesa STK Push',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          const Spacer(),
          if (_selectedMethod == PaymentMethod.mpesa)
            const Icon(Icons.check_circle, color: AppTheme.primary, size: 22),
        ],
      ),
    );
  }

  Widget _buildCardMethod() {
    return _PaymentMethodCard(
      isSelected: _selectedMethod == PaymentMethod.card,
      onTap: () => setState(() => _selectedMethod = PaymentMethod.card),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF6772E5).withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusSM),
            ),
            child: const Icon(Icons.credit_card,
                color: Color(0xFF6772E5), size: 22),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Card Payment',
                  style: Theme.of(context).textTheme.titleLarge),
              Text('Visa, Mastercard, AMEX',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          const Spacer(),
          if (_selectedMethod == PaymentMethod.card)
            const Icon(Icons.check_circle, color: AppTheme.primary, size: 22),
        ],
      ),
    );
  }

  // ── Payment Forms ────────────────────────────────────────────────────────

  Widget _buildMpesaForm() {
    return Column(
      key: const ValueKey('mpesa'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('M-Pesa Details',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        TextField(
          controller: _mpesaController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'M-Pesa Phone Number',
            hintText: '0712345678 or 254712345678',
            prefixIcon: Icon(Icons.phone_outlined),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.accentSurface,
            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, size: 16, color: AppTheme.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'You\'ll receive a push notification on your phone. Enter your M-Pesa PIN to complete the payment.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppTheme.accent),
                ),
              ),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(duration: 200.ms);
  }

  Widget _buildCardForm() {
    return Column(
      key: const ValueKey('card'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Card Details',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        // In production: use CardField from flutter_stripe package
        // CardField(onCardChanged: (card) { ... })
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppTheme.surfaceVariant,
            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            border: Border.all(color: AppTheme.border, width: 1),
          ),
          child: Row(
            children: [
              const Icon(Icons.credit_card,
                  color: AppTheme.textSecondary, size: 20),
              const SizedBox(width: 12),
              Text(
                'Stripe CardField widget renders here',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textTertiary,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Wire up: flutter_stripe CardField → createStripePaymentIntent Cloud Function → confirmPayment',
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: AppTheme.textTertiary),
        ),
      ],
    ).animate().fadeIn(duration: 200.ms);
  }

  // ── Supporting Widgets ───────────────────────────────────────────────────

  Widget _buildSecurityNote() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.lock_outline, size: 14, color: AppTheme.textTertiary),
        const SizedBox(width: 6),
        Text(
          'Secured by 256-bit SSL encryption',
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    );
  }

  Widget _buildRefundNote() {
    return Center(
      child: Text(
        '⚠ Viewing fee is non-refundable once payment is confirmed.',
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: AppTheme.textTertiary),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildPayButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isProcessing ? null : _processPayment,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: AppTheme.primary,
        ),
        child: _isProcessing
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : Text(
                _selectedMethod == PaymentMethod.mpesa
                    ? 'Pay KES 999 via M-Pesa'
                    : 'Pay KES 999 by Card',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }

  // ── Payment Logic ────────────────────────────────────────────────────────

  Future<void> _processPayment() async {
    setState(() => _isProcessing = true);
    try {
      if (_selectedMethod == PaymentMethod.mpesa) {
        await _processMpesaPayment();
      } else {
        await _processStripePayment();
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment failed: $e')),
        );
      }
    }
  }

  Future<void> _processMpesaPayment() async {
    final raw = _mpesaController.text.trim();
    if (raw.isEmpty) {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your M-Pesa phone number')),
      );
      return;
    }

    // Normalise: 07xxxxxxxx → 2547xxxxxxxx
    final phone = _normaliseMpesaNumber(raw);
    if (phone == null) {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Invalid phone number. Use format 0712345678 or 254712345678')),
      );
      return;
    }

    // Trigger STK Push via Cloud Function
    final result = await _paymentService.initiateMpesaPayment(
      phone: phone,
      amount: _total,
      propertyId: widget.property.id,
      bookingId: 'pending', // real bookingId created after payment success
    );

    setState(() => _isProcessing = false);

    if (result['success'] == true) {
      _checkoutRequestId = result['checkoutRequestId'] as String?;
      setState(() => _paymentState = _PaymentState.waitingForMpesa);
      _startPolling();
    } else {
      final msg = result['errorMessage'] ?? 'STK Push failed. Try again.';
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg.toString())));
      }
    }
  }

  // ── STK Push Polling ─────────────────────────────────────────────────────

  void _startPolling() {
    _pollCount = 0;
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (_checkoutRequestId == null) {
        _pollTimer?.cancel();
        return;
      }

      _pollCount++;
      if (mounted) setState(() {});

      try {
        final status = await _paymentService.checkMpesaPaymentStatus(
          checkoutRequestId: _checkoutRequestId!,
        );

        if (status['status'] == 'completed') {
          _pollTimer?.cancel();
          await _onPaymentSuccess(
            paymentReference: status['mpesaReceiptNumber'] as String? ?? '',
          );
        } else if (status['status'] == 'failed') {
          _pollTimer?.cancel();
          final desc = status['resultDesc'] ?? 'Payment was cancelled or failed.';
          _onPaymentFailed(desc.toString());
        } else if (_pollCount >= _maxPolls) {
          _pollTimer?.cancel();
          _onPaymentFailed(
              'Payment timed out. Please check your M-Pesa messages and try again.');
        }
      } catch (_) {
        // Network hiccup — keep polling
      }
    });
  }

  void _cancelPayment() {
    _pollTimer?.cancel();
    setState(() {
      _paymentState = _PaymentState.idle;
      _isProcessing = false;
      _checkoutRequestId = null;
      _pollCount = 0;
    });
  }

  void _onPaymentFailed(String message) {
    if (!mounted) return;
    setState(() => _paymentState = _PaymentState.idle);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  // ── Post-payment: create booking ─────────────────────────────────────────

  Future<void> _onPaymentSuccess({required String paymentReference}) async {
    if (!mounted) return;
    setState(() => _paymentState = _PaymentState.creatingBooking);

    try {
      final booking = Booking(
        id: '',
        propertyId: widget.property.id,
        propertyTitle: widget.property.title,
        propertyImage: widget.property.imageUrls.isNotEmpty
            ? widget.property.imageUrls.first
            : '',
        userId: '', // filled by BookingService from FirebaseAuth.currentUser
        userFullName: '',
        agentId: widget.property.agentId,
        type: BookingType.viewing,
        status: BookingStatus.pending,
        scheduledDate: widget.scheduledDate,
        timeSlot: widget.timeSlot,
        notes: widget.notes,
        paymentReference: paymentReference,
        paymentStatus: PaymentStatus.paid,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _bookingService.createBooking(booking);

      if (mounted) {
        setState(() => _paymentState = _PaymentState.idle);
        _showSuccessDialog();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _paymentState = _PaymentState.idle);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Payment received but booking failed. Please contact support. Ref: $paymentReference')),
        );
      }
    }
  }

  Future<void> _processStripePayment() async {
    // TODO: wire up flutter_stripe
    // 1. Call createStripePaymentIntent Cloud Function
    // 2. Use Stripe.instance.initPaymentSheet(...)
    // 3. await Stripe.instance.presentPaymentSheet()
    // 4. On success, call _onPaymentSuccess(paymentReference: paymentIntentId)
    await Future.delayed(const Duration(seconds: 2));
    setState(() => _isProcessing = false);
    _showSuccessDialog();
  }

  // ── Success Dialog ───────────────────────────────────────────────────────

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        ),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: AppTheme.successSurface,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 36,
                  color: AppTheme.success,
                ),
              ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),
              const SizedBox(height: 20),
              Text(
                'Booking Confirmed!',
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Your viewing has been scheduled for ${_formatDate(widget.scheduledDate)} at ${widget.timeSlot}. The agent will confirm shortly.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    context.go('/home');
                  },
                  child: const Text('Back to Home'),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.push('/bookings');
                },
                child: const Text('View My Bookings'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  String? _normaliseMpesaNumber(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('254') && digits.length == 12) return digits;
    if (digits.startsWith('0') && digits.length == 10) {
      return '254${digits.substring(1)}';
    }
    if (digits.startsWith('7') && digits.length == 9) return '254$digits';
    return null;
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

// ─── M-Pesa Waiting Screen ────────────────────────────────────────────────────

class _MpesaWaitingScreen extends StatelessWidget {
  final VoidCallback onCancel;
  final String phone;
  final int pollCount;
  final int maxPolls;

  const _MpesaWaitingScreen({
    required this.onCancel,
    required this.phone,
    required this.pollCount,
    required this.maxPolls,
  });

  @override
  Widget build(BuildContext context) {
    final secondsRemaining = (maxPolls - pollCount) * 5;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),

              // Animated M-Pesa logo area
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: const Color(0xFF00A651).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text(
                    'M',
                    style: TextStyle(
                      color: Color(0xFF00A651),
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              )
                  .animate(onPlay: (c) => c.repeat())
                  .scaleXY(begin: 1.0, end: 1.08, duration: 800.ms)
                  .then()
                  .scaleXY(begin: 1.08, end: 1.0, duration: 800.ms),

              const SizedBox(height: 32),

              Text(
                'Check Your Phone',
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'An M-Pesa STK Push has been sent to\n$phone',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Enter your M-Pesa PIN to pay KES 999',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              // Progress indicator
              LinearProgressIndicator(
                value: pollCount / maxPolls,
                backgroundColor: AppTheme.border,
                color: const Color(0xFF00A651),
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 8),
              Text(
                'Waiting for confirmation... ${secondsRemaining}s',
                style: Theme.of(context).textTheme.labelSmall,
              ),

              const SizedBox(height: 32),

              // Steps
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                  border: Border.all(color: AppTheme.border, width: 0.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StepRow(number: '1', text: 'Check your phone for the M-Pesa prompt'),
                    const SizedBox(height: 8),
                    _StepRow(number: '2', text: 'Enter your M-Pesa PIN'),
                    const SizedBox(height: 8),
                    _StepRow(number: '3', text: 'Wait for confirmation below'),
                  ],
                ),
              ),

              const Spacer(),

              TextButton(
                onPressed: onCancel,
                child: const Text(
                  'Cancel Payment',
                  style: TextStyle(color: AppTheme.error),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final String number;
  final String text;

  const _StepRow({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: const BoxDecoration(
            color: Color(0xFF00A651),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
    );
  }
}

// ─── Payment State Enum ───────────────────────────────────────────────────────

enum _PaymentState { idle, waitingForMpesa, creatingBooking }

// ─── Reusable Widgets ─────────────────────────────────────────────────────────

class _PaymentMethodCard extends StatelessWidget {
  final bool isSelected;
  final VoidCallback onTap;
  final Widget child;

  const _PaymentMethodCard({
    required this.isSelected,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusLG),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.border,
            width: isSelected ? 1.5 : 0.5,
          ),
        ),
        child: child,
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isTotal;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.isTotal = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: isTotal
                ? Theme.of(context).textTheme.titleLarge
                : Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppTheme.textSecondary),
          ),
          Text(
            value,
            style: isTotal
                ? Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(color: AppTheme.primary)
                : Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}