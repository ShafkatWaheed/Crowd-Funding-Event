import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/event/create_event_screen.dart';
import '../screens/event/edit_event_screen.dart';
import '../screens/event/event_detail_screen.dart';
import '../screens/event/ticket_receipt_screen.dart';
import '../screens/event/waitlist_screen.dart';
import '../screens/event/ticket_sales_screen.dart';
import '../screens/event/co_organizer_screen.dart';
import '../screens/event/claim_discounts_screen.dart';
import '../screens/manage/global_ticket_sales_screen.dart';
import '../screens/manage/global_waitlist_screen.dart';
import '../screens/manage/global_discounts_screen.dart';
import '../screens/venue/venue_list_screen.dart';
import '../screens/venue/create_venue_screen.dart';
import '../screens/ticket_strategy/ticket_strategies_screen.dart';
import '../screens/admin/admin_dashboard_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/profile/my_tickets_screen.dart';
import '../screens/profile/my_pledges_screen.dart';
import '../screens/legal/terms_screen.dart';
import '../screens/event/ticket_scanner_screen.dart';
import '../screens/sponsor/sponsor_onboarding_screen.dart';
import '../screens/sponsor/sponsorship_categories_screen.dart';
import '../screens/sponsor/bid_management_screen.dart';
import '../screens/sponsor/sponsor_ticket_screen.dart';
import '../screens/sponsor/sponsor_dashboard_screen.dart';
import '../screens/sponsor/organizer_sponsors_screen.dart';
import '../screens/sponsor/sponsor_category_templates_screen.dart';
import '../screens/bookmark/bookmarked_events_screen.dart';
import '../screens/profile/organizer_profile_screen.dart';
import '../screens/profile/sponsor_profile_screen.dart';

GoRouter createRouter(AuthProvider authProvider) {
  return GoRouter(
    refreshListenable: authProvider,
    redirect: (context, state) {
      final isAuthenticated = authProvider.isAuthenticated;
      final isLoading = authProvider.isLoading;
      final currentPath = state.uri.path;

      final isAuthRoute =
          currentPath == '/login' || currentPath == '/register';

      // Splash screen is shown by the MaterialApp builder while loading;
      // don't touch the URL so GoRouter preserves the browser path.
      if (isLoading) return null;

      // Not authenticated and not on an auth page → send to login,
      // preserving the intended destination so we can restore it later.
      if (!isAuthenticated && !isAuthRoute) {
        final intended = state.uri.toString();
        if (intended.isNotEmpty && intended != '/') {
          return '/login?redirect=${Uri.encodeComponent(intended)}';
        }
        return '/login';
      }

      // Authenticated but sitting on an auth page → leave.
      // Restore saved destination if present; otherwise go home.
      if (isAuthenticated && isAuthRoute) {
        final redirect = state.uri.queryParameters['redirect'];
        if (redirect != null &&
            redirect.isNotEmpty &&
            redirect != '/login' &&
            redirect != '/register') {
          return Uri.decodeComponent(redirect);
        }
        return '/';
      }

      return null;
    },
    routes: [
      // ─── Auth ───
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),

      // ─── Home ───
      GoRoute(
        path: '/',
        pageBuilder: (context, state) {
          final tab = state.uri.queryParameters['tab'];
          final idx = {'explore': 1, 'manage': 2, 'profile': 3}[tab] ?? 0;
          return NoTransitionPage(
            key: const ValueKey('home'),
            child: HomeScreen(initialTab: idx),
          );
        },
      ),

      // ─── Profile ───
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/my-tickets',
        builder: (context, state) {
          final eventIdStr = state.uri.queryParameters['eventId'];
          final eventId = eventIdStr != null ? int.tryParse(eventIdStr) : null;
          return MyTicketsScreen(filterEventId: eventId);
        },
      ),

      GoRoute(
        path: '/my-pledges',
        builder: (context, state) => const MyPledgesScreen(),
      ),

      // ─── Legal ───
      GoRoute(
        path: '/terms',
        builder: (context, state) {
          final role = state.uri.queryParameters['role'] ?? 'customer';
          return TermsScreen(role: role);
        },
      ),

      // ─── Events ───
      GoRoute(
        path: '/events/create',
        builder: (context, state) => const CreateEventScreen(),
      ),
      GoRoute(
        path: '/events/:id',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return EventDetailScreen(eventId: id);
        },
      ),
      GoRoute(
        path: '/events/:id/edit',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return EditEventScreen(eventId: id);
        },
      ),
      GoRoute(
        path: '/events/:id/waitlist',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return WaitlistScreen(eventId: id);
        },
      ),
      GoRoute(
        path: '/events/:id/ticket-waitlist',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return WaitlistScreen(eventId: id, initialTicketView: true);
        },
      ),
      GoRoute(
        path: '/events/:id/ticket-sales',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return TicketSalesScreen(eventId: id);
        },
      ),
      GoRoute(
        path: '/events/:id/scanned-tickets',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return TicketSalesScreen(eventId: id, scannedOnly: true);
        },
      ),
      GoRoute(
        path: '/events/:id/scan',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          final title = state.uri.queryParameters['title'];
          return TicketScannerScreen(eventId: id, eventTitle: title);
        },
      ),
      GoRoute(
        path: '/events/:id/tickets/:saleId/receipt',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          final saleId = int.parse(state.pathParameters['saleId']!);
          return TicketReceiptScreen(eventId: id, saleId: saleId);
        },
      ),
      GoRoute(
        path: '/events/:id/co-organizers',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return CoOrganizerScreen(eventId: id);
        },
      ),
      GoRoute(
        path: '/events/:id/discounts',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return ClaimDiscountsScreen(eventId: id);
        },
      ),
      // ─── Global Manage pages ───
      GoRoute(
        path: '/manage/ticket-sales',
        builder: (context, state) =>
            const GlobalTicketSalesScreen(scannedOnly: false),
      ),
      GoRoute(
        path: '/manage/scanned-tickets',
        builder: (context, state) =>
            const GlobalTicketSalesScreen(scannedOnly: true),
      ),
      GoRoute(
        path: '/manage/waitlist',
        builder: (context, state) => const GlobalWaitlistScreen(),
      ),
      GoRoute(
        path: '/manage/ticket-waitlist',
        builder: (context, state) =>
            const GlobalWaitlistScreen(initialTicketView: true),
      ),
      GoRoute(
        path: '/manage/discounts',
        builder: (context, state) => const GlobalDiscountsScreen(),
      ),

      // ─── Venues ───
      GoRoute(
        path: '/venues',
        builder: (context, state) => const VenueListScreen(),
      ),
      GoRoute(
        path: '/venues/create',
        builder: (context, state) => const CreateVenueScreen(),
      ),

      // ─── Ticket Strategies ───
      GoRoute(
        path: '/ticket-strategies',
        builder: (context, state) => const TicketStrategiesScreen(),
      ),

      // ─── Sponsor Category Templates ───
      GoRoute(
        path: '/sponsor-category-templates',
        builder: (context, state) => const SponsorCategoryTemplatesScreen(),
      ),

      // ─── Organizer: Sponsors ───
      GoRoute(
        path: '/manage/sponsors',
        builder: (context, state) => const OrganizerSponsorsScreen(),
      ),

      // ─── Sponsor ───
      GoRoute(
        path: '/sponsor/onboarding',
        builder: (context, state) => const SponsorOnboardingScreen(),
      ),
      GoRoute(
        path: '/events/:id/sponsorships',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return SponsorshipCategoriesScreen(eventId: id);
        },
      ),
      GoRoute(
        path: '/sponsor/dashboard',
        builder: (context, state) => const SponsorDashboardScreen(),
      ),
      GoRoute(
        path: '/sponsor/tickets',
        builder: (context, state) => const SponsorTicketScreen(),
      ),
      GoRoute(
        path: '/events/:id/sponsorships/:catId/bids',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          final catId = int.parse(state.pathParameters['catId']!);
          final catName = state.uri.queryParameters['name'];
          return BidManagementScreen(
              eventId: id, categoryId: catId, categoryName: catName);
        },
      ),

      // ─── Bookmarks ───
      GoRoute(
        path: '/bookmarks',
        builder: (context, state) => const BookmarkedEventsScreen(),
      ),

      // ─── Public Profiles ───
      GoRoute(
        path: '/users/:id/profile',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return OrganizerProfileScreen(userId: id);
        },
      ),
      GoRoute(
        path: '/users/:id/sponsor-profile',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          final extra = state.extra as Map<String, dynamic>? ?? {};
          final isOrganizerView = extra['isOrganizerView'] == true;
          return SponsorProfileScreen(
            userId: id,
            isOrganizerView: isOrganizerView,
          );
        },
      ),

      // ─── Admin ───
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminDashboardScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Page Not Found')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text('Page not found', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go('/'),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    ),
  );
}
