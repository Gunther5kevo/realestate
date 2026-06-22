import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../core/models/models.dart';

/// Bottom sheet for filtering properties by listing type, property type,
/// bedrooms (including Bedsitter/Studio), location (county + neighbourhood),
/// price range, and amenities.
///
/// Matches the existing call pattern used by HomeScreen:
///   showModalBottomSheet(
///     builder: (context) => FilterSheet(
///       currentFilter: currentFilter,
///       onApply: (newFilter) { ... },
///     ),
///   );
class FilterSheet extends StatefulWidget {
  final PropertyFilter currentFilter;
  final ValueChanged<PropertyFilter> onApply;

  const FilterSheet({
    super.key,
    required this.currentFilter,
    required this.onApply,
  });

  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  late PropertyFilter _filter;

  final _minPriceCtrl = TextEditingController();
  final _maxPriceCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filter = widget.currentFilter;
    if (_filter.minPrice != null) {
      _minPriceCtrl.text = _filter.minPrice!.toStringAsFixed(0);
    }
    if (_filter.maxPrice != null) {
      _maxPriceCtrl.text = _filter.maxPrice!.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _minPriceCtrl.dispose();
    _maxPriceCtrl.dispose();
    super.dispose();
  }

  void _apply() {
    final minPrice =
        double.tryParse(_minPriceCtrl.text.replaceAll(',', '').trim());
    final maxPrice =
        double.tryParse(_maxPriceCtrl.text.replaceAll(',', '').trim());

    widget.onApply(
      _filter.copyWith(
        minPrice: minPrice,
        maxPrice: maxPrice,
        clearMinPrice: minPrice == null,
        clearMaxPrice: maxPrice == null,
      ),
    );
    Navigator.pop(context);
  }

  void _reset() {
    _minPriceCtrl.clear();
    _maxPriceCtrl.clear();
    // Preserve listingType — it's controlled by HomeScreen's Buy/Rent toggle,
    // not by this sheet, so resetting filters shouldn't clear it.
    setState(() => _filter = PropertyFilter(listingType: _filter.listingType));
  }

  @override
  Widget build(BuildContext context) {
    final neighbourhoods = _filter.county != null
        ? KenyaLocations.neighbourhoodsFor(_filter.county!)
        : <String>[];

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusXL),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Handle + header ──────────────────────────────────────────
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Filter',
                  style: Theme.of(context).textTheme.headlineMedium),
              TextButton(
                onPressed: _reset,
                child: const Text('Reset all'),
              ),
            ],
          ),
          const SizedBox(height: 4),

          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Property type ─────────────────────────────────────
                  _SectionLabel('Property Type'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: PropertyType.values.map((t) {
                      final selected = _filter.type == t;
                      return _FilterChip(
                        label: t.displayLabel,
                        isSelected: selected,
                        onTap: () => setState(
                          () => _filter = _filter.copyWith(
                            type: t,
                            clearType: selected,
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 20),

                  // ── Bedrooms ──────────────────────────────────────────
                  _SectionLabel('Bedrooms'),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: BedroomOption.all.map((opt) {
                        final selected = _filter.minBedrooms == opt.value;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _FilterChip(
                            label: opt.label,
                            isSelected: selected,
                            onTap: () => setState(
                              () => _filter = _filter.copyWith(
                                minBedrooms: opt.value,
                                clearMinBedrooms: selected,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Location — County ─────────────────────────────────
                  _SectionLabel('County'),
                  _DropdownField<String>(
                    hint: 'Select county',
                    value: _filter.county,
                    items: KenyaLocations.allCounties,
                    labelOf: (c) => c,
                    onChanged: (c) => setState(() {
                      _filter = _filter.copyWith(
                        county: c,
                        clearCity: true,
                        clearCounty: c == null,
                      );
                    }),
                  ),

                  // ── Location — Neighbourhood ──────────────────────────
                  if (_filter.county != null &&
                      neighbourhoods.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _SectionLabel('Neighbourhood'),
                    _DropdownField<String>(
                      hint: 'Select neighbourhood',
                      value: _filter.city,
                      items: neighbourhoods,
                      labelOf: (n) => n,
                      onChanged: (n) => setState(() {
                        _filter = _filter.copyWith(
                          city: n,
                          clearCity: n == null,
                        );
                      }),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // ── Price range ───────────────────────────────────────
                  _SectionLabel(
                    _filter.listingType == ListingType.rent
                        ? 'Monthly Rent (KES)'
                        : 'Price Range (KES)',
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _minPriceCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            hintText: 'Min',
                            prefixText: 'KES ',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _maxPriceCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            hintText: 'Max',
                            prefixText: 'KES ',
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),
                  _buildPricePresets(),

                  const SizedBox(height: 20),

                  // ── Amenities ─────────────────────────────────────────
                  _SectionLabel('Amenities'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: PropertyAmenity.values.map((a) {
                      final selected = _filter.amenities.contains(a);
                      return _FilterChip(
                        label: a.displayLabel,
                        isSelected: selected,
                        onTap: () {
                          final updated =
                              List<PropertyAmenity>.from(_filter.amenities);
                          selected ? updated.remove(a) : updated.add(a);
                          setState(() =>
                              _filter = _filter.copyWith(amenities: updated));
                        },
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),

          // ── Apply button ─────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _apply,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(
                _filter.hasActiveFilters
                    ? 'Show Results  ·  ${_filter.activeFilterCount} filter${_filter.activeFilterCount == 1 ? '' : 's'}'
                    : 'Show All Results',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPricePresets() {
    final isRent = _filter.listingType == ListingType.rent;
    final presets = isRent
        ? [
            ('≤ 15K', null, 15000.0),
            ('≤ 30K', null, 30000.0),
            ('≤ 50K', null, 50000.0),
            ('≤ 100K', null, 100000.0),
          ]
        : [
            ('≤ 5M', null, 5000000.0),
            ('≤ 10M', null, 10000000.0),
            ('≤ 20M', null, 20000000.0),
            ('20M+', 20000000.0, null),
          ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: presets.map((p) {
          final label = p.$1;
          final min = p.$2;
          final max = p.$3;
          final isActive = _filter.minPrice == min && _filter.maxPrice == max;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() {
                if (isActive) {
                  _minPriceCtrl.clear();
                  _maxPriceCtrl.clear();
                  _filter = _filter.copyWith(
                    clearMinPrice: true,
                    clearMaxPrice: true,
                  );
                } else {
                  _minPriceCtrl.text = min?.toStringAsFixed(0) ?? '';
                  _maxPriceCtrl.text = max?.toStringAsFixed(0) ?? '';
                  _filter = _filter.copyWith(
                    minPrice: min,
                    maxPrice: max,
                    clearMinPrice: min == null,
                    clearMaxPrice: max == null,
                  );
                }
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isActive
                      ? AppTheme.primarySurface
                      : AppTheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  border: Border.all(
                    color: isActive ? AppTheme.primary : AppTheme.border,
                    width: 0.5,
                  ),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isActive
                        ? AppTheme.primary
                        : AppTheme.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(text, style: Theme.of(context).textTheme.titleLarge),
    );
  }
}

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
          color: isSelected
              ? AppTheme.primarySurface
              : AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.border,
            width: isSelected ? 1.5 : 0.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _DropdownField<T> extends StatelessWidget {
  final String hint;
  final T? value;
  final List<T> items;
  final String Function(T) labelOf;
  final ValueChanged<T?> onChanged;

  const _DropdownField({
    required this.hint,
    required this.value,
    required this.items,
    required this.labelOf,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(
          color: value != null ? AppTheme.primary : AppTheme.border,
          width: value != null ? 1.5 : 0.5,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          hint: Text(
            hint,
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 13,
              color: AppTheme.textSecondary,
            ),
          ),
          style: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 13,
            color: AppTheme.textPrimary,
          ),
          dropdownColor: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          items: [
            DropdownMenuItem<T>(
              value: null,
              child: Text(
                'Any',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 13,
                ),
              ),
            ),
            ...items.map(
              (item) => DropdownMenuItem<T>(
                value: item,
                child: Text(labelOf(item)),
              ),
            ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}