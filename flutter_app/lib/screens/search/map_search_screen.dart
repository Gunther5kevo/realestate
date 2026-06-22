import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/models/models.dart';
import '../../core/providers/providers.dart';

// Shell tab routes — must always use context.go(), never context.push()
const _kShellRoutes = {'/home', '/search', '/saved', '/bookings', '/profile'};

class MapSearchScreen extends ConsumerStatefulWidget {
  final Property? initialProperty;
  const MapSearchScreen({super.key, this.initialProperty});

  @override
  ConsumerState<MapSearchScreen> createState() => _MapSearchScreenState();
}

class _MapSearchScreenState extends ConsumerState<MapSearchScreen> {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  Property? _selectedProperty;
  bool _isLoadingLocation = false;

  static const LatLng _eldoretCenter = LatLng(0.5200, 35.2697);

  BitmapDescriptor _saleIcon = BitmapDescriptor.defaultMarkerWithHue(
    BitmapDescriptor.hueAzure,
  );
  BitmapDescriptor _rentIcon = BitmapDescriptor.defaultMarkerWithHue(
    BitmapDescriptor.hueGreen,
  );

  @override
  void initState() {
    super.initState();
    _loadMarkerIcons();
    if (widget.initialProperty != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedProperty = widget.initialProperty);
      });
    }
  }

  Future<void> _loadMarkerIcons() async {
    _saleIcon =
        BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
    _rentIcon =
        BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
  }

  Future<void> _onCameraIdle() async {
    if (_mapController == null) return;
    final bounds = await _mapController!.getVisibleRegion();
    ref.read(mapBoundsProvider.notifier).state = MapBounds(
      swLat: bounds.southwest.latitude,
      swLng: bounds.southwest.longitude,
      neLat: bounds.northeast.latitude,
      neLng: bounds.northeast.longitude,
    );
  }

  void _rebuildMarkers(List<Property> properties) {
    final newMarkers = properties.map((p) {
      return Marker(
        markerId: MarkerId(p.id),
        position: LatLng(p.location.latitude, p.location.longitude),
        icon: p.listingType == ListingType.rent ? _rentIcon : _saleIcon,
        onTap: () => setState(() => _selectedProperty = p),
        infoWindow: InfoWindow(
          title: p.priceLabel,
          snippet: p.title,
        ),
      );
    }).toSet();

    setState(() {
      _markers
        ..clear()
        ..addAll(newMarkers);
    });
  }

  void _setListingFilter(ListingType? type) {
    final current = ref.read(mapFilterProvider);
    ref.read(mapFilterProvider.notifier).state = current.copyWith(
      clearListingType: type == null,
      listingType: type,
    );
  }

  void _togglePropertyTypeFilter(PropertyType type) {
    final current = ref.read(mapFilterProvider);
    final isSame = current.propertyType == type;
    ref.read(mapFilterProvider.notifier).state = current.copyWith(
      clearPropertyType: isSame,
      propertyType: isSame ? null : type,
    );
  }

  /// Navigation helper that correctly uses go() for shell tab routes
  /// and push() for all other routes, deferred to after the current frame.
  void _navigate(String route) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_kShellRoutes.contains(route)) {
        context.go(route);
      } else {
        context.push(route);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeFilter = ref.watch(mapFilterProvider);

    ref.listen<AsyncValue<List<Property>>>(mapPropertiesProvider, (_, next) {
      next.whenData(_rebuildMarkers);
    });

    return Scaffold(
      body: Stack(
        children: [
          // ── Map ──────────────────────────────────────────────────────────
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: widget.initialProperty != null
                  ? LatLng(
                      widget.initialProperty!.location.latitude,
                      widget.initialProperty!.location.longitude,
                    )
                  : _eldoretCenter,
              zoom: widget.initialProperty != null ? 15 : 13,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _onCameraIdle();
              });
            },
            onCameraIdle: _onCameraIdle,
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            mapType: MapType.normal,
            onTap: (_) => setState(() => _selectedProperty = null),
            padding: EdgeInsets.only(
              bottom: _selectedProperty != null ? 220 : 0,
            ),
          ),

          // ── Loading indicator ────────────────────────────────────────────
          _MapLoadingOverlay(
            isLoading: ref.watch(mapPropertiesProvider).isLoading,
          ),

          // ── Top bar ──────────────────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      _CircleButton(
                        icon: Icons.arrow_back,
                        onTap: () => context.pop(),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          // FIX: _navigate uses go() for shell tab routes,
                          // preventing the duplicate page key crash.
                          onTap: () => _navigate('/search'),
                          child: Container(
                            height: 44,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: AppTheme.surface,
                              borderRadius: BorderRadius.circular(
                                  AppTheme.radiusFull),
                              boxShadow: AppTheme.shadowMD,
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.search,
                                    size: 18,
                                    color: AppTheme.textSecondary),
                                const SizedBox(width: 8),
                                Text(
                                  'Search this area',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                          color: AppTheme.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Filter chips ────────────────────────────────────────
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'All',
                        isSelected: activeFilter.listingType == null,
                        onTap: () => _setListingFilter(null),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'For Sale',
                        isSelected:
                            activeFilter.listingType == ListingType.sale,
                        onTap: () => _setListingFilter(ListingType.sale),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'For Rent',
                        isSelected:
                            activeFilter.listingType == ListingType.rent,
                        onTap: () => _setListingFilter(ListingType.rent),
                      ),
                      const SizedBox(width: 8),
                      ...PropertyType.values.map((t) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _FilterChip(
                              label: t.displayLabel,
                              isSelected: activeFilter.propertyType == t,
                              onTap: () => _togglePropertyTypeFilter(t),
                            ),
                          )),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── My Location button ──────────────────────────────────────────
          Positioned(
            right: 16,
            bottom: _selectedProperty != null ? 240 : 24,
            child: _CircleButton(
              icon: Icons.my_location,
              color: AppTheme.primary,
              onTap: _goToMyLocation,
              isLoading: _isLoadingLocation,
            ),
          ),

          // ── Legend ──────────────────────────────────────────────────────
          Positioned(
            left: 16,
            bottom: _selectedProperty != null ? 240 : 24,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                boxShadow: AppTheme.shadowSM,
              ),
              child: Row(
                children: [
                  _LegendItem(
                      color: const Color(0xFF4285F4), label: 'For Sale'),
                  const SizedBox(width: 12),
                  _LegendItem(color: AppTheme.accent, label: 'For Rent'),
                ],
              ),
            ),
          ),

          // ── Property preview card ───────────────────────────────────────
          if (_selectedProperty != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildPropertyPreview(_selectedProperty!),
            ),
        ],
      ),
    );
  }

  Widget _buildPropertyPreview(Property property) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        boxShadow: AppTheme.shadowLG,
      ),
      child: Row(
        children: [
          // Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            child: Image.network(
              property.imageUrls.isNotEmpty
                  ? property.imageUrls.first
                  : 'https://images.unsplash.com/photo-1564013799919-ab600027ffc6?w=200',
              width: 80,
              height: 80,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 80,
                height: 80,
                color: AppTheme.surfaceVariant,
                child: const Icon(Icons.home_outlined,
                    color: AppTheme.textSecondary),
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  property.title,
                  style: Theme.of(context).textTheme.titleLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined,
                        size: 12, color: AppTheme.textSecondary),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Text(
                        property.location.neighborhood ??
                            property.location.city,
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      property.priceLabel,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(color: AppTheme.primary),
                    ),
                    const SizedBox(width: 8),
                    if (property.bedrooms != null)
                      Text('${property.bedrooms} bd',
                          style: Theme.of(context).textTheme.bodySmall),
                    if (property.bathrooms != null) ...[
                      const SizedBox(width: 6),
                      Text('${property.bathrooms} ba',
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Navigate to detail — non-shell route, push() is correct
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios, size: 18),
            onPressed: () => _navigate('/property/${property.id}'),
          ),
        ],
      ),
    );
  }

  Future<void> _goToMyLocation() async {
    setState(() => _isLoadingLocation = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission denied')),
          );
        }
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      await _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(pos.latitude, pos.longitude),
          14,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not get location: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}

// ─── Map Loading Overlay ──────────────────────────────────────────────────────
class _MapLoadingOverlay extends StatelessWidget {
  final bool isLoading;
  const _MapLoadingOverlay({required this.isLoading});

  @override
  Widget build(BuildContext context) {
    if (!isLoading) return const SizedBox.shrink();
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: LinearProgressIndicator(
        backgroundColor: AppTheme.border,
        color: AppTheme.primary,
        minHeight: 3,
      ),
    );
  }
}

// ─── Circle Button ────────────────────────────────────────────────────────────
class _CircleButton extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final VoidCallback onTap;
  final bool isLoading;

  const _CircleButton({
    required this.icon,
    required this.onTap,
    this.color,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        shape: BoxShape.circle,
        boxShadow: AppTheme.shadowMD,
      ),
      child: isLoading
          ? const Padding(
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : IconButton(
              icon: Icon(icon, size: 20, color: color),
              onPressed: onTap,
            ),
    );
  }
}

// ─── Filter Chip ──────────────────────────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
          boxShadow: AppTheme.shadowSM,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.white : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ─── Legend Item ──────────────────────────────────────────────────────────────
class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}