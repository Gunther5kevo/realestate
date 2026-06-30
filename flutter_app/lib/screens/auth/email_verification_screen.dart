import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/providers.dart';

class EmailVerificationScreen extends ConsumerStatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  ConsumerState<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends ConsumerState<EmailVerificationScreen>
    with WidgetsBindingObserver {
  Timer? _pollTimer;
  bool _isChecking = false;
  bool _isResending = false;
  int _resendCooldown = 0;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Poll every 4s as a fallback while the app stays in the foreground.
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) => _check());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Most users verify by leaving the app (Gmail, browser, etc.) and
    // coming back — check immediately on resume instead of waiting for
    // the next poll tick.
    if (state == AppLifecycleState.resumed) {
      _check();
    }
  }

  Future<void> _check() async {
    if (_isChecking) return;
    setState(() => _isChecking = true);
    final verified =
        await ref.read(authServiceProvider).reloadAndCheckEmailVerified();
    if (verified && mounted) {
      _pollTimer?.cancel();
      // Belt-and-suspenders: force authStateProvider to re-emit in case
      // the token-refresh broadcast hasn't landed yet by the time we
      // navigate, so the router redirect doesn't bounce us back.
      ref.invalidate(authStateProvider);
      context.go('/home');
      return;
    }
    if (mounted) setState(() => _isChecking = false);
  }

  Future<void> _resend() async {
    setState(() => _isResending = true);
    try {
      await ref.read(authServiceProvider).resendVerificationEmail();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification email sent.')),
        );
        _startCooldown();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_friendlyError(e.toString()))),
        );
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  void _startCooldown() {
    setState(() => _resendCooldown = 60);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_resendCooldown <= 1) {
        t.cancel();
        setState(() => _resendCooldown = 0);
      } else {
        setState(() => _resendCooldown--);
      }
    });
  }

  String _friendlyError(String error) {
    if (error.contains('too-many-requests')) {
      return 'Too many requests. Please wait before trying again.';
    }
    return 'Could not send email. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.read(authServiceProvider).currentUser?.email ?? '';

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
              Text(
                'NestIQ',
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      fontFamily: AppTheme.fontFamilyDisplay,
                      color: AppTheme.primary,
                    ),
              ).animate().fadeIn(duration: 400.ms),
              const Spacer(),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.primarySurface,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.mark_email_unread_outlined,
                          size: 56, color: AppTheme.primary),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Verify your email',
                      style: Theme.of(context).textTheme.headlineLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'We sent a verification link to\n$email\n'
                      'Please check your inbox and tap the link to continue.',
                      style:
                          Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    if (_isChecking)
                      const CircularProgressIndicator()
                    else
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _check,
                          child: const Text("I've verified — Check now"),
                        ),
                      ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: (_isResending || _resendCooldown > 0)
                          ? null
                          : _resend,
                      child: Text(
                        _resendCooldown > 0
                            ? 'Resend available in ${_resendCooldown}s'
                            : 'Resend verification email',
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Center(
                child: TextButton(
                  onPressed: () async {
                    await ref.read(authServiceProvider).signOut();
                    if (context.mounted) context.go('/auth/login');
                  },
                  child: const Text('Use a different account'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}