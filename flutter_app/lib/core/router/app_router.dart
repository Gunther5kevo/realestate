import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/providers.dart';
import '../providers/onboarding_provider.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/register_screen.dart';
import '../../screens/auth/forgot_password_screen.dart';
import '../../screens/auth/email_verification_screen.dart';
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
import '../../screens/profile/transactions_screen.dart' hide HelpSupportScreen;
import '../../screens/profile/help_support_screen.dart';

// ─── Reusable access-denied screen ───────────────────────────────────────────

class _AccessDeniedScreen extends StatelessWidget {
  final String message;
  const _AccessDeniedScreen(
      {this.message = 'You don\'t have permission to view this page.'});

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
                style:
                    const TextStyle(fontSize: 16, color: Colors.grey),
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

      final user = authState.value;
      final isLoggedIn = user != null;
      // NOTE: FirebaseAuth caches emailVerified on the User object from the
      // last token refresh / sign-in. The verification screen calls
      // user.reload() and re-checks before navigating to '/home', so this
      // flag becomes accurate again as soon as that happens.
      final isEmailVerified = user?.emailVerified ?? false;
      final hasSeenOnboarding = onboardingAsync.value ?? false;
      final location = state.matchedLocation;
      final isAuthRoute = location.startsWith('/auth');
      final isVerifyRoute = location == '/auth/verify-email';
      final isOnboarding = location == '/onboarding';

      if (!hasSeenOnboarding) {
        return isOnboarding ? null : '/onboarding';
      }

      // Not logged in at all → must go through login/register/forgot-password.
      if (!isLoggedIn) {
        if (isOnboarding) return '/auth/login';
        return isAuthRoute ? null : '/auth/login';
      }

      // Logged in but email not verified → must go through verify-email,
      // except they can still reach forgot-password if locked out.
      if (isLoggedIn && !isEmailVerified) {
        if (isVerifyRoute) return null;
        if (location == '/auth/forgot-password') return null;
        return '/auth/verify-email';
      }

      // Logged in and verified → keep them out of onboarding/auth screens.
      if (isLoggedIn && isEmailVerified && (isOnboarding || isAuthRoute)) {
        return '/home';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (_, __) => const OnboardingScreen(),
      ),
      GoRoute(path: '/auth/login', builder: (_, __) => const LoginScreen()),
      GoRoute(
          path: '/auth/register',
          builder: (_, __) => const RegisterScreen()),
      GoRoute(
          path: '/auth/forgot-password',
          builder: (_, __) => const ForgotPasswordScreen()),
      GoRoute(
          path: '/auth/verify-email',
          builder: (_, __) => const EmailVerificationScreen()),

      // ── Shell (bottom nav) ────────────────────────────────────────────
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
          GoRoute(
              path: '/search', builder: (_, __) => const SearchScreen()),
          GoRoute(
              path: '/saved',
              builder: (_, __) => const SavedPropertiesScreen()),
          GoRoute(
              path: '/bookings',
              builder: (_, __) => const BookingsScreen()),
          GoRoute(
              path: '/profile',
              builder: (_, __) => const ProfileScreen()),
        ],
      ),

      // ── Standalone search — pushed from detail/agent screens ──────────
      GoRoute(
        path: '/agent-listings',
        builder: (_, state) {
          final agentId = state.uri.queryParameters['agentId'];
          if (agentId == null || agentId.isEmpty) {
            return const SearchScreen();
          }
          return SearchScreen(initialAgentId: agentId);
        },
      ),

      // ── Property detail ───────────────────────────────────────────────
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
                child:
                    Text('Payment session expired. Please try again.'),
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

      // ── Agent listings ─────────────────────────────────────────────────
      // Public browsing route — any signed-in user can see an agent's
      // listings. The old _AgentListingsGuard was intended for management
      // (edit/delete) but was also blocking regular users from browsing,
      // which is the more common case from the property detail screen.
      //
      // _AgentListingsRoute now passes canManage=true only to the agent
      // themselves or admins, so AgentListingsScreen can gate the
      // edit/delete actions behind that flag without blocking the view.
      GoRoute(
        path: '/agent/:id/listings',
        builder: (_, state) => _AgentListingsRoute(
          agentId: state.pathParameters['id']!,
        ),
      ),

      // ── Agent-only management routes ──────────────────────────────────
      GoRoute(
        path: '/add-listing',
        builder: (_, __) => const _AgentOnlyGuard(
          child: AddListingScreen(),
        ),
      ),
      GoRoute(
        path: '/edit-listing/:id',
        builder: (_, state) => _AgentOnlyGuard(
          child:
              AddListingScreen(editPropertyId: state.pathParameters['id']),
        ),
      ),

      GoRoute(
          path: '/edit-profile',
          builder: (_, __) => const EditProfileScreen()),
      GoRoute(
          path: '/notifications',
          builder: (_, __) => const NotificationsScreen()),

      // ── Profile sub-pages ──────────────────────────────────────────────
      GoRoute(
          path: '/transactions',
          builder: (_, __) => const TransactionsScreen()),
      GoRoute(
          path: '/help-support',
          builder: (_, __) => const HelpSupportScreen()),
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
          message:
              'Only registered agents can manage listings.\n\nContact us to upgrade your account.',
        );
      },
    );
  }
}

/// Public browsing route for an agent's listings.
///
/// Any signed-in user lands here successfully. [canManage] is only true
/// for the agent themselves or an admin — pass it into [AgentListingsScreen]
/// to conditionally show edit/delete actions without blocking the view.
class _AgentListingsRoute extends ConsumerWidget {
  final String agentId;
  const _AgentListingsRoute({required this.agentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      // Render immediately while auth resolves — no gate, canManage=false
      // so no destructive actions are visible until identity is confirmed.
      loading: () => AgentListingsScreen(agentId: agentId, canManage: false),
      error: (_, __) => AgentListingsScreen(agentId: agentId, canManage: false),
      data: (user) {
        final canManage = user != null &&
            (user.id == agentId || user.role == UserRole.admin);
        return AgentListingsScreen(agentId: agentId, canManage: canManage);
      },
    );
  }
}