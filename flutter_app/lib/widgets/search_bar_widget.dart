import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class SearchBarWidget extends StatefulWidget {
  final String hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onFilterTap;
  final bool hasActiveFilters;
  final bool readOnly;
  final VoidCallback? onTap;

  const SearchBarWidget({
    super.key,
    this.hintText = 'Search by location or property...',
    this.onChanged,
    this.onFilterTap,
    this.hasActiveFilters = false,
    this.readOnly = false,
    this.onTap,
  });

  @override
  State<SearchBarWidget> createState() => _SearchBarWidgetState();
}

class _SearchBarWidgetState extends State<SearchBarWidget> {
  final _controller = TextEditingController();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final hasText = _controller.text.isNotEmpty;
      if (hasText != _hasText) setState(() => _hasText = hasText);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    widget.onChanged?.call('');
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: widget.readOnly ? widget.onTap : null,
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.surfaceVariant,
                borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                border: Border.all(color: AppTheme.border, width: 0.5),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 14),
                  const Icon(Icons.search_rounded, size: 20, color: AppTheme.textTertiary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: widget.readOnly
                        ? Text(
                            widget.hintText,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppTheme.textTertiary,
                            ),
                          )
                        : TextField(
                            controller: _controller,
                            onChanged: widget.onChanged,
                            style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
                            decoration: InputDecoration(
                              hintText: widget.hintText,
                              hintStyle: const TextStyle(fontSize: 14, color: AppTheme.textTertiary),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                              fillColor: Colors.transparent,
                              filled: false,
                            ),
                          ),
                  ),
                  if (_hasText && !widget.readOnly)
                    GestureDetector(
                      onTap: _clear,
                      child: const Padding(
                        padding: EdgeInsets.only(right: 12),
                        child: Icon(Icons.cancel, size: 18, color: AppTheme.textTertiary),
                      ),
                    )
                  else
                    const SizedBox(width: 14),
                ],
              ),
            ),
          ),
        ),
        if (widget.onFilterTap != null) ...[
          const SizedBox(width: 10),
          GestureDetector(
            onTap: widget.onFilterTap,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: widget.hasActiveFilters ? AppTheme.primary : AppTheme.surfaceVariant,
                shape: BoxShape.circle,
                border: Border.all(
                  color: widget.hasActiveFilters ? AppTheme.primary : AppTheme.border,
                  width: 0.5,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    Icons.tune_rounded,
                    size: 20,
                    color: widget.hasActiveFilters ? Colors.white : AppTheme.textSecondary,
                  ),
                  if (widget.hasActiveFilters)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}