import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/models/models.dart';
import '../../core/providers/providers.dart';
import '../../widgets/property_card.dart';
import '../../widgets/filter_sheet.dart';
import '../../widgets/search_bar_widget.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  ListingType _selectedListingType = ListingType.sale;
  final ScrollController _scrollController = ScrollController();
  bool _showAppBarTitle = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      final show = _scrollController.offset > 60;
      if (show != _showAppBarTitle) {
        setState(() => _showAppBarTitle = show);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(propertyFilterProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: NestedScrollView(
        controller: _scrollController,
        headerSliverBuilder: (context, innerScrolled) => [
          _buildSliverAppBar(),
        ],
        body: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildListingTypeToggle(filter)),
            SliverToBoxAdapter(child: _buildSearchRow(filter)),
            SliverToBoxAdapter(child: _buildFeaturedSection()),
            SliverToBoxAdapter(child: _buildSectionHeader(filter)),
            _buildPropertyGrid(filter),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  // ─── App Bar ─────────────────────────────────────────────────────────────────

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: AppTheme.surface,
      surfaceTintColor: Colors.transparent,
      title: AnimatedOpacity(
        opacity: _showAppBarTitle ? 1 : 0,
        duration: const Duration(milliseconds: 200),
        child: Text(
          'NestIQ',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontFamily: AppTheme.fontFamilyDisplay,
                color: AppTheme.primary,
              ),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.pin,
        background: _buildAppBarBackground(),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined),
          onPressed: () => context.push('/notifications'),
          color: AppTheme.textPrimary,
        ),
        _buildAvatarButton(),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildAppBarBackground() {
    final userAsync = ref.watch(currentUserProvider);

    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          userAsync.when(
            loading: () => const SizedBox(height: 48),
            error: (_, __) => _greetingColumn('there'),
            data: (user) {
              final firstName = user?.fullName.split(' ').first ?? 'there';
              return _greetingColumn(firstName);
            },
          ),
        ],
      ),
    );
  }

  Widget _greetingColumn(String firstName) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$_greeting, $firstName 👋',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          'Find Your Dream Home',
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontFamily: AppTheme.fontFamilyDisplay,
                color: AppTheme.primary,
              ),
        ),
      ],
    );
  }

  Widget _buildAvatarButton() {
    final userAsync = ref.watch(currentUserProvider);

    return GestureDetector(
      onTap: () => context.go('/profile'),
      child: Container(
        width: 36,
        height: 36,
        margin: const EdgeInsets.only(right: 4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.primarySurface,
          border: Border.all(
            color: AppTheme.primary.withOpacity(0.2),
            width: 1.5,
          ),
        ),
        child: userAsync.when(
          loading: () => const Icon(
            Icons.person_outline,
            size: 18,
            color: AppTheme.primary,
          ),
          error: (_, __) => const Icon(
            Icons.person_outline,
            size: 18,
            color: AppTheme.primary,
          ),
          data: (user) {
            // Show avatar photo if available
            if (user?.avatarUrl != null) {
              return ClipOval(
                child: CachedNetworkImage(
                  imageUrl: user!.avatarUrl!,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => const Icon(
                    Icons.person_outline,
                    size: 18,
                    color: AppTheme.primary,
                  ),
                  errorWidget: (_, __, ___) => const Icon(
                    Icons.person_outline,
                    size: 18,
                    color: AppTheme.primary,
                  ),
                ),
              );
            }
            // Fall back to first initial
            final initial = user?.fullName.isNotEmpty == true
                ? user!.fullName[0].toUpperCase()
                : '?';
            return Center(
              child: Text(
                initial,
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ─── Listing Type Toggle ──────────────────────────────────────────────────────

  Widget _buildListingTypeToggle(PropertyFilter filter) {
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Row(
        children: [
          _ToggleButton(
            label: 'Buy',
            isSelected: _selectedListingType == ListingType.sale,
            onTap: () {
              setState(() => _selectedListingType = ListingType.sale);
              ref.read(propertyFilterProvider.notifier).state =
                  filter.copyWith(listingType: ListingType.sale);
            },
          ),
          const SizedBox(width: 8),
          _ToggleButton(
            label: 'Rent',
            isSelected: _selectedListingType == ListingType.rent,
            onTap: () {
              setState(() => _selectedListingType = ListingType.rent);
              ref.read(propertyFilterProvider.notifier).state =
                  filter.copyWith(listingType: ListingType.rent);
            },
          ),
        ],
      ),
    );
  }

  // ─── Search Row ───────────────────────────────────────────────────────────────

  Widget _buildSearchRow(PropertyFilter filter) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: SearchBarWidget(
              onTap: () => context.push('/search'),
              hintText: _selectedListingType == ListingType.rent
                  ? 'Search rental properties...'
                  : 'Search properties for sale...',
            ),
          ),
          const SizedBox(width: 8),
          // Map button
          GestureDetector(
            onTap: () => context.push('/map'),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.surfaceVariant,
                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                border: Border.all(color: AppTheme.border, width: 0.5),
              ),
              child: const Icon(
                Icons.map_outlined,
                color: AppTheme.textSecondary,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _FilterButton(
            hasActiveFilters: filter.hasActiveFilters,
            onTap: () => _showFilterSheet(filter),
          ),
        ],
      ),
    );
  }

  void _showFilterSheet(PropertyFilter currentFilter) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FilterSheet(
        currentFilter: currentFilter,
        onApply: (newFilter) {
          ref.read(propertyFilterProvider.notifier).state = newFilter;
        },
      ),
    );
  }

  // ─── Featured Section ─────────────────────────────────────────────────────────

  // ─── Featured Section — hidden entirely when empty ───────────────────────────

  Widget _buildFeaturedSection() {
    final featuredAsync = ref.watch(featuredPropertiesProvider);

    // Don't render anything (no header, no blank space) until we know there's data
    return featuredAsync.when(
      loading: () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _featuredHeader(),
          SizedBox(
            height: 280,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemCount: 3,
              itemBuilder: (_, index) => Padding(
                padding: EdgeInsets.only(right: index < 2 ? 16 : 0),
                child: Shimmer.fromColors(
                  baseColor: AppTheme.border,
                  highlightColor: AppTheme.surfaceVariant,
                  child: Container(
                    width: 240,
                    decoration: BoxDecoration(
                      color: AppTheme.border,
                      borderRadius: BorderRadius.circular(AppTheme.radiusXL),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (properties) {
        if (properties.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _featuredHeader(),
            SizedBox(
              height: 280,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: properties.length,
                itemBuilder: (context, index) {
                  final property = properties[index];
                  return Padding(
                    padding: EdgeInsets.only(
                      right: index < properties.length - 1 ? 16 : 0,
                    ),
                    child: FeaturedPropertyCard(
                      property: property,
                      onTap: () => context.push('/property/${property.id}'),
                    ).animate().fadeIn(
                          delay: Duration(milliseconds: index * 100),
                          duration: const Duration(milliseconds: 400),
                        ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _featuredHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Featured', style: Theme.of(context).textTheme.headlineMedium),
          TextButton(
            onPressed: () => context.push('/search'),
            child: const Text('See all'),
          ),
        ],
      ),
    );
  }

  // ─── All Properties Grid ──────────────────────────────────────────────────────

  Widget _buildSectionHeader(PropertyFilter filter) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'All Properties',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.primarySurface,
              borderRadius: BorderRadius.circular(AppTheme.radiusFull),
            ),
            child: Text(
              filter.hasActiveFilters ? 'Filtered' : 'All',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPropertyGrid(PropertyFilter filter) {
    final propertiesAsync = ref.watch(propertiesProvider(filter));

    return propertiesAsync.when(
      loading: () => SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        sliver: SliverGrid(
          delegate: SliverChildBuilderDelegate(
            (_, __) => Shimmer.fromColors(
              baseColor: AppTheme.border,
              highlightColor: AppTheme.surfaceVariant,
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.border,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                ),
              ),
            ),
            childCount: 6,
          ),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.72,
          ),
        ),
      ),
      error: (_, __) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: AppTheme.textTertiary,
              ),
              const SizedBox(height: 12),
              Text(
                'Could not load properties',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => ref.invalidate(propertiesProvider(filter)),
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
      data: (properties) {
        if (properties.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                children: [
                  const Icon(
                    Icons.home_outlined,
                    size: 64,
                    color: AppTheme.textTertiary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No properties found',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Try adjusting your filters',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textTertiary,
                        ),
                  ),
                ],
              ),
            ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final property = properties[index];
                return PropertyCard(
                  property: property,
                  onTap: () => context.push('/property/${property.id}'),
                )
                    .animate()
                    .fadeIn(
                      delay: Duration(milliseconds: index * 80),
                      duration: const Duration(milliseconds: 400),
                    )
                    .slideY(begin: 0.1, end: 0);
              },
              childCount: properties.length,
            ),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.72,
            ),
          ),
        );
      },
    );
  }
}

// ─── Supporting Widgets ───────────────────────────────────────────────────────

class _ToggleButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ToggleButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isSelected ? AppTheme.textOnPrimary : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  final bool hasActiveFilters;
  final VoidCallback onTap;

  const _FilterButton({required this.hasActiveFilters, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: hasActiveFilters ? AppTheme.primary : AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          border: Border.all(
            color: hasActiveFilters ? AppTheme.primary : AppTheme.border,
            width: 0.5,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              Icons.tune_rounded,
              color: hasActiveFilters
                  ? AppTheme.textOnPrimary
                  : AppTheme.textSecondary,
              size: 20,
            ),
            if (hasActiveFilters)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF6B35),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class FeaturedPropertyCard extends StatelessWidget {
  final Property property;
  final VoidCallback onTap;

  const FeaturedPropertyCard({
    super.key,
    required this.property,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 240,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radiusXL),
          boxShadow: AppTheme.shadowMD,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusXL),
          child: Stack(
            children: [
              // Image
              SizedBox.expand(
                child: CachedNetworkImage(
                  imageUrl: property.imageUrls.isNotEmpty
                      ? property.imageUrls.first
                      : 'https://images.unsplash.com/photo-1564013799919-ab600027ffc6?w=600',
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Shimmer.fromColors(
                    baseColor: AppTheme.border,
                    highlightColor: AppTheme.surfaceVariant,
                    child: Container(color: AppTheme.border),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    color: AppTheme.surfaceVariant,
                    child: const Icon(
                      Icons.home_outlined,
                      size: 48,
                      color: AppTheme.textTertiary,
                    ),
                  ),
                ),
              ),

              // Gradient overlay
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.7),
                      ],
                      stops: const [0.4, 1.0],
                    ),
                  ),
                ),
              ),

              // Featured badge
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.accent,
                    borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  ),
                  child: const Text(
                    'Featured',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              // Save button
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.favorite_border,
                    size: 18,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),

              // Property info
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        property.priceLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          fontFamily: AppTheme.fontFamily,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        property.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            color: Colors.white70,
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            property.location.neighborhood ??
                                property.location.city,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
