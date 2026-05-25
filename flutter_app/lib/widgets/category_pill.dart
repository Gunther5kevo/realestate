import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/models/models.dart';

class CategoryPill extends StatelessWidget {
  final PropertyType? type;
  final String? label;
  final IconData? icon;
  final bool isSelected;
  final VoidCallback onTap;

  const CategoryPill({
    super.key,
    this.type,
    this.label,
    this.icon,
    required this.isSelected,
    required this.onTap,
  }) : assert(type != null || label != null, 'Provide either type or label');

  static const _typeIcons = {
    PropertyType.apartment: Icons.apartment_outlined,
    PropertyType.house: Icons.house_outlined,
    PropertyType.villa: Icons.villa_outlined,
    PropertyType.land: Icons.landscape_outlined,
    PropertyType.commercial: Icons.storefront_outlined,
  };

  String get _label {
    if (label != null) return label!;
    final name = type!.name;
    return name[0].toUpperCase() + name.substring(1);
  }

  IconData get _icon {
    if (icon != null) return icon!;
    return _typeIcons[type] ?? Icons.home_outlined;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.border,
            width: isSelected ? 1.5 : 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _icon,
              size: 15,
              color: isSelected ? Colors.white : AppTheme.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              _label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                fontFamily: AppTheme.fontFamily,
                color: isSelected ? Colors.white : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A horizontal scrollable row of [CategoryPill] widgets.
/// Drop this directly into your home screen above the property grid.
class CategoryPillRow extends StatelessWidget {
  final PropertyType? selectedType;
  final ValueChanged<PropertyType?> onTypeSelected;
  final EdgeInsets padding;

  const CategoryPillRow({
    super.key,
    required this.selectedType,
    required this.onTypeSelected,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      child: Row(
        children: [
          // "All" pill
          CategoryPill(
            label: 'All',
            icon: Icons.grid_view_rounded,
            isSelected: selectedType == null,
            onTap: () => onTypeSelected(null),
          ),
          const SizedBox(width: 8),
          ...PropertyType.values.map((t) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: CategoryPill(
                  type: t,
                  isSelected: selectedType == t,
                  onTap: () => onTypeSelected(selectedType == t ? null : t),
                ),
              )),
        ],
      ),
    );
  }
}