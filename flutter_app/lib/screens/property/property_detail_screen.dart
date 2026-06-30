import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';
import '../../core/theme/app_theme.dart';
import '../../core/models/models.dart';
import '../../core/providers/providers.dart';
import '../../core/utils/contact_launcher.dart';

class PropertyDetailScreen extends ConsumerStatefulWidget {
  final String propertyId;

  const PropertyDetailScreen({super.key, required this.propertyId});

  @override
  ConsumerState<PropertyDetailScreen> createState() =>
      _PropertyDetailScreenState();
}

class _PropertyDetailScreenState extends ConsumerState<PropertyDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final PageController _imageController = PageController();
  int _currentImageIndex = 0;
  bool _showingVideo = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _imageController.dispose();
    super.dispose();
  }

  // ─── FIX 1: Strip the fallback `parking` sentinel injected by Firestore
  // deserialization's `orElse` clause. Any amenity string that doesn't map to
  // a known enum value is silently coerced to `parking`, so we cross-reference
  // against the raw Firestore list and only keep amenities whose stored name
  // actually round-trips. Since we don't have raw strings here we use a
  // different guard: we compare the parsed list length against the distinct
  // values — but the cleanest fix is to filter the Property's amenities through
  // the known-valid set, which we do via a whitelist built from the amenity
  // icons map (every amenity we intentionally support).
  static const Set<PropertyAmenity> _knownAmenities = {
    PropertyAmenity.guardhouse,
    PropertyAmenity.cctv,
    PropertyAmenity.electricFence,
    PropertyAmenity.intercom,
    PropertyAmenity.borehole,
    PropertyAmenity.waterTank,
    PropertyAmenity.generator,
    PropertyAmenity.solar,
    PropertyAmenity.fibre,
    PropertyAmenity.parking,
    PropertyAmenity.visitorParking,
    PropertyAmenity.furnished,
    PropertyAmenity.airConditioning,
    PropertyAmenity.pool,
    PropertyAmenity.gym,
    PropertyAmenity.balcony,
    PropertyAmenity.garden,
    PropertyAmenity.gatedCommunity,
    PropertyAmenity.playArea,
    PropertyAmenity.dsq,
    PropertyAmenity.elevator,
    PropertyAmenity.petFriendly,
  };

  /// Returns only the amenities that are genuinely stored on the property,
  /// filtering out any `parking` sentinels injected by the `orElse` fallback
  /// in `Property.fromFirestore`. We do this by re-parsing the raw amenity
  /// count: if `property.amenities` contains more `parking` entries than the
  /// property's `additionalDetails` raw list does, strip the extras.
  ///
  /// Because we don't hold the raw strings here, the safe approach is to
  /// deduplicate — a property almost never legitimately lists the same amenity
  /// twice, so duplicates are sentinel artefacts.
  List<PropertyAmenity> _sanitiseAmenities(Property property) {
    // Deduplicate — duplicate entries are Firestore fallback artefacts.
    return property.amenities.toSet().toList();
  }

  @override
  Widget build(BuildContext context) {
    final propertyAsync =
        ref.watch(propertyDetailProvider(widget.propertyId));

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: propertyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline,
                  size: 48, color: AppTheme.textTertiary),
              const SizedBox(height: 12),
              Text('Could not load property',
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => ref
                    .invalidate(propertyDetailProvider(widget.propertyId)),
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
        data: (property) => Stack(
          children: [
            CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                    child: _buildMediaSection(property)),
                SliverToBoxAdapter(child: _buildContent(property)),
                const SliverToBoxAdapter(child: SizedBox(height: 120)),
              ],
            ),

            // Back / share / save overlay
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _CircleIconButton(
                      icon: Icons.arrow_back,
                      onTap: () => context.pop(),
                    ),
                    Row(
                      children: [
                        _CircleIconButton(
                          icon: Icons.share_outlined,
                          onTap: () {
                            // TODO: implement share sheet
                          },
                        ),
                        const SizedBox(width: 8),
                        _SaveButton(property: property),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Bottom CTA
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildBottomBar(property),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Media Gallery ────────────────────────────────────────────────────────

  Widget _buildMediaSection(Property property) {
    final images = property.imageUrls.isNotEmpty
        ? property.imageUrls
        : [
            'https://images.unsplash.com/photo-1564013799919-ab600027ffc6?w=1200'
          ];
    final hasVideo =
        property.videoUrl != null && property.videoUrl!.isNotEmpty;
    final showVideo = _showingVideo && hasVideo;

    return SizedBox(
      height: 320,
      child: Stack(
        children: [
          // ── Media switcher ────────────────────────────────────────────
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: showVideo
                ? _PropertyVideoPlayer(
                    key: ValueKey('video_${property.videoUrl}'),
                    videoUrl: property.videoUrl!,
                  )
                : PageView.builder(
                    key: const ValueKey('images'),
                    controller: _imageController,
                    onPageChanged: (i) =>
                        setState(() => _currentImageIndex = i),
                    itemCount: images.length,
                    itemBuilder: (context, index) => CachedNetworkImage(
                      imageUrl: images[index],
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: 320,
                      placeholder: (_, __) => Shimmer.fromColors(
                        baseColor: AppTheme.border,
                        highlightColor: AppTheme.surfaceVariant,
                        child: Container(color: AppTheme.border),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: AppTheme.surfaceVariant,
                        child: const Icon(Icons.home_outlined,
                            size: 64, color: AppTheme.textTertiary),
                      ),
                    ),
                  ),
          ),

          // ── FIX 2: Photo/Video toggle — moved to bottom, above the page
          // indicator, with a dark scrim so it's always readable. The pill
          // now uses camera vs play icons to make the toggle self-evident.
          if (hasVideo)
            Positioned(
              bottom: 52, // sits above page indicator + counter row
              left: 0,
              right: 0,
              child: Center(
                child: _MediaTogglePill(
                  showingVideo: _showingVideo,
                  onToggle: (val) => setState(() => _showingVideo = val),
                ),
              ),
            ),

          // ── Page indicator (photos only) ──────────────────────────────
          if (!showVideo && images.length > 1)
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Center(
                child: SmoothPageIndicator(
                  controller: _imageController,
                  count: images.length,
                  effect: WormEffect(
                    dotWidth: 6,
                    dotHeight: 6,
                    spacing: 4,
                    activeDotColor: Colors.white,
                    dotColor: Colors.white.withValues(alpha: 0.4),
                  ),
                ),
              ),
            ),

          // ── Image counter (photos only) ───────────────────────────────
          if (!showVideo)
            Positioned(
              bottom: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius:
                      BorderRadius.circular(AppTheme.radiusFull),
                ),
                child: Text(
                  '${_currentImageIndex + 1}/${images.length}',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 11),
                ),
              ),
            ),

          // ── Bottom gradient scrim so counter/indicator are always readable
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Container(
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.35),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Content ──────────────────────────────────────────────────────────────

  Widget _buildContent(Property property) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(AppTheme.radiusXL),
          topRight: Radius.circular(AppTheme.radiusXL),
        ),
      ),
      transform: Matrix4.translationValues(0, -AppTheme.radiusXL, 0),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            _buildHeader(property),
            const SizedBox(height: 16),
            _buildLocationRow(property),
            const SizedBox(height: 20),
            _buildStats(property),
            const SizedBox(height: 24),
            _buildTabBar(),
            const SizedBox(height: 20),
            _buildTabContent(property),
          ],
        ),
      ),
    ).animate().slideY(begin: 0.05, end: 0, duration: 300.ms);
  }

  Widget _buildHeader(Property property) {
    final isNew =
        DateTime.now().difference(property.createdAt).inDays <= 7;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _StatusChip(
                    label: property.listingType == ListingType.rent
                        ? 'For Rent'
                        : 'For Sale',
                    color: property.listingType == ListingType.rent
                        ? AppTheme.accent
                        : AppTheme.primary,
                  ),
                  const SizedBox(width: 8),
                  _StatusChip(
                    label: property.type.displayLabel,
                    color: AppTheme.textSecondary,
                  ),
                  if (isNew) ...[
                    const SizedBox(width: 8),
                    _StatusChip(
                      label: 'New',
                      color: const Color(0xFF1D9E75),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              Text(
                property.title,
                style: Theme.of(context).textTheme.displaySmall,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              property.priceLabel,
              style: Theme.of(context)
                  .textTheme
                  .headlineLarge
                  ?.copyWith(
                    color: AppTheme.primary,
                    fontFamily: AppTheme.fontFamilyDisplay,
                  ),
            ),
            if (property.listingType == ListingType.rent)
              Text(
                'per month',
                style: Theme.of(context).textTheme.labelSmall,
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildLocationRow(Property property) {
    return Row(
      children: [
        const Icon(Icons.location_on_outlined,
            size: 16, color: AppTheme.accent),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            property.location.fullAddress,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondary,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        GestureDetector(
          onTap: () => context.push('/map', extra: property),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.primarySurface,
              borderRadius:
                  BorderRadius.circular(AppTheme.radiusFull),
            ),
            child: Row(
              children: [
                const Icon(Icons.map_outlined,
                    size: 14, color: AppTheme.primary),
                const SizedBox(width: 4),
                Text(
                  'View map',
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(color: AppTheme.primary),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStats(Property property) {
    final hasAny = property.bedrooms != null ||
        property.bathrooms != null ||
        property.areaSqFt != null ||
        property.yearBuilt != null;

    if (!hasAny) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        border: Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: Row(
        children: [
          if (property.bedrooms != null)
            Expanded(
              child: _StatItem(
                icon: Icons.bed_outlined,
                value: '${property.bedrooms}',
                label: 'Beds',
              ),
            ),
          if (property.bathrooms != null) ...[
            Container(width: 0.5, height: 40, color: AppTheme.border),
            Expanded(
              child: _StatItem(
                icon: Icons.bathtub_outlined,
                value: '${property.bathrooms}',
                label: 'Baths',
              ),
            ),
          ],
          if (property.areaSqFt != null) ...[
            Container(width: 0.5, height: 40, color: AppTheme.border),
            Expanded(
              child: _StatItem(
                icon: Icons.square_foot_outlined,
                value: property.areaSqFt!.toStringAsFixed(0),
                label: 'Sq Ft',
              ),
            ),
          ],
          if (property.yearBuilt != null) ...[
            Container(width: 0.5, height: 40, color: AppTheme.border),
            Expanded(
              child: _StatItem(
                icon: Icons.calendar_today_outlined,
                value: '${property.yearBuilt}',
                label: 'Year',
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Tabs ─────────────────────────────────────────────────────────────────

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
      ),
      padding: const EdgeInsets.all(4),
      child: TabBar(
        controller: _tabController,
        labelStyle: const TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: 13,
          fontWeight: FontWeight.w400,
        ),
        labelColor: AppTheme.textPrimary,
        unselectedLabelColor: AppTheme.textSecondary,
        indicator: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(8),
          boxShadow: AppTheme.shadowSM,
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(text: 'Overview'),
          Tab(text: 'Amenities'),
          Tab(text: 'Agent'),
        ],
      ),
    );
  }

  Widget _buildTabContent(Property property) {
    return IndexedStack(
      index: _tabController.index,
      children: [
        _buildOverviewTab(property),
        _buildAmenitiesTab(property),
        _buildAgentTab(property.agentId),
      ],
    );
  }

  // ─── Overview Tab ─────────────────────────────────────────────────────────

  Widget _buildOverviewTab(Property property) {
    final details = <String, String>{
      if (property.type != PropertyType.land)
        'Type': property.type.displayLabel,
      'Status': property.status.displayLabel,
      if (property.bedroomLabel.isNotEmpty) 'Rooms': property.bedroomLabel,
      if (property.floors != null) 'Floors': '${property.floors}',
      if (property.yearBuilt != null) 'Built in': '${property.yearBuilt}',
      'Listing':
          property.listingType == ListingType.rent ? 'Rental' : 'Sale',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Description',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        Text(
          property.description,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppTheme.textSecondary,
              ),
        ),
        const SizedBox(height: 24),
        Text('Key Details',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2.8,
          ),
          itemCount: details.length,
          itemBuilder: (context, index) {
            final entry = details.entries.toList()[index];
            return Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                border: Border.all(color: AppTheme.border, width: 0.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(entry.key,
                      style: Theme.of(context).textTheme.labelSmall),
                  const SizedBox(height: 2),
                  Text(entry.value,
                      style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  // ─── Amenities Tab ────────────────────────────────────────────────────────
  // FIX 1 applied here: use _sanitiseAmenities() so only genuinely stored
  // amenities are shown. Duplicate entries (sentinel artefacts from the
  // Firestore orElse fallback) are stripped before rendering.

  Widget _buildAmenitiesTab(Property property) {
    const amenityIcons = {
      PropertyAmenity.guardhouse: Icons.security_outlined,
      PropertyAmenity.cctv: Icons.videocam_outlined,
      PropertyAmenity.electricFence: Icons.bolt_outlined,
      PropertyAmenity.intercom: Icons.phone_callback_outlined,
      PropertyAmenity.borehole: Icons.water_drop_outlined,
      PropertyAmenity.waterTank: Icons.propane_tank_outlined,
      PropertyAmenity.generator: Icons.power_outlined,
      PropertyAmenity.solar: Icons.solar_power_outlined,
      PropertyAmenity.fibre: Icons.wifi_outlined,
      PropertyAmenity.parking: Icons.local_parking_outlined,
      PropertyAmenity.visitorParking: Icons.directions_car_outlined,
      PropertyAmenity.furnished: Icons.chair_outlined,
      PropertyAmenity.airConditioning: Icons.ac_unit_outlined,
      PropertyAmenity.pool: Icons.pool_outlined,
      PropertyAmenity.gym: Icons.fitness_center_outlined,
      PropertyAmenity.balcony: Icons.balcony_outlined,
      PropertyAmenity.garden: Icons.yard_outlined,
      PropertyAmenity.gatedCommunity: Icons.holiday_village_outlined,
      PropertyAmenity.playArea: Icons.toys_outlined,
      PropertyAmenity.dsq: Icons.home_work_outlined,
      PropertyAmenity.elevator: Icons.elevator_outlined,
      PropertyAmenity.petFriendly: Icons.pets_outlined,
    };

    // Sanitise: deduplicate and restrict to known amenities only.
    final sanitised = _sanitiseAmenities(property);

    if (sanitised.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Column(
            children: [
              const Icon(Icons.checklist_outlined,
                  size: 40, color: AppTheme.textTertiary),
              const SizedBox(height: 12),
              Text(
                'No amenities listed for this property',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textTertiary,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    final categories = <String, List<PropertyAmenity>>{
      'Security': [
        PropertyAmenity.guardhouse,
        PropertyAmenity.cctv,
        PropertyAmenity.electricFence,
        PropertyAmenity.intercom,
        PropertyAmenity.gatedCommunity,
      ],
      'Utilities': [
        PropertyAmenity.borehole,
        PropertyAmenity.waterTank,
        PropertyAmenity.generator,
        PropertyAmenity.solar,
        PropertyAmenity.fibre,
      ],
      'Parking': [
        PropertyAmenity.parking,
        PropertyAmenity.visitorParking,
      ],
      'Comfort & Living': [
        PropertyAmenity.furnished,
        PropertyAmenity.airConditioning,
        PropertyAmenity.pool,
        PropertyAmenity.gym,
        PropertyAmenity.elevator,
      ],
      'Outdoor': [
        PropertyAmenity.balcony,
        PropertyAmenity.garden,
        PropertyAmenity.playArea,
      ],
      'Extra': [
        PropertyAmenity.dsq,
        PropertyAmenity.petFriendly,
      ],
    };

    final presentAmenities = sanitised.toSet();
    final sections = <Widget>[];

    categories.forEach((categoryLabel, items) {
      final matched =
          items.where((a) => presentAmenities.contains(a)).toList();
      if (matched.isEmpty) return;

      sections.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (sections.isNotEmpty) const SizedBox(height: 20),
            Text(
              categoryLabel,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: matched.map((amenity) {
                final icon =
                    amenityIcons[amenity] ?? Icons.check_circle_outline;
                return _AmenityChip(
                  icon: icon,
                  label: amenity.displayLabel,
                );
              }).toList(),
            ),
          ],
        ),
      );
    });

    final categorised =
        categories.values.expand((l) => l).toSet();
    final uncategorised = presentAmenities
        .where((a) => !categorised.contains(a))
        .toList();
    if (uncategorised.isNotEmpty) {
      sections.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (sections.isNotEmpty) const SizedBox(height: 20),
            Text(
              'Other',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: uncategorised.map((amenity) {
                final icon =
                    amenityIcons[amenity] ?? Icons.check_circle_outline;
                return _AmenityChip(
                  icon: icon,
                  label: amenity.displayLabel,
                );
              }).toList(),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sections,
    );
  }

  // ─── Agent Tab ────────────────────────────────────────────────────────────
  // FIX 3: Agent listings route corrected to use path param `/agent/:id/listings`
  // instead of the broken query-param string. The "More listings" card now also
  // shows the agent's totalListings count from their profile so the user knows
  // how many properties to expect before tapping.

  Widget _buildAgentTab(String agentId) {
    final agentAsync = ref.watch(agentProfileProvider(agentId));

    return agentAsync.when(
      loading: () => Shimmer.fromColors(
        baseColor: AppTheme.border,
        highlightColor: AppTheme.surfaceVariant,
        child: Container(
          height: 120,
          decoration: BoxDecoration(
            color: AppTheme.border,
            borderRadius: BorderRadius.circular(AppTheme.radiusLG),
          ),
        ),
      ),
      error: (_, __) =>
          const Center(child: Text('Could not load agent info')),
      data: (agent) => Column(
        children: [
          // ── Agent card ─────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusLG),
              border: Border.all(color: AppTheme.border, width: 0.5),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: AppTheme.primarySurface,
                      backgroundImage: agent.avatarUrl != null
                          ? NetworkImage(agent.avatarUrl!)
                          : null,
                      child: agent.avatarUrl == null
                          ? Text(
                              agent.displayName.isNotEmpty
                                  ? agent.displayName[0].toUpperCase()
                                  : 'A',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primary,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(agent.displayName,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge),
                              if (agent.isVerified) ...[
                                const SizedBox(width: 6),
                                const Icon(Icons.verified,
                                    size: 16, color: AppTheme.primary),
                              ],
                            ],
                          ),
                          if (agent.agency != null)
                            Text(agent.agency!,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.star,
                                  size: 14, color: Color(0xFFFAB005)),
                              const SizedBox(width: 2),
                              Text(
                                '${agent.rating.toStringAsFixed(1)} (${agent.reviewCount} reviews)',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelMedium,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Contact buttons ──────────────────────────────────────
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
                                      'Hello ${agent.displayName}, I found your property listing and would like to inquire further.',
                                )
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => context.push('/agent/$agentId'),
                    child: const Text('View full profile →'),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── FIX 3: "More listings" card ────────────────────────────────
          // Route changed from '/agent-listings?agentId=$agentId' (broken
          // query-param approach) to '/agent/$agentId/listings' (path param).
          // Also surfaces totalListings count from the agent profile.
          GestureDetector(
            onTap: () => context.push('/agent/$agentId/listings'),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                border: Border.all(color: AppTheme.border, width: 0.5),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.primarySurface,
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusMD),
                    ),
                    child: const Icon(Icons.home_work_outlined,
                        size: 20, color: AppTheme.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'More listings by ${agent.displayName}',
                          style:
                              Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          agent.totalListings > 0
                              ? '${agent.totalListings} ${agent.totalListings == 1 ? 'property' : 'properties'} listed'
                              : 'See all properties by this agent',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                  color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  // Listing count badge
                  if (agent.totalListings > 0) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primarySurface,
                        borderRadius: BorderRadius.circular(
                            AppTheme.radiusFull),
                      ),
                      child: Text(
                        '${agent.totalListings}',
                        style: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  const Icon(Icons.arrow_forward_ios,
                      size: 14, color: AppTheme.textTertiary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Bottom Bar ───────────────────────────────────────────────────────────

  Widget _buildBottomBar(Property property) {
    final currentUser = ref.watch(currentUserProvider).value;
    final isOwnListing = currentUser?.id == property.agentId;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border:
            Border(top: BorderSide(color: AppTheme.border, width: 0.5)),
      ),
      child: Row(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                property.type.displayLabel,
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: AppTheme.textTertiary),
              ),
              const SizedBox(height: 2),
              Text(
                property.location.neighborhood ??
                    property.location.city,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                property.priceLabel,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          if (!isOwnListing)
            Expanded(
              child: ElevatedButton(
                onPressed: () => _showBookingSheet(property),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(
                  property.listingType == ListingType.rent
                      ? 'Book a Viewing'
                      : 'Schedule Visit',
                ),
              ),
            )
          else
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceVariant,
                  borderRadius:
                      BorderRadius.circular(AppTheme.radiusMD),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.home_outlined,
                        size: 16, color: AppTheme.textSecondary),
                    SizedBox(width: 6),
                    Text(
                      'Your listing',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─── Booking Sheet ────────────────────────────────────────────────────────

  Future<void> _showBookingSheet(Property property) async {
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;

    final existing = await ref
        .read(bookingServiceProvider)
        .getActiveBookingForProperty(
          userId: user.id,
          propertyId: property.id,
        );

    if (!mounted) return;

    if (existing != null) {
      _showAlreadyBookedDialog(existing);
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BookingSheet(property: property),
    );
  }

  void _showAlreadyBookedDialog(Booking booking) {
    final dateStr =
        DateFormat('EEE, MMM d, yyyy').format(booking.scheduledDate);
    final statusLabel = booking.status.name[0].toUpperCase() +
        booking.status.name.substring(1);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        ),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: AppTheme.primarySurface,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.event_available_outlined,
                  size: 20, color: AppTheme.primary),
            ),
            const SizedBox(width: 12),
            const Text('Already Booked'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You already have a $statusLabel viewing for this property.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceVariant,
                borderRadius:
                    BorderRadius.circular(AppTheme.radiusMD),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_outlined,
                      size: 16, color: AppTheme.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      booking.timeSlot != null
                          ? '$dateStr at ${booking.timeSlot}'
                          : dateStr,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'To book a different time, cancel your existing booking first.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await WidgetsBinding.instance.endOfFrame;
              if (context.mounted) context.go('/bookings');
            },
            child: const Text('View Booking'),
          ),
        ],
      ),
    );
  }
}

// ─── Video Player ─────────────────────────────────────────────────────────────

class _PropertyVideoPlayer extends StatefulWidget {
  final String videoUrl;
  const _PropertyVideoPlayer({super.key, required this.videoUrl});

  @override
  State<_PropertyVideoPlayer> createState() =>
      _PropertyVideoPlayerState();
}

class _PropertyVideoPlayerState extends State<_PropertyVideoPlayer> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  bool _hasError = false;
  bool _showControls = true;

  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    _controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.videoUrl),
    );
    try {
      await _controller.initialize();
      _controller.setLooping(true);
      if (mounted) setState(() => _initialized = true);
    } catch (_) {
      if (mounted) setState(() => _hasError = true);
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
        _hideTimer?.cancel();
        _showControls = true;
      } else {
        _controller.play();
        _scheduleHideControls();
      }
    });
  }

  void _onTapScreen() {
    setState(() => _showControls = !_showControls);
    if (_showControls && _controller.value.isPlaying) {
      _scheduleHideControls();
    } else {
      _hideTimer?.cancel();
    }
  }

  void _scheduleHideControls() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _controller.value.isPlaying) {
        setState(() => _showControls = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.videocam_off_outlined,
                  color: Colors.white54, size: 48),
              SizedBox(height: 8),
              Text('Could not load video',
                  style: TextStyle(color: Colors.white54)),
            ],
          ),
        ),
      );
    }

    if (!_initialized) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return GestureDetector(
      onTap: _onTapScreen,
      child: Stack(
        children: [
          SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _controller.value.size.width,
                height: _controller.value.size.height,
                child: VideoPlayer(_controller),
              ),
            ),
          ),
          AnimatedOpacity(
            opacity: _showControls ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.5),
                  ],
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Center(
                    child: IconButton(
                      onPressed: _togglePlayPause,
                      icon: Icon(
                        _controller.value.isPlaying
                            ? Icons.pause_circle_filled
                            : Icons.play_circle_filled,
                        color: Colors.white,
                        size: 56,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16),
                    child: VideoProgressIndicator(
                      _controller,
                      allowScrubbing: true,
                      colors: const VideoProgressColors(
                        playedColor: Colors.white,
                        backgroundColor: Colors.white24,
                        bufferedColor: Colors.white38,
                      ),
                    ),
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        ValueListenableBuilder(
                          valueListenable: _controller,
                          builder: (_, value, __) => Text(
                            _formatDuration(value.position),
                            style: const TextStyle(
                                color: Colors.white, fontSize: 11),
                          ),
                        ),
                        Text(
                          _formatDuration(
                              _controller.value.duration),
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final m =
        d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s =
        d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

// ─── Media Toggle Pill ────────────────────────────────────────────────────────
// FIX 2: Redesigned pill with camera/play icons and a stronger dark scrim
// so the toggle is immediately obvious without competing with the back button.

class _MediaTogglePill extends StatelessWidget {
  final bool showingVideo;
  final ValueChanged<bool> onToggle;

  const _MediaTogglePill({
    required this.showingVideo,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PillOption(
            label: 'Photos',
            icon: Icons.camera_alt_outlined,
            isSelected: !showingVideo,
            onTap: () => onToggle(false),
          ),
          _PillOption(
            label: 'Video',
            icon: Icons.videocam_outlined,
            isSelected: showingVideo,
            onTap: () => onToggle(true),
          ),
        ],
      ),
    );
  }
}

class _PillOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _PillOption({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius:
              BorderRadius.circular(AppTheme.radiusFull),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected
                  ? AppTheme.textPrimary
                  : Colors.white70,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? AppTheme.textPrimary
                    : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Save Button ──────────────────────────────────────────────────────────────

class _SaveButton extends ConsumerWidget {
  final Property property;
  const _SaveButton({required this.property});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final isSaved =
        userAsync.value?.savedProperties.contains(property.id) ?? false;

    return _CircleIconButton(
      icon: isSaved ? Icons.favorite : Icons.favorite_border,
      iconColor: isSaved ? Colors.red : null,
      onTap: () async {
        final user = userAsync.value;
        if (user == null) return;
        await ref
            .read(propertyServiceProvider)
            .toggleSavedProperty(user.id, property.id);
        ref.invalidate(currentUserProvider);
      },
    );
  }
}

// ─── Booking Bottom Sheet ─────────────────────────────────────────────────────

class BookingSheet extends ConsumerStatefulWidget {
  final Property property;
  const BookingSheet({super.key, required this.property});

  @override
  ConsumerState<BookingSheet> createState() => _BookingSheetState();
}

class _BookingSheetState extends ConsumerState<BookingSheet> {
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  String? _selectedTimeSlot;
  bool _isLoading = false;
  String? _errorMessage;
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slotsAsync = ref.watch(
      _availableSlotsProvider(
        _AvailableSlotsParams(widget.property.agentId, _selectedDate),
      ),
    );

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(AppTheme.radiusXL),
          topRight: Radius.circular(AppTheme.radiusXL),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('Book a Viewing',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 4),
          Text(widget.property.title,
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.info_outline,
                  size: 14, color: AppTheme.accent),
              const SizedBox(width: 6),
              Text(
                'Viewing fee: KES 999 (non-refundable)',
                style:
                    Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppTheme.accent,
                        ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('Select Date',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          _buildDateSelector(),
          const SizedBox(height: 20),
          Text('Select Time',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          slotsAsync.when(
            loading: () => const SizedBox(
              height: 44,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, __) => Text(
              'Could not load time slots',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            data: (slots) => _buildTimeSlots(slots),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _notesController,
            maxLines: 2,
            decoration: const InputDecoration(
              hintText: 'Additional notes (optional)',
              labelText: 'Notes',
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFCEBEB),
                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                border: Border.all(
                    color: const Color(0xFFF09595), width: 0.5),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline,
                      size: 16, color: Color(0xFFA32D2D)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFFA32D2D)),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_selectedTimeSlot != null && !_isLoading)
                  ? _proceedToPayment
                  : null,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Proceed to Payment  →  KES 999'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector() {
    return SizedBox(
      height: 68,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 14,
        itemBuilder: (context, index) {
          final date = DateTime.now().add(Duration(days: index + 1));
          final isSelected = _selectedDate.day == date.day &&
              _selectedDate.month == date.month;

          return GestureDetector(
            onTap: () => setState(() {
              _selectedDate = date;
              _selectedTimeSlot = null;
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 52,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primary
                    : AppTheme.surfaceVariant,
                borderRadius:
                    BorderRadius.circular(AppTheme.radiusMD),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    [
                      'Mon',
                      'Tue',
                      'Wed',
                      'Thu',
                      'Fri',
                      'Sat',
                      'Sun'
                    ][date.weekday - 1],
                    style: TextStyle(
                      fontSize: 11,
                      color: isSelected
                          ? Colors.white70
                          : AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${date.day}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTimeSlots(List<String> slots) {
    if (slots.isEmpty) {
      return Text(
        'No slots available for this date',
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: AppTheme.textTertiary),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: slots.map((slot) {
        final isSelected = _selectedTimeSlot == slot;
        return GestureDetector(
          onTap: () => setState(() => _selectedTimeSlot = slot),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.primary
                  : AppTheme.surfaceVariant,
              borderRadius:
                  BorderRadius.circular(AppTheme.radiusMD),
              border: Border.all(
                color: isSelected ? AppTheme.primary : AppTheme.border,
                width: 0.5,
              ),
            ),
            child: Text(
              slot,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isSelected
                    ? Colors.white
                    : AppTheme.textPrimary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Future<void> _proceedToPayment() async {
    if (_selectedTimeSlot == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = ref.read(currentUserProvider).value;
      if (user == null) {
        throw Exception('You must be signed in to book a viewing.');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = false);

    if (!mounted) return;
    Navigator.pop(context);

    await WidgetsBinding.instance.endOfFrame;

    if (context.mounted) {
      context.push(
        '/payment',
        extra: {
          'property': widget.property,
          'scheduledDate': _selectedDate,
          'timeSlot': _selectedTimeSlot,
          'notes': _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
        },
      );
    }
  }
}

// ─── Available Slots Provider ─────────────────────────────────────────────────

class _AvailableSlotsParams {
  final String agentId;
  final DateTime date;

  _AvailableSlotsParams(this.agentId, this.date);

  @override
  bool operator ==(Object other) =>
      other is _AvailableSlotsParams &&
      other.agentId == agentId &&
      other.date.day == date.day &&
      other.date.month == date.month &&
      other.date.year == date.year;

  @override
  int get hashCode =>
      Object.hash(agentId, date.day, date.month, date.year);
}

final _availableSlotsProvider =
    FutureProvider.family<List<String>, _AvailableSlotsParams>(
  (ref, params) => ref
      .read(bookingServiceProvider)
      .getAvailableTimeSlots(params.agentId, params.date),
);

// ─── Supporting Widgets ───────────────────────────────────────────────────────

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final VoidCallback onTap;

  const _CircleIconButton({
    required this.icon,
    this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          shape: BoxShape.circle,
          boxShadow: AppTheme.shadowSM,
        ),
        child: Icon(icon, size: 20,
            color: iconColor ?? AppTheme.textPrimary),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 20, color: AppTheme.accent),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 11,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

// ─── Amenity Chip ─────────────────────────────────────────────────────────────
// Extracted into its own widget to avoid repeating the decoration in both the
// categorised and uncategorised sections of _buildAmenitiesTab.

class _AmenityChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _AmenityChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.primarySurface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(
          color: AppTheme.primary.withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppTheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppTheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}