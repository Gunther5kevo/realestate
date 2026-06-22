import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/app_theme.dart';
import '../../core/models/models.dart';
import '../../core/providers/providers.dart';

class AddListingScreen extends ConsumerStatefulWidget {
  final String? editPropertyId;
  const AddListingScreen({super.key, this.editPropertyId});
  @override
  ConsumerState<AddListingScreen> createState() => _AddListingScreenState();
}

class _AddListingScreenState extends ConsumerState<AddListingScreen> {
  final _formKey = GlobalKey<FormState>();
  int _step = 0;
  bool _isLoading = false;
  bool _isEditMode = false;

  // Controllers
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _priceController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _bedroomsController = TextEditingController();
  final _bathroomsController = TextEditingController();
  final _areaController = TextEditingController();

  // Coords from geocoded address
  double _latitude = -1.286389;
  double _longitude = 36.817223;
  String _state = 'Nairobi County';
  String _country = 'Kenya';

  PropertyType _type = PropertyType.apartment;
  ListingType _listingType = ListingType.sale;
  List<PropertyAmenity> _amenities = [];
  final List<File> _images = [];
  List<String> _existingImageUrls = [];
  File? _video;
  String? _existingVideoUrl;

  final _steps = ['Basic Info', 'Details', 'Media', 'Review'];

  @override
  void initState() {
    super.initState();
    if (widget.editPropertyId != null) {
      _isEditMode = true;
      _loadExistingProperty();
    }
  }

  Future<void> _loadExistingProperty() async {
    setState(() => _isLoading = true);
    try {
      final property = await ref
          .read(propertyServiceProvider)
          .getProperty(widget.editPropertyId!);
      if (mounted) {
        setState(() {
          _titleController.text = property.title;
          _descController.text = property.description;
          _priceController.text = property.price.toStringAsFixed(0);
          _addressController.text = property.location.address;
          _cityController.text = property.location.city;
          _bedroomsController.text = property.bedrooms?.toString() ?? '';
          _bathroomsController.text = property.bathrooms?.toString() ?? '';
          _areaController.text = property.areaSqFt?.toString() ?? '';
          _type = property.type;
          _listingType = property.listingType;
          _amenities = List<PropertyAmenity>.from(property.amenities);
          _existingImageUrls = List<String>.from(property.imageUrls);
          _existingVideoUrl = property.videoUrl;
          _latitude = property.location.latitude;
          _longitude = property.location.longitude;
          _state = property.location.state;
          _country = property.location.country;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to load listing: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _priceController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _bedroomsController.dispose();
    _bathroomsController.dispose();
    _areaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Listing' : 'Add Listing'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (_step + 1) / _steps.length,
            backgroundColor: AppTheme.border,
            color: AppTheme.primary,
          ),
        ),
      ),
      body: _isLoading && _isEditMode
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Step indicator
                Container(
                  color: AppTheme.surface,
                  padding: const EdgeInsets.symmetric(
                      vertical: 12, horizontal: 16),
                  child: Row(
                    children: List.generate(
                      _steps.length,
                      (i) => Expanded(
                        child: Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: i <= _step
                                    ? AppTheme.primary
                                    : AppTheme.surfaceVariant,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: i < _step
                                    ? const Icon(Icons.check,
                                        size: 14, color: Colors.white)
                                    : Text(
                                        '${i + 1}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: i == _step
                                              ? Colors.white
                                              : AppTheme.textSecondary,
                                        ),
                                      ),
                              ),
                            ),
                            if (i < _steps.length - 1)
                              Expanded(
                                child: Container(
                                  height: 1,
                                  color: i < _step
                                      ? AppTheme.primary
                                      : AppTheme.border,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                Expanded(
                  child: Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: [
                        _buildStep0(),
                        _buildStep1(),
                        _buildStep2(),
                        _buildStep3(),
                      ][_step],
                    ),
                  ),
                ),

                // Navigation buttons
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    border: Border(
                        top: BorderSide(
                            color: AppTheme.border, width: 0.5)),
                  ),
                  child: Row(
                    children: [
                      if (_step > 0)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => setState(() => _step--),
                            child: const Text('Back'),
                          ),
                        ),
                      if (_step > 0) const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _isLoading
                              ? null
                              : (_step < _steps.length - 1
                                  ? _nextStep
                                  : _submit),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white),
                                )
                              : Text(
                                  _step < _steps.length - 1
                                      ? 'Continue'
                                      : _isEditMode
                                          ? 'Save Changes'
                                          : 'Submit for Review',
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  // ─── Step 0: Basic Info ───────────────────────────────────────────────────

  Widget _buildStep0() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Basic Information',
            style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 20),
        TextFormField(
          controller: _titleController,
          decoration:
              const InputDecoration(labelText: 'Property Title *'),
          validator: (v) => v != null && v.length >= 5
              ? null
              : 'Enter a descriptive title',
        ),
        const SizedBox(height: 16),
        Text('Listing Type',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _ChoiceChip(
                label: 'For Sale',
                isSelected: _listingType == ListingType.sale,
                onTap: () =>
                    setState(() => _listingType = ListingType.sale),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ChoiceChip(
                label: 'For Rent',
                isSelected: _listingType == ListingType.rent,
                onTap: () =>
                    setState(() => _listingType = ListingType.rent),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text('Property Type',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: PropertyType.values
              .map((t) => _ChoiceChip(
                    // Uses the displayLabel extension so labels match the
                    // filter sheet exactly (e.g. "Bedsitter", not "Bedsitter"
                    // mangled, and proper spacing for multi-word types).
                    label: t.displayLabel,
                    isSelected: _type == t,
                    onTap: () => setState(() => _type = t),
                  ))
              .toList(),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _priceController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: _listingType == ListingType.rent
                ? 'Monthly Rent (KES) *'
                : 'Price (KES) *',
            prefixText: 'KES ',
          ),
          validator: (v) => v != null && double.tryParse(v) != null
              ? null
              : 'Enter a valid price',
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _descController,
          maxLines: 4,
          decoration: const InputDecoration(
              labelText: 'Description *',
              alignLabelWithHint: true),
          validator: (v) => v != null && v.length >= 30
              ? null
              : 'Minimum 30 characters',
        ),
      ],
    );
  }

  // ─── Step 1: Property Details ─────────────────────────────────────────────

  Widget _buildStep1() {
    // Single-room types (bedsitter/studio) don't need a bedroom count field.
    final showBedrooms = !_type.isSingleRoom;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Property Details',
            style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 20),
        TextFormField(
          controller: _addressController,
          decoration: InputDecoration(
            labelText: 'Street Address *',
            prefixIcon: const Icon(Icons.location_on_outlined),
            suffixIcon: IconButton(
              icon: const Icon(Icons.my_location, size: 18),
              tooltip: 'Lookup coordinates',
              onPressed: _geocodeAddress,
            ),
          ),
          validator: (v) =>
              v != null && v.isNotEmpty ? null : 'Required',
        ),
        const SizedBox(height: 4),
        Text(
          'Lat: ${_latitude.toStringAsFixed(6)}, Lng: ${_longitude.toStringAsFixed(6)}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textTertiary, fontSize: 11),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _cityController,
          decoration: const InputDecoration(
              labelText: 'City / Neighbourhood *'),
          validator: (v) =>
              v != null && v.isNotEmpty ? null : 'Required',
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            if (showBedrooms)
              Expanded(
                child: TextFormField(
                  controller: _bedroomsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Bedrooms',
                      prefixIcon: Icon(Icons.bed_outlined)),
                ),
              ),
            if (showBedrooms) const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _bathroomsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Bathrooms',
                    prefixIcon: Icon(Icons.bathtub_outlined)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _areaController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
              labelText: 'Area (sq ft)',
              prefixIcon: Icon(Icons.square_foot_outlined)),
        ),
        const SizedBox(height: 24),
        Text('Amenities',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: PropertyAmenity.values.map((a) {
            final isSelected = _amenities.contains(a);
            return GestureDetector(
              onTap: () => setState(() =>
                  isSelected ? _amenities.remove(a) : _amenities.add(a)),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primarySurface
                      : AppTheme.surfaceVariant,
                  borderRadius:
                      BorderRadius.circular(AppTheme.radiusFull),
                  border: Border.all(
                      color: isSelected
                          ? AppTheme.primary
                          : AppTheme.border,
                      width: 0.5),
                ),
                child: Text(
                  // displayLabel extension renders proper spacing for
                  // camelCase enum values (e.g. "Gated Estate" instead of
                  // "GatedCommunity", "Pet Friendly" instead of "PetFriendly").
                  a.displayLabel,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isSelected
                          ? AppTheme.primary
                          : AppTheme.textSecondary),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ─── Step 2: Photos & Video ───────────────────────────────────────────────

  Widget _buildStep2() {
    final totalImages = _existingImageUrls.length + _images.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Photos & Video',
            style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 4),
        Text('Add at least 3 photos. Video is optional.',
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 20),

        Text('Photos ($totalImages)',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8),
          itemCount:
              _existingImageUrls.length + _images.length + 1,
          itemBuilder: (_, i) {
            if (i == _existingImageUrls.length + _images.length) {
              return GestureDetector(
                onTap: _pickImages,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceVariant,
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusMD),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_photo_alternate_outlined,
                          size: 28, color: AppTheme.textSecondary),
                      SizedBox(height: 4),
                      Text('Add Photo',
                          style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
              );
            }
            if (i < _existingImageUrls.length) {
              return _MediaTile(
                isFirst: i == 0,
                onRemove: () =>
                    setState(() => _existingImageUrls.removeAt(i)),
                child: ClipRRect(
                  borderRadius:
                      BorderRadius.circular(AppTheme.radiusMD),
                  child: Image.network(_existingImageUrls[i],
                      fit: BoxFit.cover),
                ),
              );
            }
            final fileIndex = i - _existingImageUrls.length;
            return _MediaTile(
              isFirst: i == 0,
              onRemove: () =>
                  setState(() => _images.removeAt(fileIndex)),
              child: ClipRRect(
                borderRadius:
                    BorderRadius.circular(AppTheme.radiusMD),
                child:
                    Image.file(_images[fileIndex], fit: BoxFit.cover),
              ),
            );
          },
        ),

        const SizedBox(height: 24),
        Text('Property Video',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text('Optional — short walkthrough (max 2 min)',
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 10),
        if (_video != null || _existingVideoUrl != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primarySurface,
              borderRadius:
                  BorderRadius.circular(AppTheme.radiusMD),
              border: Border.all(
                  color: AppTheme.primary.withValues(alpha: 0.3),
                  width: 0.5),
            ),
            child: Row(
              children: [
                const Icon(Icons.videocam_outlined,
                    color: AppTheme.primary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _video != null
                        ? _video!.path.split('/').last
                        : 'Existing video',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppTheme.primary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() {
                    _video = null;
                    _existingVideoUrl = null;
                  }),
                  child: const Icon(Icons.close,
                      size: 16, color: AppTheme.primary),
                ),
              ],
            ),
          )
        else
          GestureDetector(
            onTap: _pickVideo,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceVariant,
                borderRadius:
                    BorderRadius.circular(AppTheme.radiusMD),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.video_call_outlined,
                      size: 22, color: AppTheme.textSecondary),
                  const SizedBox(width: 8),
                  Text('Add Video',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(
                              color: AppTheme.textSecondary)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // ─── Step 3: Review ───────────────────────────────────────────────────────

  Widget _buildStep3() {
    final totalImages = _existingImageUrls.length + _images.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Review Your Listing',
            style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(
          _isEditMode
              ? 'Review your changes before saving.'
              : 'Your listing will be reviewed by our team before going live.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 24),
        _ReviewRow(label: 'Title', value: _titleController.text),
        _ReviewRow(
            label: 'Type',
            value: '${_type.displayLabel} · ${_listingType == ListingType.rent ? 'Rent' : 'Sale'}'),
        _ReviewRow(
            label: 'Price', value: 'KES ${_priceController.text}'),
        _ReviewRow(
            label: 'Location',
            value:
                '${_addressController.text}, ${_cityController.text}'),
        if (!_type.isSingleRoom)
          _ReviewRow(
              label: 'Bedrooms',
              value: _bedroomsController.text.isNotEmpty
                  ? _bedroomsController.text
                  : 'N/A'),
        _ReviewRow(
            label: 'Photos', value: '$totalImages uploaded'),
        _ReviewRow(
            label: 'Video',
            value: (_video != null || _existingVideoUrl != null)
                ? 'Yes'
                : 'None'),
        _ReviewRow(
            label: 'Amenities',
            value: _amenities.isEmpty
                ? 'None'
                // displayLabel keeps this human-readable: "Borehole, Generator,
                // Pet Friendly" instead of "borehole, generator, petFriendly".
                : _amenities.map((a) => a.displayLabel).join(', ')),
        const SizedBox(height: 16),
        if (!_isEditMode)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: AppTheme.warningSurface,
                borderRadius:
                    BorderRadius.circular(AppTheme.radiusMD)),
            child: Row(
              children: [
                const Icon(Icons.info_outline,
                    size: 16, color: AppTheme.warning),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'After submission, an admin will review your listing within 24 hours.',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppTheme.warning),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  Future<void> _pickImages() async {
    final picked =
        await ImagePicker().pickMultiImage(imageQuality: 80);
    if (picked.isNotEmpty) {
      setState(
          () => _images.addAll(picked.map((p) => File(p.path))));
    }
  }

  Future<void> _pickVideo() async {
    final picked = await ImagePicker().pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 2),
    );
    if (picked != null) {
      setState(() => _video = File(picked.path));
    }
  }

  Future<void> _geocodeAddress() async {
    final address = _addressController.text.trim();
    final city = _cityController.text.trim();
    if (address.isEmpty) return;
    try {
      final query =
          Uri.encodeComponent('$address, $city, Kenya');
      final uri = Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=1');
      final response = await HttpClient().getUrl(uri).then((req) {
        req.headers.set('User-Agent', 'NestIQApp/1.0');
        return req.close();
      });
      final body =
          await response.transform(const Utf8Decoder()).join();
      final List<dynamic> results = jsonDecode(body);
      if (results.isNotEmpty && mounted) {
        final lat = double.parse(results[0]['lat'] as String);
        final lon = double.parse(results[0]['lon'] as String);
        setState(() {
          _latitude = lat;
          _longitude = lon;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Location set: ${lat.toStringAsFixed(5)}, ${lon.toStringAsFixed(5)}'),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Address not found. Pin coordinates unchanged.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Geocoding failed: $e')));
      }
    }
  }

  void _nextStep() {
    if (!_formKey.currentState!.validate()) return;
    if (_step == 2) {
      final totalImages =
          _existingImageUrls.length + _images.length;
      if (totalImages < 3) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Please add at least 3 photos')),
        );
        return;
      }
    }
    setState(() => _step++);
  }

  List<String> _buildSearchPrefixes(String text) {
    final lower = text.toLowerCase().trim();
    final prefixes = <String>{};
    final words = lower.split(RegExp(r'\s+'));
    for (final word in words) {
      for (int i = 1; i <= word.length; i++) {
        prefixes.add(word.substring(0, i));
      }
    }
    return prefixes.toList();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final totalImages = _existingImageUrls.length + _images.length;
    if (totalImages < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please add at least 3 photos')),
      );
      setState(() => _step = 2);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final propertyService = ref.read(propertyServiceProvider);
      final uid = ref.read(authStateProvider).value?.uid ?? '';

      // ── Fetch agent details from Firestore ───────────────────────────
      final currentUser =
          await ref.read(authServiceProvider).getCurrentUserData();
      final agentName = currentUser.fullName;
      final agentPhone = currentUser.phoneNumber;

      final titlePrefixes =
          _buildSearchPrefixes(_titleController.text);
      final cityPrefixes =
          _buildSearchPrefixes(_cityController.text);
      final addressPrefixes =
          _buildSearchPrefixes(_addressController.text);
      final searchPrefixes = {
        ...titlePrefixes,
        ...cityPrefixes,
        ...addressPrefixes,
      }.toList();

      // For single-room types (bedsitter/studio) force bedrooms to 0 so
      // downstream bedroom-count filters and isSingleRoom logic stay correct
      // even if the field was left blank or stale from a previous edit.
      final bedroomsValue = _type.isSingleRoom
          ? 0
          : int.tryParse(_bedroomsController.text);

      if (_isEditMode) {
        // ── Edit: patch only changed fields ──────────────────────────
        final updates = <String, dynamic>{
          'title': _titleController.text.trim(),
          'description': _descController.text.trim(),
          'price': double.parse(_priceController.text),
          'type': _type.name,
          'listingType': _listingType.name,
          'location': {
            'latitude': _latitude,
            'longitude': _longitude,
            'address': _addressController.text.trim(),
            'city': _cityController.text.trim(),
            'state': _state,
            'country': _country,
          },
          'bedrooms': bedroomsValue,
          'bathrooms': int.tryParse(_bathroomsController.text),
          'areaSqFt': double.tryParse(_areaController.text),
          'amenities': _amenities.map((a) => a.name).toList(),
          'agentName': agentName,
          'agentPhone': agentPhone,
          'searchPrefixes': searchPrefixes,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        List<String> finalImageUrls =
            List.from(_existingImageUrls);
        if (_images.isNotEmpty) {
          final newUrls = await propertyService.uploadImages(
              widget.editPropertyId!, _images);
          finalImageUrls.addAll(newUrls);
        }
        updates['imageUrls'] = finalImageUrls;

        if (_video != null) {
          final uploadedVideoUrl = await propertyService
              .uploadVideo(widget.editPropertyId!, _video!);
          final existingVideos = _existingVideoUrl != null
              ? [_existingVideoUrl!]
              : <String>[];
          updates['videoUrls'] = [
            ...existingVideos,
            uploadedVideoUrl
          ];
        } else if (_existingVideoUrl != null) {
          updates['videoUrls'] = [_existingVideoUrl!];
        } else {
          updates['videoUrls'] = <String>[];
        }

        await propertyService.updateProperty(
            widget.editPropertyId!, updates);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Listing updated ✓')));
          context.pop();
        }
      } else {
        // ── Create new property ───────────────────────────────────────
        final property = Property(
          id: '',
          title: _titleController.text.trim(),
          description: _descController.text.trim(),
          price: double.parse(_priceController.text),
          type: _type,
          status: PropertyStatus.active,
          listingType: _listingType,
          location: PropertyLocation(
            latitude: _latitude,
            longitude: _longitude,
            address: _addressController.text.trim(),
            city: _cityController.text.trim(),
            state: _state,
            country: _country,
          ),
          bedrooms: bedroomsValue,
          bathrooms: int.tryParse(_bathroomsController.text),
          areaSqFt: double.tryParse(_areaController.text),
          amenities: _amenities,
          agentId: uid,
          agentName: agentName,
          agentPhone: agentPhone,
          isApproved: false,
          imageUrls: [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final propertyId =
            await propertyService.createProperty(property);

        await propertyService.updateProperty(propertyId, {
          'searchPrefixes': searchPrefixes,
        });

        if (_images.isNotEmpty) {
          final urls = await propertyService.uploadImages(
              propertyId, _images);
          await propertyService
              .updateProperty(propertyId, {'imageUrls': urls});
        }

        if (_video != null) {
          final uploadedVideoUrl = await propertyService
              .uploadVideo(propertyId, _video!);
          await propertyService.updateProperty(
              propertyId, {'videoUrls': [uploadedVideoUrl]});
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content:
                    Text('Listing submitted for review! ✓')),
          );
          context.pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

// ─── Media Tile ───────────────────────────────────────────────────────────────

class _MediaTile extends StatelessWidget {
  final Widget child;
  final bool isFirst;
  final VoidCallback onRemove;
  const _MediaTile(
      {required this.child,
      required this.isFirst,
      required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                  color: Colors.black54, shape: BoxShape.circle),
              child: const Icon(Icons.close,
                  size: 14, color: Colors.white),
            ),
          ),
        ),
        if (isFirst)
          Positioned(
            bottom: 4,
            left: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(4)),
              child: const Text('Cover',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600)),
            ),
          ),
      ],
    );
  }
}

// ─── Choice Chip ──────────────────────────────────────────────────────────────

class _ChoiceChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  const _ChoiceChip(
      {required this.label,
      required this.isSelected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
            vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primarySurface
              : AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          border: Border.all(
              color:
                  isSelected ? AppTheme.primary : AppTheme.border,
              width: isSelected ? 1.5 : 0.5),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isSelected
                    ? AppTheme.primary
                    : AppTheme.textSecondary),
          ),
        ),
      ),
    );
  }
}

// ─── Review Row ───────────────────────────────────────────────────────────────

class _ReviewRow extends StatelessWidget {
  final String label;
  final String value;
  const _ReviewRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 100,
              child: Text(label,
                  style: Theme.of(context).textTheme.bodySmall)),
          Expanded(
              child: Text(value,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}