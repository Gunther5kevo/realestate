import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/providers.dart';
import '../../core/models/models.dart';

class AgentListingsScreen extends ConsumerWidget {
  final String agentId;
  const AgentListingsScreen({super.key, required this.agentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listingsAsync = ref.watch(agentPropertiesProvider(agentId));

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('My Listings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/add-listing'),
          ),
        ],
      ),
      body: listingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (listings) => listings.isEmpty
            ? _buildEmpty(context)
            : RefreshIndicator(
                onRefresh: () async =>
                    ref.refresh(agentPropertiesProvider(agentId)),
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: listings.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _ListingTile(
                    property: listings[i],
                    onEdit: () =>
                        context.push('/edit-listing/${listings[i].id}'),
                    onView: () =>
                        context.push('/property/${listings[i].id}'),
                    onDelete: () =>
                        _confirmDelete(context, ref, listings[i]),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.home_outlined,
              size: 64, color: AppTheme.textTertiary),
          const SizedBox(height: 16),
          Text(
            'No listings yet',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            'Start by adding your first property',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppTheme.textTertiary),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () =>
                (context as Element).findAncestorWidgetOfExactType<Scaffold>() !=
                        null
                    ? GoRouter.of(context).push('/add-listing')
                    : null,
            child: const Text('Add Your First Listing'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Property property) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Listing'),
        content: Text(
            'Are you sure you want to delete "${property.title}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(propertyServiceProvider).deleteProperty(property.id);
        ref.refresh(agentPropertiesProvider(agentId));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Listing deleted')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete: $e')),
          );
        }
      }
    }
  }
}

// ─── Listing Tile ─────────────────────────────────────────────────────────────

class _ListingTile extends StatelessWidget {
  final Property property;
  final VoidCallback onEdit;
  final VoidCallback onView;
  final VoidCallback onDelete;

  const _ListingTile({
    required this.property,
    required this.onEdit,
    required this.onView,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final p = property;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        border: Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: Row(
        children: [
          // Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            child: Image.network(
              p.imageUrls.isNotEmpty
                  ? p.imageUrls.first
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
          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.title,
                  style: Theme.of(context).textTheme.titleLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  p.location.city,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 6),
                Text(
                  p.priceLabel,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: AppTheme.primary,
                        fontSize: 15,
                      ),
                ),
              ],
            ),
          ),

          // Status + actions
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _StatusBadge(property: p),
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ActionIcon(
                    icon: Icons.edit_outlined,
                    onTap: onEdit,
                    tooltip: 'Edit',
                  ),
                  const SizedBox(width: 8),
                  _ActionIcon(
                    icon: Icons.open_in_new,
                    onTap: onView,
                    tooltip: 'View',
                  ),
                  const SizedBox(width: 8),
                  _ActionIcon(
                    icon: Icons.delete_outline,
                    onTap: onDelete,
                    tooltip: 'Delete',
                    color: AppTheme.error,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final Property property;
  const _StatusBadge({required this.property});

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    final String label;

    if (property.status == PropertyStatus.suspended) {
      bg = AppTheme.surfaceVariant;
      fg = AppTheme.textSecondary;
      label = 'Suspended';
    } else if (!property.isApproved) {
      bg = AppTheme.warningSurface;
      fg = AppTheme.warning;
      label = 'Pending';
    } else {
      bg = AppTheme.successSurface;
      fg = AppTheme.success;
      label = 'Live';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final Color color;

  const _ActionIcon({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.color = AppTheme.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }
}