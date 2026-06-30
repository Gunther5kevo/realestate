import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../core/models/models.dart';
import '../../core/providers/providers.dart';

class TransactionsScreen extends ConsumerWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(userTransactionsProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Transactions')),
      body: transactionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _ErrorState(
          onRetry: () => ref.invalidate(userTransactionsProvider),
        ),
        data: (transactions) {
          if (transactions.isEmpty) return const _EmptyState();

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: transactions.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final tx = transactions[index];
              return _TransactionTile(transaction: tx)
                  .animate()
                  .fadeIn(
                    delay: Duration(milliseconds: index * 60),
                    duration: const Duration(milliseconds: 300),
                  )
                  .slideY(begin: 0.05, end: 0);
            },
          );
        },
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final Transaction transaction;
  const _TransactionTile({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final statusInfo = _statusInfo(transaction.status);
    final dateLabel =
        DateFormat('MMM d, yyyy · h:mm a').format(transaction.createdAt);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        border: Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: statusInfo.color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(_methodIcon(transaction.paymentMethod),
                    size: 18, color: statusInfo.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _methodLabel(transaction.paymentMethod),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dateLabel,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${transaction.currency} ${transaction.amount.toStringAsFixed(0)}',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusInfo.color.withOpacity(0.12),
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusFull),
                    ),
                    child: Text(
                      statusInfo.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: statusInfo.color,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (transaction.paymentReference != null) ...[
            const SizedBox(height: 12),
            Divider(color: AppTheme.border, height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  'Ref: ',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textTertiary,
                      ),
                ),
                Expanded(
                  child: Text(
                    transaction.paymentReference!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  IconData _methodIcon(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.mpesa:
        return Icons.phone_android;
      case PaymentMethod.stripe:
      case PaymentMethod.card:
        return Icons.credit_card;
    }
  }

  String _methodLabel(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.mpesa:
        return 'M-Pesa Payment';
      case PaymentMethod.stripe:
        return 'Card Payment';
      case PaymentMethod.card:
        return 'Card Payment';
    }
  }

  ({String label, Color color}) _statusInfo(TransactionStatus status) {
    switch (status) {
      case TransactionStatus.completed:
        return (label: 'Completed', color: const Color(0xFF43A047));
      case TransactionStatus.pending:
        return (label: 'Pending', color: const Color(0xFFFB8C00));
      case TransactionStatus.processing:
        return (label: 'Processing', color: const Color(0xFF1E88E5));
      case TransactionStatus.failed:
        return (label: 'Failed', color: const Color(0xFFE53935));
      case TransactionStatus.refunded:
        return (label: 'Refunded', color: const Color(0xFF757575));
    }
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.receipt_long_outlined,
                size: 64, color: AppTheme.textTertiary),
            const SizedBox(height: 16),
            Text(
              'No transactions yet',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 8),
            Text(
              'Your payment history will show up here.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppTheme.textTertiary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline,
                size: 48, color: AppTheme.textTertiary),
            const SizedBox(height: 12),
            Text(
              'Could not load transactions',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
            const SizedBox(height: 12),
            TextButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}