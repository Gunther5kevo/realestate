import 'package:cloud_firestore/cloud_firestore.dart';

// ─── User Model ──────────────────────────────────────────────────────────────
enum UserRole { user, agent, admin }

class AppUser {
  final String id;
  final String email;
  final String fullName;
  final String? phoneNumber;
  final String? avatarUrl;
  final UserRole role;
  final bool isVerified;
  final bool isActive;
  final List<String> savedProperties;
  final Map<String, dynamic>? agentProfile;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AppUser({
    required this.id,
    required this.email,
    required this.fullName,
    this.phoneNumber,
    this.avatarUrl,
    required this.role,
    this.isVerified = false,
    this.isActive = true,
    this.savedProperties = const [],
    this.agentProfile,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppUser(
      id: doc.id,
      email: data['email'] ?? '',
      fullName: data['fullName'] ?? '',
      phoneNumber: data['phoneNumber'],
      avatarUrl: data['avatarUrl'],
      role: UserRole.values.firstWhere(
        (r) => r.name == data['role'],
        orElse: () => UserRole.user,
      ),
      isVerified: data['isVerified'] ?? false,
      isActive: data['isActive'] ?? true,
      savedProperties:
          List<String>.from(data['savedProperties'] ?? []),
      agentProfile: data['agentProfile'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'email': email,
        'fullName': fullName,
        'phoneNumber': phoneNumber,
        'avatarUrl': avatarUrl,
        'role': role.name,
        'isVerified': isVerified,
        'isActive': isActive,
        'savedProperties': savedProperties,
        'agentProfile': agentProfile,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  AppUser copyWith({
    String? fullName,
    String? phoneNumber,
    String? avatarUrl,
    UserRole? role,
    bool? isVerified,
    bool? isActive,
    List<String>? savedProperties,
    Map<String, dynamic>? agentProfile,
  }) =>
      AppUser(
        id: id,
        email: email,
        fullName: fullName ?? this.fullName,
        phoneNumber: phoneNumber ?? this.phoneNumber,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        role: role ?? this.role,
        isVerified: isVerified ?? this.isVerified,
        isActive: isActive ?? this.isActive,
        savedProperties: savedProperties ?? this.savedProperties,
        agentProfile: agentProfile ?? this.agentProfile,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );
}

// ─── Property Model ──────────────────────────────────────────────────────────
enum PropertyType { apartment, house, villa, commercial, land, studio }
enum PropertyStatus { active, pending, sold, rented, suspended }
enum ListingType { sale, rent }
enum PropertyAmenity {
  pool, gym, parking, security, balcony, garden, elevator,
  wifi, airConditioning, furnished, petFriendly, waterfront
}

class PropertyLocation {
  final double latitude;
  final double longitude;
  final String address;
  final String city;
  final String state;
  final String country;
  final String? neighborhood;
  final String? zipCode;

  const PropertyLocation({
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.city,
    required this.state,
    required this.country,
    this.neighborhood,
    this.zipCode,
  });

  factory PropertyLocation.fromMap(Map<String, dynamic> map) =>
      PropertyLocation(
        latitude: (map['latitude'] ?? 0).toDouble(),
        longitude: (map['longitude'] ?? 0).toDouble(),
        address: map['address'] ?? '',
        city: map['city'] ?? '',
        state: map['state'] ?? '',
        country: map['country'] ?? '',
        neighborhood: map['neighborhood'],
        zipCode: map['zipCode'],
      );

  Map<String, dynamic> toMap() => {
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
        'city': city,
        'state': state,
        'country': country,
        'neighborhood': neighborhood,
        'zipCode': zipCode,
        'geoPoint': GeoPoint(latitude, longitude),
      };

  String get fullAddress => '$address, $city, $state';
}

class Property {
  final String id;
  final String title;
  final String description;
  final double price;
  final String currency;
  final PropertyType type;
  final PropertyStatus status;
  final ListingType listingType;
  final PropertyLocation location;
  final int? bedrooms;
  final int? bathrooms;
  final double? areaSqFt;
  final int? floors;
  final int? yearBuilt;
  final List<String> imageUrls;
  final List<String> videoUrls;
  final List<PropertyAmenity> amenities;
  final String agentId;
  final String? agentName;
  final String? agentPhone;        // ← NEW
  final bool isFeatured;
  final bool isApproved;
  final int viewCount;
  final int savedCount;
  final Map<String, dynamic>? virtualTourUrl;
  final Map<String, dynamic>? additionalDetails;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Property({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    this.currency = 'KES',
    required this.type,
    required this.status,
    required this.listingType,
    required this.location,
    this.bedrooms,
    this.bathrooms,
    this.areaSqFt,
    this.floors,
    this.yearBuilt,
    this.imageUrls = const [],
    this.videoUrls = const [],
    this.amenities = const [],
    required this.agentId,
    this.agentName,
    this.agentPhone,               // ← NEW
    this.isFeatured = false,
    this.isApproved = false,
    this.viewCount = 0,
    this.savedCount = 0,
    this.virtualTourUrl,
    this.additionalDetails,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Property.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Property(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      price: (data['price'] ?? 0).toDouble(),
      currency: data['currency'] ?? 'KES',
      type: PropertyType.values.firstWhere(
        (t) => t.name == data['type'],
        orElse: () => PropertyType.apartment,
      ),
      status: PropertyStatus.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => PropertyStatus.active,
      ),
      listingType: ListingType.values.firstWhere(
        (l) => l.name == data['listingType'],
        orElse: () => ListingType.sale,
      ),
      location:
          PropertyLocation.fromMap(data['location'] ?? {}),
      bedrooms: data['bedrooms'],
      bathrooms: data['bathrooms'],
      areaSqFt: data['areaSqFt']?.toDouble(),
      floors: data['floors'],
      yearBuilt: data['yearBuilt'],
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      videoUrls: List<String>.from(data['videoUrls'] ?? []),
      amenities: (data['amenities'] as List<dynamic>? ?? [])
          .map((a) => PropertyAmenity.values.firstWhere(
                (pa) => pa.name == a,
                orElse: () => PropertyAmenity.wifi,
              ))
          .toList(),
      agentId: data['agentId'] ?? '',
      agentName: data['agentName'],
      agentPhone: data['agentPhone'],   // ← NEW
      isFeatured: data['isFeatured'] ?? false,
      isApproved: data['isApproved'] ?? false,
      viewCount: data['viewCount'] ?? 0,
      savedCount: data['savedCount'] ?? 0,
      virtualTourUrl: data['virtualTourUrl'],
      additionalDetails: data['additionalDetails'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'description': description,
        'price': price,
        'currency': currency,
        'type': type.name,
        'status': status.name,
        'listingType': listingType.name,
        'location': location.toMap(),
        'bedrooms': bedrooms,
        'bathrooms': bathrooms,
        'areaSqFt': areaSqFt,
        'floors': floors,
        'yearBuilt': yearBuilt,
        'imageUrls': imageUrls,
        'videoUrls': videoUrls,
        'amenities': amenities.map((a) => a.name).toList(),
        'agentId': agentId,
        'agentName': agentName,
        'agentPhone': agentPhone,         // ← NEW
        'isFeatured': isFeatured,
        'isApproved': isApproved,
        'viewCount': viewCount,
        'savedCount': savedCount,
        'virtualTourUrl': virtualTourUrl,
        'additionalDetails': additionalDetails,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
        'searchTitle': _buildSearchTitle(),
        'searchCity': location.city.toLowerCase(),
        'searchKeywords': _buildSearchKeywords(),
      };

  String _buildSearchTitle() {
    final parts = <String>[
      title.toLowerCase(),
      location.neighborhood?.toLowerCase() ?? '',
      location.city.toLowerCase(),
      location.state.toLowerCase(),
      type.name.toLowerCase(),
      listingType.name.toLowerCase(),
      if (listingType == ListingType.rent) 'rent rental',
      if (listingType == ListingType.sale) 'sale buy',
      if (bedrooms != null) '$bedrooms bedroom',
      agentName?.toLowerCase() ?? '',
    ];
    return parts.where((p) => p.isNotEmpty).join(' ');
  }

  List<String> _buildSearchKeywords() {
    final keywords = <String>{};
    keywords.addAll(title.toLowerCase().split(' '));
    keywords.add(location.city.toLowerCase());
    keywords.add(location.state.toLowerCase());
    if (location.neighborhood != null) {
      keywords
          .addAll(location.neighborhood!.toLowerCase().split(' '));
    }
    if (location.address.isNotEmpty) {
      keywords
          .addAll(location.address.toLowerCase().split(' '));
    }
    keywords.add(type.name.toLowerCase());
    keywords.add(listingType.name.toLowerCase());
    if (listingType == ListingType.rent) {
      keywords.addAll(['rent', 'rental', 'to let', 'let']);
    } else {
      keywords.addAll(['sale', 'buy', 'purchase', 'for sale']);
    }
    if (bedrooms != null) {
      keywords.add('${bedrooms}bed');
      keywords.add('${bedrooms}bedroom');
      keywords.add('$bedrooms bed');
      keywords.add('$bedrooms bedroom');
    }
    if (price >= 100000000) keywords.add('luxury');
    if (price >= 50000000) keywords.addAll(['premium', 'highend']);
    if (listingType == ListingType.rent && price <= 50000) {
      keywords.add('affordable');
    }
    keywords.removeWhere((k) => k.length < 2);
    return keywords.toList();
  }

  // ─── Computed getters ─────────────────────────────────────────────────────

  String? get videoUrl =>
      videoUrls.isNotEmpty ? videoUrls.first : null;

  String get formattedPrice {
    if (price >= 1000000) {
      return '$currency ${(price / 1000000).toStringAsFixed(1)}M';
    } else if (price >= 1000) {
      return '$currency ${(price / 1000).toStringAsFixed(0)}K';
    }
    return '$currency ${price.toStringAsFixed(0)}';
  }

  String get priceLabel => listingType == ListingType.rent
      ? '$formattedPrice/mo'
      : formattedPrice;
}

// ─── Booking Model ───────────────────────────────────────────────────────────
enum BookingType { viewing, reservation }
enum BookingStatus { pending, confirmed, cancelled, completed }
enum PaymentStatus { unpaid, paid, refunded }

class Booking {
  final String id;
  final String propertyId;
  final String propertyTitle;
  final String propertyImage;
  final String userId;
  final String userFullName;
  final String agentId;
  final BookingType type;
  final BookingStatus status;
  final DateTime scheduledDate;
  final String? timeSlot;
  final String? notes;
  final String? cancellationReason;
  final String? paymentReference;
  final PaymentStatus paymentStatus;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Booking({
    required this.id,
    required this.propertyId,
    required this.propertyTitle,
    required this.propertyImage,
    required this.userId,
    required this.userFullName,
    required this.agentId,
    required this.type,
    required this.status,
    required this.scheduledDate,
    this.timeSlot,
    this.notes,
    this.cancellationReason,
    this.paymentReference,
    this.paymentStatus = PaymentStatus.unpaid,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Booking.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Booking(
      id: doc.id,
      propertyId: data['propertyId'] ?? '',
      propertyTitle: data['propertyTitle'] ?? '',
      propertyImage: data['propertyImage'] ?? '',
      userId: data['userId'] ?? '',
      userFullName: data['userFullName'] ?? '',
      agentId: data['agentId'] ?? '',
      type: BookingType.values.firstWhere(
        (t) => t.name == data['type'],
        orElse: () => BookingType.viewing,
      ),
      status: BookingStatus.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => BookingStatus.pending,
      ),
      scheduledDate:
          (data['scheduledDate'] as Timestamp).toDate(),
      timeSlot: data['timeSlot'],
      notes: data['notes'],
      cancellationReason: data['cancellationReason'],
      paymentReference: data['paymentReference'],
      paymentStatus: PaymentStatus.values.firstWhere(
        (s) => s.name == data['paymentStatus'],
        orElse: () => PaymentStatus.unpaid,
      ),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'propertyId': propertyId,
        'propertyTitle': propertyTitle,
        'propertyImage': propertyImage,
        'userId': userId,
        'userFullName': userFullName,
        'agentId': agentId,
        'type': type.name,
        'status': status.name,
        'scheduledDate': Timestamp.fromDate(scheduledDate),
        'timeSlot': timeSlot,
        'notes': notes,
        'cancellationReason': cancellationReason,
        'paymentReference': paymentReference,
        'paymentStatus': paymentStatus.name,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  Booking copyWith({
    String? userId,
    String? userFullName,
    BookingStatus? status,
    String? cancellationReason,
    String? paymentReference,
    PaymentStatus? paymentStatus,
  }) =>
      Booking(
        id: id,
        propertyId: propertyId,
        propertyTitle: propertyTitle,
        propertyImage: propertyImage,
        userId: userId ?? this.userId,
        userFullName: userFullName ?? this.userFullName,
        agentId: agentId,
        type: type,
        status: status ?? this.status,
        scheduledDate: scheduledDate,
        timeSlot: timeSlot,
        notes: notes,
        cancellationReason:
            cancellationReason ?? this.cancellationReason,
        paymentReference:
            paymentReference ?? this.paymentReference,
        paymentStatus: paymentStatus ?? this.paymentStatus,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );
}

// ─── Transaction Model ───────────────────────────────────────────────────────
enum TransactionStatus {
  pending, processing, completed, failed, refunded
}
enum PaymentMethod { mpesa, stripe, card }

class Transaction {
  final String id;
  final String propertyId;
  final String userId;
  final String agentId;
  final double amount;
  final String currency;
  final TransactionStatus status;
  final PaymentMethod paymentMethod;
  final String? paymentReference;
  final String? mpesaPhone;
  final String? stripePaymentIntentId;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Transaction({
    required this.id,
    required this.propertyId,
    required this.userId,
    required this.agentId,
    required this.amount,
    this.currency = 'KES',
    required this.status,
    required this.paymentMethod,
    this.paymentReference,
    this.mpesaPhone,
    this.stripePaymentIntentId,
    this.metadata,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Transaction.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Transaction(
      id: doc.id,
      propertyId: data['propertyId'] ?? '',
      userId: data['userId'] ?? '',
      agentId: data['agentId'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      currency: data['currency'] ?? 'KES',
      status: TransactionStatus.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => TransactionStatus.pending,
      ),
      paymentMethod: PaymentMethod.values.firstWhere(
        (p) => p.name == data['paymentMethod'],
        orElse: () => PaymentMethod.mpesa,
      ),
      paymentReference: data['paymentReference'],
      mpesaPhone: data['mpesaPhone'],
      stripePaymentIntentId: data['stripePaymentIntentId'],
      metadata: data['metadata'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'propertyId': propertyId,
        'userId': userId,
        'agentId': agentId,
        'amount': amount,
        'currency': currency,
        'status': status.name,
        'paymentMethod': paymentMethod.name,
        'paymentReference': paymentReference,
        'mpesaPhone': mpesaPhone,
        'stripePaymentIntentId': stripePaymentIntentId,
        'metadata': metadata,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };
}

// ─── Search Filter Model ─────────────────────────────────────────────────────
class PropertyFilter {
  final String? searchQuery;
  final PropertyType? type;
  final ListingType? listingType;
  final double? minPrice;
  final double? maxPrice;
  final int? minBedrooms;
  final int? maxBedrooms;
  final int? minBathrooms;
  final double? minArea;
  final double? maxArea;
  final String? city;
  final String? neighborhood;
  final List<PropertyAmenity> amenities;
  final bool? isFeatured;
  final String sortBy;
  final double? radiusKm;
  final double? centerLat;
  final double? centerLng;

  const PropertyFilter({
    this.searchQuery,
    this.type,
    this.listingType,
    this.minPrice,
    this.maxPrice,
    this.minBedrooms,
    this.maxBedrooms,
    this.minBathrooms,
    this.minArea,
    this.maxArea,
    this.city,
    this.neighborhood,
    this.amenities = const [],
    this.isFeatured,
    this.sortBy = 'newest',
    this.radiusKm,
    this.centerLat,
    this.centerLng,
  });

  PropertyFilter copyWith({
    String? searchQuery,
    PropertyType? type,
    ListingType? listingType,
    double? minPrice,
    double? maxPrice,
    int? minBedrooms,
    int? maxBedrooms,
    int? minBathrooms,
    double? minArea,
    double? maxArea,
    String? city,
    String? neighborhood,
    List<PropertyAmenity>? amenities,
    bool? isFeatured,
    String? sortBy,
    double? radiusKm,
    double? centerLat,
    double? centerLng,
  }) =>
      PropertyFilter(
        searchQuery: searchQuery ?? this.searchQuery,
        type: type ?? this.type,
        listingType: listingType ?? this.listingType,
        minPrice: minPrice ?? this.minPrice,
        maxPrice: maxPrice ?? this.maxPrice,
        minBedrooms: minBedrooms ?? this.minBedrooms,
        maxBedrooms: maxBedrooms ?? this.maxBedrooms,
        minBathrooms: minBathrooms ?? this.minBathrooms,
        minArea: minArea ?? this.minArea,
        maxArea: maxArea ?? this.maxArea,
        city: city ?? this.city,
        neighborhood: neighborhood ?? this.neighborhood,
        amenities: amenities ?? this.amenities,
        isFeatured: isFeatured ?? this.isFeatured,
        sortBy: sortBy ?? this.sortBy,
        radiusKm: radiusKm ?? this.radiusKm,
        centerLat: centerLat ?? this.centerLat,
        centerLng: centerLng ?? this.centerLng,
      );

  bool get hasActiveFilters =>
      type != null ||
      minPrice != null ||
      maxPrice != null ||
      minBedrooms != null ||
      city != null ||
      amenities.isNotEmpty;
}

// ─── Agent Profile ───────────────────────────────────────────────────────────
class AgentProfile {
  final String userId;
  final String displayName;
  final String? bio;
  final String? avatarUrl;
  final String? licenseNumber;
  final String? agency;
  final String? phone;
  final String? email;
  final String? website;
  final double rating;
  final int reviewCount;
  final int totalListings;
  final int soldCount;
  final bool isVerified;
  final List<String> specializations;
  final Map<String, String>? socialLinks;
  final DateTime memberSince;

  const AgentProfile({
    required this.userId,
    required this.displayName,
    this.bio,
    this.avatarUrl,
    this.licenseNumber,
    this.agency,
    this.phone,
    this.email,
    this.website,
    this.rating = 0.0,
    this.reviewCount = 0,
    this.totalListings = 0,
    this.soldCount = 0,
    this.isVerified = false,
    this.specializations = const [],
    this.socialLinks,
    required this.memberSince,
  });

  factory AgentProfile.fromMap(Map<String, dynamic> map, String id) =>
      AgentProfile(
        userId: id,
        displayName: map['displayName'] ?? '',
        bio: map['bio'],
        avatarUrl: map['avatarUrl'],
        licenseNumber: map['licenseNumber'],
        agency: map['agency'],
        phone: map['phone'],
        email: map['email'],
        website: map['website'],
        rating: (map['rating'] ?? 0).toDouble(),
        reviewCount: map['reviewCount'] ?? 0,
        totalListings: map['totalListings'] ?? 0,
        soldCount: map['soldCount'] ?? 0,
        isVerified: map['isVerified'] ?? false,
        specializations:
            List<String>.from(map['specializations'] ?? []),
        socialLinks: map['socialLinks'] != null
            ? Map<String, String>.from(map['socialLinks'])
            : null,
        memberSince: map['memberSince'] != null
            ? (map['memberSince'] as Timestamp).toDate()
            : DateTime.now(),
      );
}