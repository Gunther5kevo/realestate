import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_theme.dart';
import '../../core/models/models.dart';
import '../../core/providers/providers.dart';

class BookingsScreen extends ConsumerStatefulWidget {
  const BookingsScreen({super.key});

  @override
  ConsumerState<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends ConsumerState<BookingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(currentUserRoleProvider);
    final isAgent = role == UserRole.agent;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(isAgent ? 'Booking Requests' : 'My Bookings'),
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primary,
          indicatorSize: TabBarIndicatorSize.label,
          dividerColor: AppTheme.border,
          tabs: isAgent
              ? const [
                  Tab(text: 'Incoming'),
                  Tab(text: 'Confirmed'),
                ]
              : const [
                  Tab(text: 'All'),
                  Tab(text: 'Upcoming'),
                ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: isAgent
            ? [
                _AgentBookingsTab(filter: null),
                _AgentBookingsTab(filter: BookingStatus.confirmed),
              ]
            : [
                _UserBookingsTab(filter: null),
                _UserBookingsTab(upcomingOnly: true),
              ],
      ),
    );
  }
}

// ─── User Tabs ────────────────────────────────────────────────────────────────

class _UserBookingsTab extends ConsumerWidget {
  final BookingStatus? filter;
  final bool upcomingOnly;

  const _UserBookingsTab({this.filter, this.upcomingOnly = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(userBookingsProvider);

    return bookingsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) =>
          _ErrorState(onRetry: () => ref.invalidate(userBookingsProvider)),
      data: (bookings) {
        var filtered = bookings;

        if (filter != null) {
          filtered = filtered.where((b) => b.status == filter).toList();
        }

        if (upcomingOnly) {
          filtered = filtered
              .where((b) =>
                  (b.status == BookingStatus.confirmed ||
                      b.status == BookingStatus.pending) &&
                  b.scheduledDate.isAfter(DateTime.now()))
              .toList();
        }

        if (filtered.isEmpty) {
          return _EmptyState(
            icon: Icons.calendar_today_outlined,
            title: upcomingOnly ? 'No upcoming viewings' : 'No bookings yet',
            subtitle: upcomingOnly
                ? 'Confirmed viewings will appear here'
                : 'Browse properties and schedule a viewing',
            onAction: upcomingOnly ? null : () => context.go('/home'),
            actionLabel: 'Browse Properties',
          );
        }

        return RefreshIndicator(
          color: AppTheme.primary,
          onRefresh: () async => ref.invalidate(userBookingsProvider),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) =>
                _BookingCard(booking: filtered[i], isAgent: false),
          ),
        );
      },
    );
  }
}

// ─── Agent Tabs ───────────────────────────────────────────────────────────────

class _AgentBookingsTab extends ConsumerWidget {
  final BookingStatus? filter;

  const _AgentBookingsTab({this.filter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(agentBookingsProvider);

    return bookingsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) =>
          _ErrorState(onRetry: () => ref.invalidate(agentBookingsProvider)),
      data: (bookings) {
        final filtered = filter != null
            ? bookings.where((b) => b.status == filter).toList()
            : bookings;

        if (filtered.isEmpty) {
          return _EmptyState(
            icon: Icons.inbox_outlined,
            title: filter == BookingStatus.confirmed
                ? 'No confirmed bookings'
                : 'No booking requests yet',
            subtitle: filter == BookingStatus.confirmed
                ? 'Confirmed viewings will appear here'
                : 'When clients book viewings they will appear here',
          );
        }

        return RefreshIndicator(
          color: AppTheme.primary,
          onRefresh: () async => ref.invalidate(agentBookingsProvider),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) =>
                _BookingCard(booking: filtered[i], isAgent: true),
          ),
        );
      },
    );
  }
}

// ─── Booking Card ─────────────────────────────────────────────────────────────

class _BookingCard extends ConsumerStatefulWidget {
  final Booking booking;
  final bool isAgent;

  const _BookingCard({required this.booking, required this.isAgent});

  @override
  ConsumerState<_BookingCard> createState() => _BookingCardState();
}

class _BookingCardState extends ConsumerState<_BookingCard> {
  bool _isActing = false;

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;

    final statusColor = {
      BookingStatus.pending: AppTheme.warning,
      BookingStatus.confirmed: AppTheme.success,
      BookingStatus.cancelled: AppTheme.error,
      BookingStatus.completed: AppTheme.textSecondary,
    }[booking.status]!;

    final statusLabel = {
      BookingStatus.pending: 'Pending',
      BookingStatus.confirmed: 'Confirmed',
      BookingStatus.cancelled: 'Cancelled',
      BookingStatus.completed: 'Completed',
    }[booking.status]!;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        border: Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Property row
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                  child: booking.propertyImage.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: booking.propertyImage,
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => _imageFallback(),
                        )
                      : _imageFallback(),
                ),
                const SizedBox(width: 12),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        booking.propertyTitle,
                        style: Theme.of(context).textTheme.titleLarge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.isAgent
                            ? 'Client: ${booking.userFullName}'
                            : DateFormat('EEE, MMM d, yyyy')
                                .format(booking.scheduledDate),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (!widget.isAgent && booking.timeSlot != null)
                        Text(
                          'at ${booking.timeSlot}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      if (widget.isAgent)
                        Text(
                          '${DateFormat('EEE, MMM d').format(booking.scheduledDate)}'
                          '${booking.timeSlot != null ? ' at ${booking.timeSlot}' : ''}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),

                // Status badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Action buttons
          if (_showActions(booking.status)) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: _isActing
                  ? const Center(
                      child: SizedBox(
                        height: 36,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : widget.isAgent
                      ? _agentActions(booking)
                      : _clientActions(booking),
            ),
          ],
        ],
      ),
    );
  }

  bool _showActions(BookingStatus status) =>
      status == BookingStatus.pending || status == BookingStatus.confirmed;

  Widget _agentActions(Booking booking) {
    if (booking.status == BookingStatus.pending) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => _updateStatus(BookingStatus.cancelled),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.error,
                side: const BorderSide(color: AppTheme.error, width: 0.5),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              child: const Text('Decline'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton(
              onPressed: () => _updateStatus(BookingStatus.confirmed),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              child: const Text('Confirm'),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => _updateStatus(BookingStatus.cancelled),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.error,
              side: const BorderSide(color: AppTheme.error, width: 0.5),
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
            child: const Text('Cancel'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton(
            onPressed: () => _updateStatus(BookingStatus.completed),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
            child: const Text('Mark Done'),
          ),
        ),
      ],
    );
  }

  Widget _clientActions(Booking booking) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => _showCancelDialog(),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.error,
              side: const BorderSide(color: AppTheme.error, width: 0.5),
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
            child: const Text('Cancel'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton(
            onPressed: () => context.push('/property/${booking.propertyId}'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
            child: const Text('View Property'),
          ),
        ),
      ],
    );
  }

  Future<void> _updateStatus(BookingStatus status) async {
    setState(() => _isActing = true);
    try {
      await ref
          .read(bookingServiceProvider)
          .updateBookingStatus(widget.booking.id, status);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update booking: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isActing = false);
    }
  }

  void _showCancelDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        ),
        title: const Text('Cancel Booking'),
        content: const Text(
          'Are you sure you want to cancel this viewing? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep it'),
          ),
          TextButton(
            // THE FIX: await endOfFrame after dialog pop before calling
            // _updateStatus. The status update triggers a Riverpod rebuild
            // which re-inserts the card's widgets in the same frame the dialog
            // is being removed, causing a duplicate-GlobalKey assertion.
            // Waiting for endOfFrame lets the dialog route fully deregister
            // its keys before the list rebuilds.
            onPressed: () async {
              Navigator.pop(context);
              await WidgetsBinding.instance.endOfFrame;
              if (context.mounted) _updateStatus(BookingStatus.cancelled);
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('Yes, cancel'),
          ),
        ],
      ),
    );
  }

  Widget _imageFallback() {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
      ),
      child: const Icon(
        Icons.home_outlined,
        color: AppTheme.textTertiary,
        size: 28,
      ),
    );
  }
}

// ─── Reusable States ──────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onAction;
  final String? actionLabel;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onAction,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: AppTheme.surfaceVariant,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: AppTheme.textTertiary),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppTheme.textTertiary),
              textAlign: TextAlign.center,
            ),
            if (onAction != null) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onAction,
                child: Text(actionLabel ?? 'Go'),
              ),
            ],
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline,
              size: 48, color: AppTheme.textTertiary),
          const SizedBox(height: 12),
          Text(
            'Could not load bookings',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 12),
          TextButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}