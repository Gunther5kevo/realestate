import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/providers.dart';
import '../providers/onboarding_provider.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/register_screen.dart';
import '../../screens/auth/forgot_password_screen.dart';
import '../../screens/home/home_screen.dart';
import '../../screens/search/search_screen.dart';
import '../../screens/search/map_search_screen.dart';
import '../../screens/property/property_detail_screen.dart';
import '../../screens/payment/payment_screen.dart';
import '../../screens/bookings/bookings_screen.dart';
import '../../screens/profile/profile_screen.dart';
import '../../screens/profile/edit_profile_screen.dart';
import '../../screens/agent/agent_profile_screen.dart';
import '../../screens/agent/agent_listings_screen.dart';
import '../../screens/agent/add_listing_screen.dart';
import '../../screens/notifications/notifications_screen.dart';
import '../../screens/saved/saved_properties_screen.dart';
import '../../screens/shell/main_shell.dart';
import '../../screens/onboarding/onboarding_screen.dart';
import '../../core/models/models.dart';

// ─── Reusable access-denied screen ───────────────────────────────────────────

class _AccessDeniedScreen extends StatelessWidget {
  final String message;
  const _AccessDeniedScreen({this.message = 'You don\'t have permission to view this page.'});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Access Denied')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => GoRouter.of(context).go('/home'),
                child: const Text('Go Home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Router ───────────────────────────────────────────────────────────────────

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final onboardingAsync = ref.watch(onboardingCompletedProvider);

  return GoRouter(
    initialLocation: '/onboarding',
    debugLogDiagnostics: false,
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Page not found')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text('No route found for: ${state.uri}',
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => GoRouter.of(context).go('/home'),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    ),
    redirect: (context, state) {
      if (authState.isLoading) return null;
      if (onboardingAsync.isLoading) return null;

      final isLoggedIn = authState.value != null;
      final hasSeenOnboarding = onboardingAsync.value ?? false;
      final location = state.matchedLocation;
      final isAuthRoute = location.startsWith('/auth');
      final isOnboarding = location == '/onboarding';

      if (!hasSeenOnboarding) {
        return isOnboarding ? null : '/onboarding';
      }
      if (isLoggedIn && (isOnboarding || isAuthRoute)) return '/home';
      if (!isLoggedIn && !isAuthRoute && !isOnboarding) return '/auth/login';

      return null;
    },
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (_, __) => const OnboardingScreen(),
      ),
      GoRoute(path: '/auth/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/auth/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(
          path: '/auth/forgot-password',
          builder: (_, __) => const ForgotPasswordScreen()),

      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
          GoRoute(path: '/search', builder: (_, __) => const SearchScreen()),
          GoRoute(path: '/saved', builder: (_, __) => const SavedPropertiesScreen()),
          GoRoute(path: '/bookings', builder: (_, __) => const BookingsScreen()),
          GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
        ],
      ),

      GoRoute(
        path: '/property/:id',
        builder: (_, state) =>
            PropertyDetailScreen(propertyId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/map',
        builder: (_, state) =>
            MapSearchScreen(initialProperty: state.extra as Property?),
      ),
      GoRoute(
        path: '/payment',
        builder: (_, state) {
          final args = state.extra as Map<String, dynamic>?;
          if (args == null ||
              args['property'] == null ||
              args['scheduledDate'] == null ||
              args['timeSlot'] == null) {
            return const Scaffold(
              body: Center(
                child: Text('Payment session expired. Please try again.'),
              ),
            );
          }
          return PaymentScreen(
            property: args['property'] as Property,
            scheduledDate: args['scheduledDate'] as DateTime,
            timeSlot: args['timeSlot'] as String,
            notes: args['notes'] as String?,
          );
        },
      ),

      GoRoute(
        path: '/agent/:id',
        builder: (_, state) =>
            AgentProfileScreen(agentId: state.pathParameters['id']!),
      ),

      // ── Agent-only routes ──────────────────────────────────────────────────
      // /agent/:id/listings — only the agent themselves or an admin
      GoRoute(
        path: '/agent/:id/listings',
        builder: (_, state) => _AgentListingsGuard(
          agentId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/add-listing',
        builder: (_, __) => const _AgentOnlyGuard(
          child: AddListingScreen(),
        ),
      ),
      GoRoute(
        path: '/edit-listing/:id',
        builder: (_, state) => _AgentOnlyGuard(
          child: AddListingScreen(editPropertyId: state.pathParameters['id']),
        ),
      ),

      GoRoute(path: '/edit-profile', builder: (_, __) => const EditProfileScreen()),
      GoRoute(path: '/notifications', builder: (_, __) => const NotificationsScreen()),
    ],
  );
});

// ─── Guard widgets ────────────────────────────────────────────────────────────

/// Blocks the route unless the current user is an agent or admin.
class _AgentOnlyGuard extends ConsumerWidget {
  final Widget child;
  const _AgentOnlyGuard({required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const _AccessDeniedScreen(),
      data: (user) {
        if (user == null) return const _AccessDeniedScreen();
        if (user.role == UserRole.agent || user.role == UserRole.admin) {
          return child;
        }
        return const _AccessDeniedScreen(
          message: 'Only registered agents can manage listings.\n\nContact us to upgrade your account.',
        );
      },
    );
  }
}

/// Blocks /agent/:id/listings unless the viewer IS that agent, or is an admin.
class _AgentListingsGuard extends ConsumerWidget {
  final String agentId;
  const _AgentListingsGuard({required this.agentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const _AccessDeniedScreen(),
      data: (user) {
        if (user == null) return const _AccessDeniedScreen();
        final isSelf = user.id == agentId;
        final isAdmin = user.role == UserRole.admin;
        if (isSelf || isAdmin) {
          return AgentListingsScreen(agentId: agentId);
        }
        return const _AccessDeniedScreen(
          message: 'You can only manage your own listings.',
        );
      },
    );
  }
}