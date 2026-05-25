// property_card.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/theme/app_theme.dart';
import '../../core/models/models.dart';

class PropertyCard extends StatelessWidget {
  final Property property;
  final VoidCallback onTap;
  final bool showSaveButton;

  const PropertyCard({super.key, required this.property, required this.onTap, this.showSaveButton = true});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusLG),
          border: Border.all(color: AppTheme.border, width: 0.5),
          boxShadow: AppTheme.shadowSM,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(AppTheme.radiusLG),
                      topRight: Radius.circular(AppTheme.radiusLG),
                    ),
                    child: SizedBox.expand(
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
                      ),
                    ),
                  ),
                  // Type badge
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: property.listingType == ListingType.rent ? AppTheme.accent : AppTheme.primary,
                        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                      ),
                      child: Text(
                        property.listingType == ListingType.rent ? 'Rent' : 'Sale',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  // Save button
                  if (showSaveButton)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), shape: BoxShape.circle),
                        child: const Icon(Icons.favorite_border, size: 16, color: AppTheme.textSecondary),
                      ),
                    ),
                ],
              ),
            ),
            // Info
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    property.priceLabel,
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    property.title,
                    style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 11, color: AppTheme.textTertiary),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          property.location.neighborhood ?? property.location.city,
                          style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 11, color: AppTheme.textTertiary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (property.bedrooms != null || property.areaSqFt != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (property.bedrooms != null)
                          _Spec(icon: Icons.bed_outlined, value: '${property.bedrooms}'),
                        if (property.bathrooms != null)
                          _Spec(icon: Icons.bathtub_outlined, value: '${property.bathrooms}'),
                        if (property.areaSqFt != null)
                          _Spec(icon: Icons.square_foot_outlined, value: '${property.areaSqFt!.toStringAsFixed(0)}ft²'),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Spec extends StatelessWidget {
  final IconData icon;
  final String value;
  const _Spec({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Row(
        children: [
          Icon(icon, size: 11, color: AppTheme.textSecondary),
          const SizedBox(width: 2),
          Text(value, style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 11, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}