import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_theme.dart';
import '../../core/models/models.dart';
import '../../core/providers/providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorState(
          onRetry: () => ref.invalidate(currentUserProvider),
        ),
        data: (user) {
          if (user == null) {
            return _ErrorState(
              onRetry: () => ref.invalidate(currentUserProvider),
            );
          }
          return _ProfileBody(user: user);
        },
      ),
    );
  }
}

// ─── Profile Body ─────────────────────────────────────────────────────────────

class _ProfileBody extends ConsumerWidget {
  final AppUser user;
  const _ProfileBody({required this.user});

@override
Widget build(BuildContext context, WidgetRef ref) {
  final isAgent = user.role == UserRole.agent;

  return CustomScrollView(
    slivers: [
      // ── Header sliver
      SliverToBoxAdapter(child: _buildHeader(context, ref, isAgent)),

      // ── Agent stats row
      if (isAgent)
        SliverToBoxAdapter(child: _buildAgentStats(context, ref)),

      // ── Agent tools section
      if (isAgent) ...[
        SliverToBoxAdapter(child: const SizedBox(height: 12)),
        SliverToBoxAdapter(
          child: _Section(
            title: 'Agent Tools',
            children: [
              _MenuItem(
                icon: Icons.add_home_outlined,
                label: 'Add New Listing',
                onTap: () => context.push('/add-listing'),
              ),
              _MenuItem(
                icon: Icons.list_alt_outlined,
                label: 'My Listings',
                onTap: () => context.push('/agent/${user.id}/listings'),
              ),
              _MenuItem(
                icon: Icons.calendar_today_outlined,
                label: 'Booking Requests',
                onTap: () => context.go('/bookings'),
              ),
            ],
          ),
        ),
      ],

      // ── Account section
      SliverToBoxAdapter(child: const SizedBox(height: 12)),
      SliverToBoxAdapter(
        child: _Section(
          title: 'Account',
          children: [
            _MenuItem(
              icon: Icons.favorite_outline,
              label: 'Saved Properties',
              badge: user.savedProperties.isNotEmpty
                  ? '${user.savedProperties.length}'
                  : null,
              onTap: () => context.go('/saved'),
            ),
            _MenuItem(
              icon: Icons.receipt_long_outlined,
              label: 'Transactions',
              onTap: () => context.push('/transactions'),
            ),
            _MenuItem(
              icon: Icons.notifications_outlined,
              label: 'Notifications',
              onTap: () => context.push('/notifications'),
            ),
            _MenuItem(
              icon: Icons.help_outline,
              label: 'Help & Support',
              onTap: () => context.push('/help-support'),
            ),
          ],
        ),
      ),

      // ── Sign out section
      SliverToBoxAdapter(child: const SizedBox(height: 12)),
      SliverToBoxAdapter(
        child: _Section(
          title: '',
          children: [
            _MenuItem(
              icon: Icons.logout,
              label: 'Sign Out',
              textColor: AppTheme.error,
              iconColor: AppTheme.error,
              showChevron: false,
              onTap: () => _showSignOutDialog(context, ref),
            ),
          ],
        ),
      ),

      const SliverToBoxAdapter(child: SizedBox(height: 40)),
    ],
  );
}

  Widget _buildHeader(BuildContext context, WidgetRef ref, bool isAgent) {
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
      child: Column(
        children: [
          // Avatar
          Stack(
            children: [
              CircleAvatar(
                radius: 44,
                backgroundColor: AppTheme.primarySurface,
                child: user.avatarUrl != null
                    ? ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: user.avatarUrl!,
                          width: 88,
                          height: 88,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => const Icon(
                            Icons.person_outline,
                            size: 40,
                            color: AppTheme.primary,
                          ),
                          errorWidget: (_, __, ___) => Text(
                            user.fullName.isNotEmpty
                                ? user.fullName[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primary,
                            ),
                          ),
                        ),
                      )
                    : Text(
                        user.fullName.isNotEmpty
                            ? user.fullName[0].toUpperCase()
                            : 'U',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primary,
                        ),
                      ),
              ),
              // Edit button on avatar
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () => context.push('/edit-profile'),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.surface, width: 2),
                    ),
                    child: const Icon(
                      Icons.edit,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Name + verified
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  user.fullName,
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
              ),
              if (user.isVerified) ...[
                const SizedBox(width: 6),
                const Icon(Icons.verified, size: 18, color: AppTheme.primary),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            user.email,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppTheme.textSecondary),
          ),
          if (user.phoneNumber != null) ...[
            const SizedBox(height: 2),
            Text(
              user.phoneNumber!,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppTheme.textSecondary),
            ),
          ],
          const SizedBox(height: 10),

          // Role badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: AppTheme.primarySurface,
              borderRadius: BorderRadius.circular(AppTheme.radiusFull),
            ),
            child: Text(
              user.role.name[0].toUpperCase() + user.role.name.substring(1),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Agent stats — pulls real data from agentProfileProvider
  Widget _buildAgentStats(BuildContext context, WidgetRef ref) {
    final agentAsync = ref.watch(agentProfileProvider(user.id));

    return Container(
      color: AppTheme.surface,
      margin: const EdgeInsets.only(top: 1),
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: agentAsync.when(
        loading: () => const SizedBox(height: 60),
        error: (_, __) => const SizedBox.shrink(),
        data: (agent) => Row(
          children: [
            _StatBox(value: '${agent.totalListings}', label: 'Listings'),
            _StatBox(value: '${agent.soldCount}', label: 'Sold'),
            _StatBox(
              value: agent.rating > 0
                  ? agent.rating.toStringAsFixed(1)
                  : '—',
              label: 'Rating',
            ),
            _StatBox(value: '${agent.reviewCount}', label: 'Reviews'),
          ],
        ),
      ),
    );
  }

  void _showSignOutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        ),
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(authServiceProvider).signOut();
              if (context.mounted) context.go('/auth/login');
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}

// ─── Supporting Widgets ───────────────────────────────────────────────────────

class _StatBox extends StatelessWidget {
  final String value;
  final String label;
  const _StatBox({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppTheme.primary,
                ),
          ),
          const SizedBox(height: 2),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: Text(
                title.toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppTheme.textTertiary,
                      letterSpacing: 0.8,
                    ),
              ),
            ),
          ...children,
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? textColor;
  final Color? iconColor;
  final String? badge;
  final bool showChevron;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.textColor,
    this.iconColor,
    this.badge,
    this.showChevron = true,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: (iconColor ?? AppTheme.textSecondary).withOpacity(0.08),
                borderRadius: BorderRadius.circular(AppTheme.radiusSM),
              ),
              child: Icon(
                icon,
                size: 18,
                color: iconColor ?? AppTheme.textSecondary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ),
            if (badge != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primarySurface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                ),
                child: Text(
                  badge!,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            if (showChevron)
              const Icon(
                Icons.chevron_right,
                size: 18,
                color: AppTheme.textTertiary,
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline,
              size: 48, color: AppTheme.textTertiary),
          const SizedBox(height: 12),
          Text(
            'Could not load profile',
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