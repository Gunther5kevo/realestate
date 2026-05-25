import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/models/models.dart';

class FilterSheet extends StatefulWidget {
  final PropertyFilter currentFilter;
  final void Function(PropertyFilter) onApply;

  const FilterSheet({super.key, required this.currentFilter, required this.onApply});

  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  late PropertyFilter _filter;
  RangeValues _priceRange = const RangeValues(0, 200000000);

  @override
  void initState() {
    super.initState();
    _filter = widget.currentFilter;
    _priceRange = RangeValues(
      _filter.minPrice ?? 0,
      _filter.maxPrice ?? 200000000,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(AppTheme.radiusXL),
          topRight: Radius.circular(AppTheme.radiusXL),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(2))),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Filters', style: Theme.of(context).textTheme.headlineMedium),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _filter = const PropertyFilter();
                      _priceRange = const RangeValues(0, 200000000);
                    });
                  },
                  child: const Text('Clear all'),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Listing type
                  _SectionLabel(label: 'Listing Type'),
                  Row(
                    children: [
                      _FilterChip(label: 'For Sale', isSelected: _filter.listingType == ListingType.sale, onTap: () => setState(() => _filter = _filter.copyWith(listingType: ListingType.sale))),
                      const SizedBox(width: 8),
                      _FilterChip(label: 'For Rent', isSelected: _filter.listingType == ListingType.rent, onTap: () => setState(() => _filter = _filter.copyWith(listingType: ListingType.rent))),
                    ],
                  ),
                  _SectionLabel(label: 'Property Type'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: PropertyType.values.map((t) => _FilterChip(
                      label: t.name[0].toUpperCase() + t.name.substring(1),
                      isSelected: _filter.type == t,
                      onTap: () => setState(() => _filter = _filter.copyWith(type: t)),
                    )).toList(),
                  ),
                  _SectionLabel(label: 'Price Range'),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_formatPrice(_priceRange.start), style: Theme.of(context).textTheme.bodySmall),
                      Text(_formatPrice(_priceRange.end), style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                  RangeSlider(
                    values: _priceRange,
                    min: 0,
                    max: 200000000,
                    divisions: 100,
                    activeColor: AppTheme.primary,
                    inactiveColor: AppTheme.border,
                    onChanged: (v) => setState(() => _priceRange = v),
                    onChangeEnd: (v) => setState(() => _filter = _filter.copyWith(minPrice: v.start, maxPrice: v.end)),
                  ),
                  _SectionLabel(label: 'Bedrooms'),
                  Row(
                    children: [
                      _FilterChip(label: 'Any', isSelected: _filter.minBedrooms == null, onTap: () => setState(() => _filter = _filter.copyWith())),
                      const SizedBox(width: 6),
                      ...['1', '2', '3', '4', '5+'].map((b) {
                        final n = b == '5+' ? 5 : int.parse(b);
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: _FilterChip(
                            label: b,
                            isSelected: _filter.minBedrooms == n,
                            onTap: () => setState(() => _filter = _filter.copyWith(minBedrooms: n)),
                          ),
                        );
                      }),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  widget.onApply(_filter);
                  Navigator.pop(context);
                },
                child: const Text('Apply Filters'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatPrice(double v) {
    if (v >= 1000000) return 'KES ${(v / 1000000).toStringAsFixed(0)}M';
    if (v >= 1000) return 'KES ${(v / 1000).toStringAsFixed(0)}K';
    return 'KES ${v.toStringAsFixed(0)}';
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Text(label, style: Theme.of(context).textTheme.headlineSmall),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primarySurface : AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
          border: Border.all(color: isSelected ? AppTheme.primary : AppTheme.border, width: isSelected ? 1.5 : 0.5),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: isSelected ? AppTheme.primary : AppTheme.textSecondary),
        ),
      ),
    );
  }
}