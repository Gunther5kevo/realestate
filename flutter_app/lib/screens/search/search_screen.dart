import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/theme/app_theme.dart';
import '../../core/models/models.dart';
import '../../core/providers/providers.dart';
import '../../widgets/property_card.dart';
import '../../widgets/filter_sheet.dart';

// ─── Local scoped provider for search screen ──────────────────────────────────
class _SearchParams {
  final String query;
  final PropertyFilter filter;
  const _SearchParams(this.query, this.filter);

  @override
  bool operator ==(Object other) =>
      other is _SearchParams &&
      other.query == query &&
      other.filter == filter;

  @override
  int get hashCode => Object.hash(query, filter);
}

final _searchParamsProvider =
    FutureProvider.autoDispose.family<List<Property>, _SearchParams>(
  (ref, params) => ref
      .read(propertyServiceProvider)
      .searchProperties(params.query, filter: params.filter),
);

// ─── Screen ───────────────────────────────────────────────────────────────────

class SearchScreen extends ConsumerStatefulWidget {
  /// When set, the screen opens pre-filtered to this agent's listings.
  /// Used by the "More listings by this agent" shortcut in PropertyDetailScreen.
  final String? initialAgentId;

  const SearchScreen({super.key, this.initialAgentId});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  PropertyFilter _filter = const PropertyFilter();
  String _query = '';

  @override
  void initState() {
    super.initState();

    // Pre-seed the query with the agent ID so searchProperties can filter by it.
    // We store it in _query (which feeds the search service) and also show it
    // in the text field as a read-only hint via the controller.
    if (widget.initialAgentId != null) {
      _query = widget.initialAgentId!;
      _searchController.text = '';        // keep text field blank — agent ID is
                                          // not a human-readable search term
      _filter = PropertyFilter(
        searchQuery: widget.initialAgentId,
      );
    }

    _searchController.addListener(() {
      final text = _searchController.text;
      if (text != _query) {
        setState(() => _query = text);
      }
    });

    // Only auto-focus the keyboard when there is no pre-seeded agent filter.
    if (widget.initialAgentId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // True when we were opened from a "more listings by agent" tap.
  bool get _isAgentView => widget.initialAgentId != null;

  @override
  Widget build(BuildContext context) {
    final params = _SearchParams(_query, _filter);
    final resultsAsync = ref.watch(_searchParamsProvider(params));

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          if (_filter.hasActiveFilters) _buildFilterChips(),
          Expanded(
            // When opened from an agent tap we skip the empty-search prompt
            // and go straight to results (or loading/error).
            child: (!_isAgentView && _query.isEmpty && !_filter.hasActiveFilters)
                ? _buildEmptySearch()
                : resultsAsync.when(
                    loading: () => _buildLoadingGrid(),
                    error: (e, _) => _buildError(e),
                    data: (properties) => properties.isEmpty
                        ? _buildNoResults()
                        : _buildResults(properties),
                  ),
          ),
        ],
      ),
    );
  }

  // ─── App Bar ───────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppTheme.surface,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => context.pop(),
      ),
      title: _isAgentView
          // Agent-filter view: show a static title instead of a text field
          ? Text(
              'Agent Listings',
              style: Theme.of(context).textTheme.titleLarge,
            )
          : TextField(
              controller: _searchController,
              focusNode: _focusNode,
              style: Theme.of(context).textTheme.bodyLarge,
              decoration: InputDecoration(
                hintText: 'Search by location, property name...',
                hintStyle:
                    Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppTheme.textTertiary,
                        ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                fillColor: Colors.transparent,
                filled: false,
                contentPadding: EdgeInsets.zero,
                isDense: true,
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
              ),
            ),
      actions: [
        // Hide the filter button in agent-view to keep the UX focused
        if (!_isAgentView)
          IconButton(
            icon: Icon(
              Icons.tune_rounded,
              color: _filter.hasActiveFilters
                  ? AppTheme.primary
                  : AppTheme.textSecondary,
            ),
            onPressed: _showFilters,
          ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(0.5),
        child: Container(height: 0.5, color: AppTheme.border),
      ),
    );
  }

  // ─── Filter Chips ──────────────────────────────────────────────────────────

  Widget _buildFilterChips() {
    return Container(
      height: 48,
      color: AppTheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          if (_filter.listingType != null)
            _ActiveFilterChip(
              label: _filter.listingType == ListingType.rent
                  ? 'For Rent'
                  : 'For Sale',
              onRemove: () => setState(
                () => _filter = _filter.copyWith(listingType: null),
              ),
            ),
          if (_filter.type != null)
            _ActiveFilterChip(
              label: _filter.type!.displayLabel,
              onRemove: () => setState(
                  () => _filter = _filter.copyWith(clearType: true)),
            ),
          if (_filter.minPrice != null || _filter.maxPrice != null)
            _ActiveFilterChip(
              label: 'Price range',
              onRemove: () => setState(
                () => _filter = _filter.copyWith(
                  clearMinPrice: true,
                  clearMaxPrice: true,
                ),
              ),
            ),
          if (_filter.minBedrooms != null)
            _ActiveFilterChip(
              label: '${_filter.minBedrooms}+ beds',
              onRemove: () => setState(
                () => _filter = _filter.copyWith(clearMinBedrooms: true),
              ),
            ),
        ],
      ),
    );
  }

  // ─── States ────────────────────────────────────────────────────────────────

  Widget _buildEmptySearch() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: AppTheme.primarySurface,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.search,
                size: 36,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Search for properties',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Try "Elgon View apartment",\n"West Indies studio" or "3 bedroom Kapsoya"',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.search_off,
              size: 64,
              color: AppTheme.textTertiary,
            ),
            const SizedBox(height: 16),
            Text(
              _isAgentView
                  ? 'No listings found for this agent'
                  : 'No properties found',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 8),
            Text(
              _isAgentView
                  ? 'This agent has no active listings at the moment'
                  : 'Try different keywords or adjust your filters',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textTertiary,
                  ),
              textAlign: TextAlign.center,
            ),
            if (!_isAgentView && _filter.hasActiveFilters) ...[
              const SizedBox(height: 20),
              TextButton(
                onPressed: () =>
                    setState(() => _filter = const PropertyFilter()),
                child: const Text('Clear all filters'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.72,
      ),
      itemCount: 6,
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: AppTheme.border,
        highlightColor: AppTheme.surfaceVariant,
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.border,
            borderRadius: BorderRadius.circular(AppTheme.radiusLG),
          ),
        ),
      ),
    );
  }

  Widget _buildError(Object e) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline,
              size: 48, color: AppTheme.textTertiary),
          const SizedBox(height: 12),
          Text(
            'Something went wrong',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => setState(() {}),
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }

  // ─── Results ───────────────────────────────────────────────────────────────

  Widget _buildResults(List<Property> properties) {
    return Column(
      children: [
        Container(
          color: AppTheme.surface,
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
          child: Row(
            children: [
              Text(
                '${properties.length} ${properties.length == 1 ? 'property' : 'properties'} found',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
              ),
              const Spacer(),
              if (!_isAgentView)
                TextButton.icon(
                  icon: const Icon(Icons.map_outlined, size: 16),
                  label: const Text('Map view'),
                  onPressed: () => context.push('/map'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.72,
            ),
            itemCount: properties.length,
            itemBuilder: (context, i) => PropertyCard(
              property: properties[i],
              onTap: () => context.push('/property/${properties[i].id}'),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Filter Sheet ──────────────────────────────────────────────────────────

  void _showFilters() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FilterSheet(
        currentFilter: _filter,
        onApply: (newFilter) => setState(() => _filter = newFilter),
      ),
    );
  }
}

// ─── Active Filter Chip ───────────────────────────────────────────────────────

class _ActiveFilterChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;

  const _ActiveFilterChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.only(left: 12, right: 6, top: 4, bottom: 4),
      decoration: BoxDecoration(
        color: AppTheme.primarySurface,
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        border: Border.all(
          color: AppTheme.primary.withOpacity(0.3),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close,
                size: 11,
                color: AppTheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}