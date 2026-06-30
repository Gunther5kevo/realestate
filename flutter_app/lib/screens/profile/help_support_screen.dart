import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  static const _supportEmail = 'support@nestiq.app';
  static const _supportPhone = '+254700000000'; // TODO: replace with real number

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Help & Support')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Get in touch',
            style: Theme.of(context).textTheme.headlineMedium,
          ).animate().fadeIn(duration: 300.ms),
          const SizedBox(height: 12),
          _ContactTile(
            icon: Icons.support_agent,
            title: 'Live chat support',
            subtitle: 'Chat with us on WhatsApp',
            onTap: () => _launchWhatsApp(_supportPhone),
          ).animate().fadeIn(delay: 50.ms, duration: 300.ms),
          const SizedBox(height: 10),
          _ContactTile(
            icon: Icons.email_outlined,
            title: 'Email us',
            subtitle: _supportEmail,
            onTap: () => _launchEmail(_supportEmail),
          ).animate().fadeIn(delay: 100.ms, duration: 300.ms),
          const SizedBox(height: 10),
          _ContactTile(
            icon: Icons.call_outlined,
            title: 'Call us',
            subtitle: _supportPhone,
            onTap: () => _launchCall(_supportPhone),
          ).animate().fadeIn(delay: 150.ms, duration: 300.ms),

          const SizedBox(height: 32),
          Text(
            'Frequently asked questions',
            style: Theme.of(context).textTheme.headlineMedium,
          ).animate().fadeIn(delay: 200.ms, duration: 300.ms),
          const SizedBox(height: 12),
          ..._faqs.asMap().entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _FaqTile(
                    question: entry.value.question,
                    answer: entry.value.answer,
                  ).animate().fadeIn(
                        delay: Duration(milliseconds: 250 + entry.key * 50),
                        duration: const Duration(milliseconds: 300),
                      ),
                ),
              ),

          const SizedBox(height: 32),
          Center(
            child: Text(
              'NestIQ v1.0.0',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textTertiary,
                  ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  static Future<void> _launchEmail(String email) async {
    final uri = Uri(scheme: 'mailto', path: email);
    await launchUrl(uri);
  }

  static Future<void> _launchCall(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    await launchUrl(uri);
  }

  static Future<void> _launchWhatsApp(String phone) async {
    final cleaned = phone.replaceAll('+', '');
    final uri = Uri.parse('https://wa.me/$cleaned');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static const _faqs = [
    _Faq(
      question: 'How do I book a property viewing?',
      answer:
          'Open a property listing, tap "Book Viewing," choose a date and time slot, then complete payment to confirm your booking.',
    ),
    _Faq(
      question: 'What payment methods are supported?',
      answer:
          'We currently support M-Pesa and card payments (via Stripe) for viewing fees.',
    ),
    _Faq(
      question: 'Can I get a refund if I cancel a viewing?',
      answer:
          'Refund eligibility depends on how far in advance you cancel. Contact support with your booking reference for assistance.',
    ),
    _Faq(
      question: 'How do I become a verified agent?',
      answer:
          'Register a regular account first, then contact our support team to request an upgrade to agent access.',
    ),
    _Faq(
      question: 'Why was my listing not approved?',
      answer:
          'All listings are reviewed before going live to ensure quality and accuracy. If yours was rejected, check your email or contact support for details.',
    ),
  ];
}

class _Faq {
  final String question;
  final String answer;
  const _Faq({required this.question, required this.answer});
}

class _FaqTile extends StatelessWidget {
  final String question;
  final String answer;
  const _FaqTile({required this.question, required this.answer});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusLG),
          border: Border.all(color: AppTheme.border, width: 0.5),
        ),
        child: ExpansionTile(
          title: Text(
            question,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          childrenPadding:
              const EdgeInsets.fromLTRB(16, 0, 16, 16),
          expandedAlignment: Alignment.topLeft,
          children: [
            Text(
              answer,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                    height: 1.4,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ContactTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusLG),
          border: Border.all(color: AppTheme.border, width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.primarySurface,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: AppTheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                size: 20, color: AppTheme.textTertiary),
          ],
        ),
      ),
    );
  }
}