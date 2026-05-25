import 'package:url_launcher/url_launcher.dart';

class ContactLauncher {
  /// Opens the phone dialer with the given number.
  static Future<void> call(String phone) async {
    final uri = Uri(scheme: 'tel', path: _clean(phone));
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  /// Opens WhatsApp with an optional pre-filled message.
  /// Falls back to SMS if WhatsApp is not installed.
  static Future<void> whatsapp(String phone, {String? message}) async {
    final number = _e164(phone);
    final encoded = Uri.encodeComponent(message ?? 'Hello, I found your property listing and would like to inquire further.');
    final wa = Uri.parse('https://wa.me/$number?text=$encoded');

    if (await canLaunchUrl(wa)) {
      await launchUrl(wa, mode: LaunchMode.externalApplication);
    } else {
      // Fallback to SMS
      await sms(phone, message: message);
    }
  }

  /// Opens the SMS app.
  static Future<void> sms(String phone, {String? message}) async {
    final uri = Uri(
      scheme: 'sms',
      path: _clean(phone),
      queryParameters: message != null ? {'body': message} : null,
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  /// Strips non-digit characters except leading +
  static String _clean(String phone) =>
      phone.replaceAll(RegExp(r'[^\d+]'), '');

  /// Converts 07xxxxxxxx → 2547xxxxxxxx (Kenya)
  static String _e164(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('254')) return digits;
    if (digits.startsWith('0')) return '254${digits.substring(1)}';
    if (digits.startsWith('7') && digits.length == 9) return '254$digits';
    return digits;
  }
}