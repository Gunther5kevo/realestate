import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/theme/app_theme.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () => _markAllRead(uid),
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: uid == null
          ? const Center(child: Text('Not logged in'))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('notifications')
                  .where('userId', isEqualTo: uid)
                  .orderBy('createdAt', descending: true)
                  .limit(50)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.notifications_none, size: 64, color: AppTheme.textTertiary),
                        const SizedBox(height: 16),
                        Text('No notifications yet', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: AppTheme.textSecondary)),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final data = docs[i].data() as Map<String, dynamic>;
                    final isRead = data['isRead'] == true;
                    final type = data['type'] as String? ?? '';
                    return InkWell(
                      onTap: () {
                        docs[i].reference.update({'isRead': true});
                      },
                      child: Container(
                        color: isRead ? null : AppTheme.primarySurface.withOpacity(0.4),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: _typeColor(type).withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(_typeIcon(type), size: 18, color: _typeColor(type)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(data['title'] ?? '', style: Theme.of(context).textTheme.titleMedium),
                                  const SizedBox(height: 2),
                                  Text(data['body'] ?? '', style: Theme.of(context).textTheme.bodySmall),
                                ],
                              ),
                            ),
                            if (!isRead)
                              Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle)),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'new_booking': return Icons.calendar_today_outlined;
      case 'booking_update': return Icons.update_outlined;
      case 'payment_confirmed': return Icons.check_circle_outline;
      case 'new_listing': return Icons.home_outlined;
      default: return Icons.notifications_outlined;
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'payment_confirmed': return AppTheme.success;
      case 'booking_update': return AppTheme.warning;
      case 'new_listing': return AppTheme.primary;
      default: return AppTheme.accent;
    }
  }

  void _markAllRead(String? uid) {
    if (uid == null) return;
    FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: uid)
        .where('isRead', isEqualTo: false)
        .get()
        .then((snap) {
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snap.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      batch.commit();
    });
  }
}