import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../models/models.dart';
import '../services/firebase_services.dart';

// ─── Service Providers ────────────────────────────────────────────────────────
final authServiceProvider = Provider<AuthService>((ref) => AuthService());
final propertyServiceProvider = Provider<PropertyService>((ref) => PropertyService());
final bookingServiceProvider = Provider<BookingService>((ref) => BookingService());
final paymentServiceProvider = Provider<PaymentService>((ref) => PaymentService());
final agentServiceProvider = Provider<AgentService>((ref) => AgentService());
final adminServiceProvider = Provider<AdminService>((ref) => AdminService());

// ─── Auth Providers ───────────────────────────────────────────────────────────
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

final currentUserProvider = FutureProvider<AppUser?>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return null;
  return ref.read(authServiceProvider).getCurrentUserData();
});

final currentUserRoleProvider = Provider<UserRole>((ref) {
  final user = ref.watch(currentUserProvider).value;
  return user?.role ?? UserRole.user;
});

// ─── Property Providers ───────────────────────────────────────────────────────
final propertyFilterProvider = StateProvider<PropertyFilter>(
  (ref) => const PropertyFilter(),
);

final propertiesProvider = FutureProvider.family<List<Property>, PropertyFilter>(
  (ref, filter) async {
    return ref.read(propertyServiceProvider).getProperties(filter: filter);
  },
);

final featuredPropertiesProvider = FutureProvider<List<Property>>((ref) {
  return ref.read(propertyServiceProvider).getFeaturedProperties();
});

final propertyDetailProvider = StreamProvider.family<Property, String>(
  (ref, id) => ref.read(propertyServiceProvider).getPropertyStream(id),
);

final savedPropertiesProvider = FutureProvider<List<Property>>((ref) async {
  final user = ref.watch(currentUserProvider).value;
  if (user == null || user.savedProperties.isEmpty) return [];
  return ref
      .read(propertyServiceProvider)
      .getSavedProperties(user.savedProperties);
});

final agentPropertiesProvider = FutureProvider.family<List<Property>, String>(
  (ref, agentId) =>
      ref.read(propertyServiceProvider).getAgentProperties(agentId),
);

// ─── Map Providers ────────────────────────────────────────────────────────────

/// Holds the map filter selections (listing type + property type).
/// Separated from bounds so filter changes trigger a re-fetch independently.
final mapFilterProvider = StateProvider<MapFilter>(
  (ref) => const MapFilter(),
);

/// Holds the current visible map bounds set by MapSearchScreen.
final mapBoundsProvider = StateProvider<MapBounds?>((ref) => null);

/// Fetches properties within the current map bounds + active filters.
/// Re-runs automatically whenever bounds or filters change.
final mapPropertiesProvider = FutureProvider<List<Property>>((ref) async {
  final bounds = ref.watch(mapBoundsProvider);
  final filter = ref.watch(mapFilterProvider);
  if (bounds == null) return [];

  return ref.read(propertyServiceProvider).getPropertiesInBounds(
        swLat: bounds.swLat,
        swLng: bounds.swLng,
        neLat: bounds.neLat,
        neLng: bounds.neLng,
        listingType: filter.listingType,
        type: filter.propertyType,
      );
});

// ─── Booking Providers ────────────────────────────────────────────────────────
final userBookingsProvider = StreamProvider<List<Booking>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return const Stream.empty();
  return ref.read(bookingServiceProvider).getUserBookings(user.uid);
});

final agentBookingsProvider = StreamProvider<List<Booking>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return const Stream.empty();
  return ref.read(bookingServiceProvider).getAgentBookings(user.uid);
});

// ─── Agent Providers ──────────────────────────────────────────────────────────
final agentProfileProvider = StreamProvider.family<AgentProfile, String>(
  (ref, agentId) =>
      ref.read(agentServiceProvider).getAgentProfileStream(agentId),
);

final topAgentsProvider = FutureProvider<List<AgentProfile>>((ref) {
  return ref.read(agentServiceProvider).getTopAgents();
});

// ─── Transaction Providers ────────────────────────────────────────────────────
final userTransactionsProvider = StreamProvider<List<Transaction>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return const Stream.empty();
  return ref
      .read(paymentServiceProvider)
      .getUserTransactions(user.uid)
      .map((transactions) => transactions.cast<Transaction>());
});

// ─── Admin Providers ──────────────────────────────────────────────────────────
final pendingPropertiesProvider = FutureProvider<List<Property>>((ref) {
  return ref.read(adminServiceProvider).getPendingProperties();
});

final allUsersProvider = FutureProvider<List<AppUser>>((ref) {
  return ref.read(adminServiceProvider).getAllUsers();
});

final dashboardStatsProvider = FutureProvider<Map<String, dynamic>>((ref) {
  return ref.read(adminServiceProvider).getDashboardStats();
});

// ─── Search Provider ──────────────────────────────────────────────────────────
final searchQueryProvider = StateProvider<String>((ref) => '');

final searchResultsProvider = FutureProvider<List<Property>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  if (query.isEmpty) return [];
  return ref.read(propertyServiceProvider).searchProperties(query);
});