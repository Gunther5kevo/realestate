import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/providers.dart';
import '../../widgets/property_card.dart';
import '../../core/utils/contact_launcher.dart';

class AgentProfileScreen extends ConsumerWidget {
  final String agentId;
  const AgentProfileScreen({super.key, required this.agentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agentAsync = ref.watch(agentProfileProvider(agentId));
    final listingsAsync = ref.watch(agentPropertiesProvider(agentId));

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: agentAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (agent) => CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 220,
              pinned: true,
              backgroundColor: AppTheme.primary,
              surfaceTintColor: Colors.transparent,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => context.pop(),
              ),
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.pin,
                background: Container(
                  color: AppTheme.primary,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 56),
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        backgroundImage: agent.avatarUrl != null
                            ? NetworkImage(agent.avatarUrl!)
                            : null,
                        child: agent.avatarUrl == null
                            ? Text(
                                agent.displayName.isNotEmpty
                                    ? agent.displayName[0].toUpperCase()
                                    : 'A',
                                style: const TextStyle(
                                  fontSize: 28,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            agent.displayName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              fontFamily: AppTheme.fontFamily,
                            ),
                          ),
                          if (agent.isVerified) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.verified,
                                size: 18, color: Colors.white),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        agent.agency ?? 'Independent Agent',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontFamily: AppTheme.fontFamily,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Container(
                color: AppTheme.surface,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _StatBox(
                            value: '${agent.totalListings}',
                            label: 'Listings'),
                        _StatBox(
                            value: '${agent.soldCount}', label: 'Sold'),
                        _StatBox(
                            value: agent.rating.toStringAsFixed(1),
                            label: 'Rating'),
                        _StatBox(
                            value: '${agent.reviewCount}',
                            label: 'Reviews'),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (agent.bio != null && agent.bio!.isNotEmpty) ...[
                      Text('About',
                          style:
                              Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 8),
                      Text(
                        agent.bio!,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 20),
                    ],
                    if (agent.licenseNumber != null) ...[
                      _DetailRow(
                          icon: Icons.badge_outlined,
                          label: 'License',
                          value: agent.licenseNumber!),
                      const SizedBox(height: 8),
                    ],
                    if (agent.phone != null)
                      _DetailRow(
                          icon: Icons.phone_outlined,
                          label: 'Phone',
                          value: agent.phone!),
                    const SizedBox(height: 20),

                    // ── Contact buttons ──────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.phone_outlined, size: 16),
                            label: const Text('Call'),
                            onPressed: agent.phone != null
                                ? () => ContactLauncher.call(agent.phone!)
                                : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.chat_outlined, size: 16),
                            label: const Text('WhatsApp'),
                            onPressed: agent.phone != null
                                ? () => ContactLauncher.whatsapp(
                                      agent.phone!,
                                      message:
                                          'Hello ${agent.displayName}, I found your listing and would like to inquire further.',
                                    )
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Listings',
                        style:
                            Theme.of(context).textTheme.headlineMedium),
                    TextButton(
                      onPressed: () =>
                          context.push('/agent/$agentId/listings'),
                      child: const Text('See all'),
                    ),
                  ],
                ),
              ),
            ),

            listingsAsync.when(
              loading: () => const SliverToBoxAdapter(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => SliverToBoxAdapter(
                  child: Center(child: Text('Error: $e'))),
              data: (listings) => SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => PropertyCard(
                      property: listings[i],
                      onTap: () =>
                          context.push('/property/${listings[i].id}'),
                    ),
                    childCount: listings.length,
                  ),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.72,
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }
}

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
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(color: AppTheme.primary),
          ),
          const SizedBox(height: 2),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DetailRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.textSecondary),
        const SizedBox(width: 8),
        Text('$label: ',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(fontWeight: FontWeight.w500)),
        Text(value, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}