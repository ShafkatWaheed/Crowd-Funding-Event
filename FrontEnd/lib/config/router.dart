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
import '../screens/legal/terms_screen.dart';
import '../screens/event/ticket_scanner_screen.dart';

GoRouter createRouter(AuthProvider authProvider) {
  return GoRouter(
    refreshListenable: authProvider,
    initialLocation: '/login',
    redirect: (context, state) {
      final isAuthenticated = authProvider.isAuthenticated;
      final isLoading = authProvider.isLoading;
      final currentPath = state.uri.path;

      final isAuthRoute =
          currentPath == '/login' || currentPath == '/register';

      // ── While auth is still loading, keep user on an auth route ──
      // This prevents the home screen from flashing before login resolves.
      if (isLoading) {
        if (!isAuthRoute) return '/login';
        return null; // already on login/register, stay there
      }

      // ── Auth resolved: not authenticated → force to login ──
      if (!isAuthenticated && !isAuthRoute) {
        return '/login';
      }

      // ── Auth resolved: authenticated but still on auth route → go home ──
      if (isAuthenticated && isAuthRoute) {
        return '/';
      }

      return null; // no redirect needed
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
        builder: (context, state) => const HomeScreen(),
      ),

      // ─── Profile ───
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/my-tickets',
        builder: (context, state) => const MyTicketsScreen(),
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
