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
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _imageController.dispose();
    super.dispose();
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
                SliverToBoxAdapter(child: _buildMediaSection(property)),
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
                          onTap: () {},
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

    // Single source of truth — both the switcher and all overlays use this
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
                    // Prefix ensures key is always different from 'images'
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                ),
                child: Text(
                  '${_currentImageIndex + 1}/${images.length}',
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ),

          // ── Photo / Video toggle pill (only when video exists) ────────
          if (hasVideo)
            Positioned(
              top: 16,
              left: 0,
              right: 0,
              child: Center(
                child: _MediaTogglePill(
                  showingVideo: _showingVideo,
                  onToggle: (val) => setState(() => _showingVideo = val),
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
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
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
              borderRadius: BorderRadius.circular(AppTheme.radiusFull),
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
    switch (_tabController.index) {
      case 1:
        return _buildAmenitiesTab(property);
      case 2:
        return _buildAgentTab(property.agentId);
      default:
        return _buildOverviewTab(property);
    }
  }

  Widget _buildOverviewTab(Property property) {
    final details = <String, String>{
      if (property.type != PropertyType.land)
        'Type': property.type.displayLabel,
      'Status': property.status.displayLabel,
      if (property.bedroomLabel.isNotEmpty)
        'Rooms': property.bedroomLabel,
      if (property.floors != null) 'Floors': '${property.floors}',
      if (property.yearBuilt != null) 'Built in': '${property.yearBuilt}',
      'Listing': property.listingType == ListingType.rent ? 'Rental' : 'Sale',
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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

  Widget _buildAmenitiesTab(Property property) {
    const amenityIcons = {
      // Security & Access
      PropertyAmenity.guardhouse: Icons.security_outlined,
      PropertyAmenity.cctv: Icons.videocam_outlined,
      PropertyAmenity.electricFence: Icons.bolt_outlined,
      PropertyAmenity.intercom: Icons.phone_callback_outlined,
      // Water & Power
      PropertyAmenity.borehole: Icons.water_drop_outlined,
      PropertyAmenity.waterTank: Icons.propane_tank_outlined,
      PropertyAmenity.generator: Icons.power_outlined,
      PropertyAmenity.solar: Icons.solar_power_outlined,
      // Connectivity
      PropertyAmenity.fibre: Icons.wifi_outlined,
      // Parking & Transport
      PropertyAmenity.parking: Icons.local_parking_outlined,
      PropertyAmenity.visitorParking: Icons.directions_car_outlined,
      // Living & Comfort
      PropertyAmenity.furnished: Icons.chair_outlined,
      PropertyAmenity.airConditioning: Icons.ac_unit_outlined,
      PropertyAmenity.pool: Icons.pool_outlined,
      PropertyAmenity.gym: Icons.fitness_center_outlined,
      // Outdoor & Community
      PropertyAmenity.balcony: Icons.balcony_outlined,
      PropertyAmenity.garden: Icons.yard_outlined,
      PropertyAmenity.gatedCommunity: Icons.holiday_village_outlined,
      PropertyAmenity.playArea: Icons.toys_outlined,
      // Extra rooms
      PropertyAmenity.dsq: Icons.home_work_outlined,
      PropertyAmenity.elevator: Icons.elevator_outlined,
      // Pet
      PropertyAmenity.petFriendly: Icons.pets_outlined,
    };

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.1,
      ),
      itemCount: PropertyAmenity.values.length,
      itemBuilder: (context, index) {
        final amenity = PropertyAmenity.values[index];
        final icon = amenityIcons[amenity] ?? Icons.check_circle_outline;
        final hasAmenity = property.amenities.contains(amenity);

        return Container(
          decoration: BoxDecoration(
            color: hasAmenity
                ? AppTheme.primarySurface
                : AppTheme.surfaceVariant,
            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            border: Border.all(
              color: hasAmenity
                  ? AppTheme.primary.withValues(alpha: 0.2)
                  : AppTheme.border,
              width: 0.5,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 22,
                color:
                    hasAmenity ? AppTheme.primary : AppTheme.textTertiary,
              ),
              const SizedBox(height: 4),
              Text(
                amenity.displayLabel,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: hasAmenity
                      ? AppTheme.primary
                      : AppTheme.textTertiary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── Agent Tab ────────────────────────────────────────────────────────────

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
      data: (agent) => Container(
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
                            style:
                                Theme.of(context).textTheme.bodySmall),
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

            // ── Contact buttons ──────────────────────────────────────────
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
            TextButton(
              onPressed: () => context.push('/agent/$agentId'),
              child: const Text('View full profile →'),
            ),
          ],
        ),
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
        border: Border(top: BorderSide(color: AppTheme.border, width: 0.5)),
      ),
      child: Row(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                property.priceLabel,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppTheme.primary,
                    ),
              ),
              Text(
                property.listingType == ListingType.rent
                    ? 'Monthly rent'
                    : 'Total price',
                style: Theme.of(context).textTheme.labelSmall,
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
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
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
                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
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
  State<_PropertyVideoPlayer> createState() => _PropertyVideoPlayerState();
}

class _PropertyVideoPlayerState extends State<_PropertyVideoPlayer> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  bool _hasError = false;
  bool _showControls = true;

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
    _controller.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    setState(() {
      _controller.value.isPlaying
          ? _controller.pause()
          : _controller.play();
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
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
      onTap: _toggleControls,
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
                    padding: const EdgeInsets.symmetric(horizontal: 16),
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
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                          _formatDuration(_controller.value.duration),
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
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

// ─── Media Toggle Pill ────────────────────────────────────────────────────────

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
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PillOption(
            label: 'Photos',
            icon: Icons.photo_outlined,
            isSelected: !showingVideo,
            onTap: () => onToggle(false),
          ),
          _PillOption(
            label: 'Video',
            icon: Icons.play_circle_outline,
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? AppTheme.textPrimary : Colors.white70,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color:
                    isSelected ? AppTheme.textPrimary : Colors.white70,
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
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
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
                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
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
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.primary
                  : AppTheme.surfaceVariant,
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
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
                color:
                    isSelected ? Colors.white : AppTheme.textPrimary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Future<void> _proceedToPayment() async {
    if (_selectedTimeSlot == null) return;

    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;
    setState(() => _isLoading = false);

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
        child:
            Icon(icon, size: 20, color: iconColor ?? AppTheme.textPrimary),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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