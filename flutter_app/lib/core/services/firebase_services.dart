import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/models.dart';

// ─── Auth Service ─────────────────────────────────────────────────────────────
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<AppUser> signUp({
    required String email,
    required String password,
    required String fullName,
    String? phoneNumber,
    UserRole role = UserRole.user,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await credential.user!.updateDisplayName(fullName);
    await credential.user!.sendEmailVerification();

    final user = AppUser(
      id: credential.user!.uid,
      email: email,
      fullName: fullName,
      phoneNumber: phoneNumber,
      role: role,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _db.collection('users').doc(user.id).set(user.toMap());

    if (role == UserRole.agent) {
      await _createAgentProfile(user.id, fullName, email);
    }

    return user;
  }

  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
    return await getCurrentUserData();
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  Future<AppUser> getCurrentUserData() async {
    final uid = _auth.currentUser!.uid;
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) throw Exception('User data not found');
    return AppUser.fromFirestore(doc);
  }

  Future<void> updateProfile({
    String? fullName,
    String? phoneNumber,
    String? avatarUrl,
  }) async {
    final uid = _auth.currentUser!.uid;
    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
      if (fullName != null) 'fullName': fullName,
      if (phoneNumber != null) 'phoneNumber': phoneNumber,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
    };
    await _db.collection('users').doc(uid).update(updates);
    if (fullName != null) {
      await _auth.currentUser!.updateDisplayName(fullName);
    }
  }

  Future<void> _createAgentProfile(
      String uid, String name, String email) async {
    await _db.collection('agents').doc(uid).set({
      'displayName': name,
      'email': email,
      'rating': 0.0,
      'reviewCount': 0,
      'totalListings': 0,
      'soldCount': 0,
      'isVerified': false,
      'specializations': [],
      'memberSince': FieldValue.serverTimestamp(),
    });
  }
}

// ─── Property Service ─────────────────────────────────────────────────────────
class PropertyService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<List<Property>> getProperties({
    required PropertyFilter filter,
    DocumentSnapshot? lastDoc,
    int limit = 20,
  }) async {
    Query query = _db
        .collection('properties')
        .where('isApproved', isEqualTo: true)
        .where('status', isEqualTo: PropertyStatus.active.name);

    if (filter.listingType != null) {
      query =
          query.where('listingType', isEqualTo: filter.listingType!.name);
    }
    if (filter.type != null) {
      query = query.where('type', isEqualTo: filter.type!.name);
    }
    if (filter.city != null) {
      query = query.where('location.city', isEqualTo: filter.city);
    }
    if (filter.minBedrooms != null) {
      query = query.where('bedrooms',
          isGreaterThanOrEqualTo: filter.minBedrooms);
    }
    if (filter.isFeatured == true) {
      query = query.where('isFeatured', isEqualTo: true);
    }

    switch (filter.sortBy) {
      case 'price_asc':
        query = query.orderBy('price', descending: false);
        break;
      case 'price_desc':
        query = query.orderBy('price', descending: true);
        break;
      case 'popular':
        query = query.orderBy('viewCount', descending: true);
        break;
      default:
        query = query.orderBy('createdAt', descending: true);
    }

    if (lastDoc != null) query = query.startAfterDocument(lastDoc);

    final snapshot = await query.limit(limit).get();

    return snapshot.docs
        .map((doc) => Property.fromFirestore(doc))
        .where((p) {
          if (filter.minPrice != null && p.price < filter.minPrice!) {
            return false;
          }
          if (filter.maxPrice != null && p.price > filter.maxPrice!) {
            return false;
          }
          return true;
        })
        .toList();
  }

  Stream<Property> getPropertyStream(String propertyId) {
    return _db
        .collection('properties')
        .doc(propertyId)
        .snapshots()
        .map((doc) => Property.fromFirestore(doc));
  }

  Future<Property> getProperty(String propertyId) async {
    final doc =
        await _db.collection('properties').doc(propertyId).get();
    if (!doc.exists) throw Exception('Property not found');

    _db.collection('properties').doc(propertyId).update({
      'viewCount': FieldValue.increment(1),
    });

    return Property.fromFirestore(doc);
  }

  Future<List<Property>> searchProperties(
    String query, {
    PropertyFilter filter = const PropertyFilter(),
  }) async {
    final trimmed = query.trim().toLowerCase();

    if (trimmed.isEmpty && !filter.hasActiveFilters) return [];

    Query q = _db
        .collection('properties')
        .where('isApproved', isEqualTo: true)
        .where('status', isEqualTo: PropertyStatus.active.name);

    if (trimmed.isNotEmpty) {
      q = q.where('searchPrefixes', arrayContains: trimmed);
    } else {
      q = q.orderBy('createdAt', descending: true);
    }

    if (filter.listingType != null) {
      q = q.where('listingType', isEqualTo: filter.listingType!.name);
    }
    if (filter.type != null) {
      q = q.where('type', isEqualTo: filter.type!.name);
    }

    final snapshot = await q.limit(30).get();

    return snapshot.docs
        .map((doc) => Property.fromFirestore(doc))
        .where((p) {
          if (filter.minPrice != null && p.price < filter.minPrice!) {
            return false;
          }
          if (filter.maxPrice != null && p.price > filter.maxPrice!) {
            return false;
          }
          if (filter.minBedrooms != null &&
              (p.bedrooms ?? 0) < filter.minBedrooms!) {
            return false;
          }
          return true;
        })
        .toList();
  }

  Future<List<Property>> getFeaturedProperties() async {
    final snapshot = await _db
        .collection('properties')
        .where('isApproved', isEqualTo: true)
        .where('isFeatured', isEqualTo: true)
        .where('status', isEqualTo: PropertyStatus.active.name)
        .orderBy('createdAt', descending: true)
        .limit(10)
        .get();

    return snapshot.docs
        .map((doc) => Property.fromFirestore(doc))
        .toList();
  }

  Future<List<Property>> getAgentProperties(String agentId) async {
    final snapshot = await _db
        .collection('properties')
        .where('agentId', isEqualTo: agentId)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => Property.fromFirestore(doc))
        .toList();
  }

  Future<List<Property>> getPropertiesInBounds({
    required double swLat,
    required double swLng,
    required double neLat,
    required double neLng,
    ListingType? listingType,
    PropertyType? type,
    int limit = 50,
  }) async {
    Query query = _db
        .collection('properties')
        .where('isApproved', isEqualTo: true)
        .where('status', isEqualTo: PropertyStatus.active.name)
        .where('location.latitude', isGreaterThanOrEqualTo: swLat)
        .where('location.latitude', isLessThanOrEqualTo: neLat);

    if (listingType != null) {
      query =
          query.where('listingType', isEqualTo: listingType.name);
    }
    if (type != null) {
      query = query.where('type', isEqualTo: type.name);
    }

    final snapshot = await query.limit(limit).get();

    return snapshot.docs
        .map((doc) => Property.fromFirestore(doc))
        .where((p) =>
            p.location.longitude >= swLng &&
            p.location.longitude <= neLng)
        .toList();
  }

  Future<String> createProperty(Property property) async {
    final docRef =
        await _db.collection('properties').add(property.toMap());
    return docRef.id;
  }

  Future<void> updateProperty(
      String id, Map<String, dynamic> data) async {
    data['updatedAt'] = FieldValue.serverTimestamp();
    await _db.collection('properties').doc(id).update(data);
  }

  Future<void> deleteProperty(String id) async {
    await _db.collection('properties').doc(id).delete();
  }

  Future<List<String>> uploadImages(
    String propertyId,
    List<File> images,
  ) async {
    final urls = <String>[];
    for (var i = 0; i < images.length; i++) {
      final ref = _storage.ref().child(
          'properties/$propertyId/images/${DateTime.now().millisecondsSinceEpoch}_$i.jpg');
      final task = await ref.putFile(images[i]);
      urls.add(await task.ref.getDownloadURL());
    }
    return urls;
  }

  Future<String> uploadVideo(String propertyId, File video) async {
    final ref = _storage.ref().child(
        'properties/$propertyId/videos/${DateTime.now().millisecondsSinceEpoch}.mp4');
    final task = await ref.putFile(video);
    return await task.ref.getDownloadURL();
  }

  Future<void> toggleSavedProperty(
      String userId, String propertyId) async {
    final userRef = _db.collection('users').doc(userId);
    final doc = await userRef.get();
    final saved =
        List<String>.from(doc.data()?['savedProperties'] ?? []);

    if (saved.contains(propertyId)) {
      await userRef.update({
        'savedProperties': FieldValue.arrayRemove([propertyId]),
      });
      await _db.collection('properties').doc(propertyId).update({
        'savedCount': FieldValue.increment(-1),
      });
    } else {
      await userRef.update({
        'savedProperties': FieldValue.arrayUnion([propertyId]),
      });
      await _db.collection('properties').doc(propertyId).update({
        'savedCount': FieldValue.increment(1),
      });
    }
  }

  Future<List<Property>> getSavedProperties(List<String> ids) async {
    if (ids.isEmpty) return [];
    final snapshot = await _db
        .collection('properties')
        .where(FieldPath.documentId,
            whereIn: ids.take(10).toList())
        .get();
    return snapshot.docs
        .map((doc) => Property.fromFirestore(doc))
        .toList();
  }
}

// ─── Booking Service ──────────────────────────────────────────────────────────
//
// IMPORTANT: Bookings are created AFTER payment is confirmed.
// The flow is:
//   BookingSheet → PaymentScreen → (payment success) → createBooking
//
// createBooking requires paymentStatus == PaymentStatus.paid.
// The agent is only notified once payment is confirmed.
//
// STATUS → PROPERTY STATUS MAPPING
// When an agent marks a booking as `completed` the property is automatically
// transitioned to either `sold` (sale listing) or `rented` (rent listing).
// All other pending/confirmed bookings for the same property are cancelled.

class BookingService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Creates a booking. Should only be called after payment is confirmed.
  Future<String> createBooking(Booking booking) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('User not authenticated');

    String userId = booking.userId;
    String userFullName = booking.userFullName;

    if (userId.isEmpty || userFullName.isEmpty) {
      final userDoc = await _db.collection('users').doc(uid).get();
      userId = uid;
      userFullName = userDoc.data()?['fullName'] as String? ?? '';
    }

    if (booking.paymentStatus != PaymentStatus.paid) {
      throw Exception('Cannot create booking without confirmed payment.');
    }

    final data = booking
        .copyWith(
          userId: userId,
          userFullName: userFullName,
        )
        .toMap();

    data['createdAt'] = FieldValue.serverTimestamp();
    data['updatedAt'] = FieldValue.serverTimestamp();

    final ref = await _db.collection('bookings').add(data);

    FirebaseFunctions.instanceFor(region: 'us-central1')
        .httpsCallable('notifyAgent')
        .call({
      'bookingId': ref.id,
      'agentId': booking.agentId,
      'message': 'New paid viewing request from $userFullName',
      'scheduledDate': booking.scheduledDate.toIso8601String(),
      'timeSlot': booking.timeSlot,
    });

    return ref.id;
  }

  /// Returns an active booking for the given user and property, or null.
  Future<Booking?> getActiveBookingForProperty({
    required String userId,
    required String propertyId,
  }) async {
    final snapshot = await _db
        .collection('bookings')
        .where('userId', isEqualTo: userId)
        .where('propertyId', isEqualTo: propertyId)
        .where('status', whereIn: ['pending', 'confirmed'])
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return Booking.fromFirestore(snapshot.docs.first);
  }

  Stream<List<Booking>> getUserBookings(String userId) {
    return _db
        .collection('bookings')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => Booking.fromFirestore(d)).toList());
  }

  Stream<List<Booking>> getAgentBookings(String agentId) {
    return _db
        .collection('bookings')
        .where('agentId', isEqualTo: agentId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => Booking.fromFirestore(d)).toList());
  }

  /// Updates a booking's status.
  ///
  /// When [status] is [BookingStatus.completed]:
  ///   1. The booking document is marked completed.
  ///   2. The linked property is marked `sold` or `rented` depending on its
  ///      [ListingType] — all inside a single Firestore batch so the two
  ///      writes are atomic.
  ///   3. Every other pending/confirmed booking for that property is
  ///      cancelled (with reason "Property no longer available") so no other
  ///      client sees stale availability.
  ///   4. The agent's `soldCount` counter is incremented.
  Future<void> updateBookingStatus(
    String bookingId,
    BookingStatus status, {
    String? cancellationReason,
  }) async {
    if (status == BookingStatus.completed) {
      await _completeBookingAndCloseProperty(bookingId);
    } else {
      await _db.collection('bookings').doc(bookingId).update({
        'status': status.name,
        if (cancellationReason != null)
          'cancellationReason': cancellationReason,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Internal: atomically completes the booking and marks the property
  /// as sold/rented.
  Future<void> _completeBookingAndCloseProperty(String bookingId) async {
    // 1. Read the booking to find the propertyId and agentId.
    final bookingDoc =
        await _db.collection('bookings').doc(bookingId).get();
    if (!bookingDoc.exists) throw Exception('Booking not found');

    final bookingData = bookingDoc.data()!;
    final propertyId = bookingData['propertyId'] as String;
    final agentId = bookingData['agentId'] as String? ?? '';

    // 2. Read the property to determine listing type.
    final propertyDoc =
        await _db.collection('properties').doc(propertyId).get();
    if (!propertyDoc.exists) throw Exception('Property not found');

    final propertyData = propertyDoc.data()!;
    final listingTypeName = propertyData['listingType'] as String? ?? 'sale';
    final listingType = ListingType.values.firstWhere(
      (l) => l.name == listingTypeName,
      orElse: () => ListingType.sale,
    );
    final newPropertyStatus = listingType == ListingType.rent
        ? PropertyStatus.rented
        : PropertyStatus.sold;

    // 3. Find all OTHER active bookings for the same property to cancel.
    final otherBookingsSnap = await _db
        .collection('bookings')
        .where('propertyId', isEqualTo: propertyId)
        .where('status', whereIn: ['pending', 'confirmed'])
        .get();

    // 4. Build and commit a batch.
    final batch = _db.batch();

    // 4a. Complete this booking.
    batch.update(_db.collection('bookings').doc(bookingId), {
      'status': BookingStatus.completed.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // 4b. Update the property status.
    batch.update(_db.collection('properties').doc(propertyId), {
      'status': newPropertyStatus.name,
      'isApproved': true, // keep it visible so users can see the sold banner
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // 4c. Cancel every other active booking for this property.
    for (final doc in otherBookingsSnap.docs) {
      if (doc.id == bookingId) continue; // skip the one we're completing
      batch.update(doc.reference, {
        'status': BookingStatus.cancelled.name,
        'cancellationReason': 'Property is no longer available',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    // 4d. Increment agent soldCount.
    if (agentId.isNotEmpty) {
      batch.update(_db.collection('agents').doc(agentId), {
        'soldCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  Future<List<String>> getAvailableTimeSlots(
    String agentId,
    DateTime date,
  ) async {
    final snapshot = await _db
        .collection('bookings')
        .where('agentId', isEqualTo: agentId)
        .where('scheduledDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(date))
        .where('scheduledDate',
            isLessThan: Timestamp.fromDate(
                date.add(const Duration(days: 1))))
        .where('status', whereIn: ['pending', 'confirmed'])
        .get();

    const allSlots = [
      '09:00', '09:30', '10:00', '10:30', '11:00', '11:30',
      '14:00', '14:30', '15:00', '15:30', '16:00', '16:30',
    ];

    final bookedSlots = snapshot.docs
        .map((d) => d.data()['timeSlot'] as String?)
        .whereType<String>()
        .toSet();

    return allSlots.where((s) => !bookedSlots.contains(s)).toList();
  }
}

// ─── Payment Service ──────────────────────────────────────────────────────────
class PaymentService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'us-central1');

  Future<Map<String, dynamic>> initiateMpesaPayment({
    required String phone,
    required double amount,
    required String propertyId,
    required String bookingId,
  }) async {
    final result =
        await _functions.httpsCallable('initiateMpesaPayment').call({
      'phone': phone,
      'amount': amount.toInt(),
      'propertyId': propertyId,
      'bookingId': bookingId,
      'accountReference': 'NestIQViewing',
      'description': 'Property Viewing Fee',
    });
    return Map<String, dynamic>.from(result.data as Map);
  }

  Future<Map<String, dynamic>> checkMpesaPaymentStatus({
    required String checkoutRequestId,
  }) async {
    final result = await _functions
        .httpsCallable('checkMpesaPaymentStatus')
        .call({'checkoutRequestId': checkoutRequestId});
    return Map<String, dynamic>.from(result.data as Map);
  }

  Future<Map<String, dynamic>> createStripePaymentIntent({
    required double amount,
    required String currency,
    required String propertyId,
  }) async {
    final result = await _functions
        .httpsCallable('createStripePaymentIntent')
        .call({
      'amount': (amount * 100).toInt(),
      'currency': currency.toLowerCase(),
      'propertyId': propertyId,
    });
    return Map<String, dynamic>.from(result.data as Map);
  }

  Future<String> recordTransaction(Transaction transaction) async {
    final ref =
        await _db.collection('transactions').add(transaction.toMap());
    return ref.id;
  }

  Stream<List<Transaction>> getUserTransactions(String userId) {
    return _db
        .collection('transactions')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => Transaction.fromFirestore(d))
            .toList());
  }

  Future<void> updateTransactionStatus(
    String id,
    TransactionStatus status,
    String? reference,
  ) async {
    await _db.collection('transactions').doc(id).update({
      'status': status.name,
      if (reference != null) 'paymentReference': reference,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}

// ─── Agent Service ────────────────────────────────────────────────────────────
class AgentService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<AgentProfile> getAgentProfile(String agentId) async {
    final doc = await _db.collection('agents').doc(agentId).get();
    if (!doc.exists) throw Exception('Agent not found');
    return AgentProfile.fromMap(doc.data()!, doc.id);
  }

  Stream<AgentProfile> getAgentProfileStream(String agentId) {
    return _db
        .collection('agents')
        .doc(agentId)
        .snapshots()
        .map((doc) => AgentProfile.fromMap(doc.data()!, doc.id));
  }

  Future<void> updateAgentProfile(
      String agentId, Map<String, dynamic> data) async {
    await _db.collection('agents').doc(agentId).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<String> uploadAgentAvatar(String agentId, File image) async {
    final ref =
        _storage.ref().child('agents/$agentId/avatar.jpg');
    final task = await ref.putFile(image);
    return await task.ref.getDownloadURL();
  }

  Future<List<AgentProfile>> getTopAgents() async {
    final snapshot = await _db
        .collection('agents')
        .where('isVerified', isEqualTo: true)
        .orderBy('rating', descending: true)
        .limit(10)
        .get();

    return snapshot.docs
        .map((doc) => AgentProfile.fromMap(doc.data(), doc.id))
        .toList();
  }
}

// ─── Admin Service ────────────────────────────────────────────────────────────
class AdminService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> approveProperty(String propertyId, bool approved) async {
    await _db.collection('properties').doc(propertyId).update({
      'isApproved': approved,
      'status': approved
          ? PropertyStatus.active.name
          : PropertyStatus.suspended.name,
      'reviewedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<List<Property>> getPendingProperties() async {
    final snapshot = await _db
        .collection('properties')
        .where('isApproved', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => Property.fromFirestore(doc))
        .toList();
  }

  Future<List<AppUser>> getAllUsers({UserRole? role}) async {
    Query query = _db
        .collection('users')
        .orderBy('createdAt', descending: true);
    if (role != null) {
      query = query.where('role', isEqualTo: role.name);
    }
    final snapshot = await query.limit(50).get();
    return snapshot.docs
        .map((doc) => AppUser.fromFirestore(doc))
        .toList();
  }

  Future<void> updateUserStatus(String userId, bool isActive) async {
    await _db.collection('users').doc(userId).update({
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateUserRole(String userId, UserRole role) async {
    final batch = _db.batch();

    batch.update(_db.collection('users').doc(userId), {
      'role': role.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (role == UserRole.agent) {
      final agentDoc =
          await _db.collection('agents').doc(userId).get();
      if (!agentDoc.exists) {
        final userDoc =
            await _db.collection('users').doc(userId).get();
        final data = userDoc.data() as Map<String, dynamic>;
        batch.set(_db.collection('agents').doc(userId), {
          'displayName': data['fullName'] ?? '',
          'email': data['email'] ?? '',
          'phone': data['phoneNumber'] ?? '',
          'rating': 0.0,
          'reviewCount': 0,
          'totalListings': 0,
          'soldCount': 0,
          'isVerified': false,
          'specializations': [],
          'memberSince': FieldValue.serverTimestamp(),
        });
      }
    }

    await batch.commit();
  }

  Future<Map<String, dynamic>> getDashboardStats() async {
    final results = await Future.wait([
      _db.collection('users').count().get(),
      _db
          .collection('properties')
          .where('isApproved', isEqualTo: true)
          .count()
          .get(),
      _db.collection('bookings').count().get(),
      _db
          .collection('transactions')
          .where('status', isEqualTo: 'completed')
          .count()
          .get(),
    ]);

    return {
      'totalUsers': results[0].count,
      'totalProperties': results[1].count,
      'totalBookings': results[2].count,
      'completedTransactions': results[3].count,
    };
  }

  Future<void> verifyAgent(String agentId, bool verified) async {
    await Future.wait([
      _db.collection('agents').doc(agentId).update({
        'isVerified': verified,
        'updatedAt': FieldValue.serverTimestamp(),
      }),
      _db.collection('users').doc(agentId).update({
        'isVerified': verified,
        'updatedAt': FieldValue.serverTimestamp(),
      }),
    ]);
  }
}