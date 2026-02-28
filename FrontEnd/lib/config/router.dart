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
import '../screens/event/refund_requests_screen.dart';
import '../screens/event/co_organizer_screen.dart';
import '../screens/event/claim_discounts_screen.dart';
import '../screens/manage/co_organized_events_screen.dart';
import '../screens/manage/global_refund_requests_screen.dart';
import '../screens/manage/global_ticket_sales_screen.dart';
import '../screens/manage/global_waitlist_screen.dart';
import '../screens/manage/global_discounts_screen.dart';
import '../screens/manage/organizer_pledges_screen.dart';
import '../screens/venue/venue_list_screen.dart';
import '../screens/venue/create_venue_screen.dart';
import '../screens/ticket_strategy/ticket_strategies_screen.dart';
import '../screens/admin/admin_dashboard_screen.dart';
import '../screens/admin/admin_payouts_screen.dart';
import '../screens/admin/admin_transactions_screen.dart';
import '../screens/admin/admin_escrow_pipeline_screen.dart';
import '../screens/admin/admin_run_logs_screen.dart';
import '../screens/admin/admin_user_detail_screen.dart';
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
import '../screens/chat/bid_chat_screen.dart';
import '../screens/chat/conversations_screen.dart';
import '../screens/home/tabs/profile_tab.dart';
import '../screens/profile/organizer_profile_screen.dart';
import '../screens/profile/sponsor_profile_screen.dart';
import 'page_transitions.dart';

GoRouter createRouter(AuthProvider authProvider) {
  return GoRouter(
    refreshListenable: authProvider,
    redirect: (context, state) {
      final isAuthenticated = authProvider.isAuthenticated;
      final isLoading = authProvider.isLoading;
      final currentPath = state.uri.path;

      final isAuthRoute =
          currentPath == '/login' || currentPath == '/register';

      if (isLoading) return null;

      if (!isAuthenticated && !isAuthRoute) {
        final intended = state.uri.toString();
        if (intended.isNotEmpty && intended != '/') {
          return '/login?redirect=${Uri.encodeComponent(intended)}';
        }
        return '/login';
      }

      if (isAuthenticated && isAuthRoute) {
        if (authProvider.user?.isAdmin == true) return '/admin';
        final redirect = state.uri.queryParameters['redirect'];
        if (redirect != null &&
            redirect.isNotEmpty &&
            redirect != '/login' &&
            redirect != '/register') {
          return Uri.decodeComponent(redirect);
        }
        return '/';
      }

      if (isAuthenticated) {
        final isAdminRoute = currentPath == '/admin' ||
            currentPath.startsWith('/admin/');
        final isEventRoute = currentPath.startsWith('/events/');
        if (authProvider.user?.isAdmin == true && !isAdminRoute && !isEventRoute) {
          return '/admin';
        }
        if (authProvider.user?.isAdmin != true && isAdminRoute) {
          return '/';
        }
      }

      return null;
    },
    routes: [
      // ─── Auth (fade-through) ───
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) =>
            fadeThroughPage(child: const LoginScreen()),
      ),
      GoRoute(
        path: '/register',
        pageBuilder: (context, state) =>
            fadeThroughPage(child: const RegisterScreen()),
      ),

      // ─── Home (no transition — tab switching) ───
      GoRoute(
        path: '/',
        pageBuilder: (context, state) {
          final tab = state.uri.queryParameters['tab'];
          final idx = {'explore': 1, 'manage': 2, 'channel': 3, 'profile': 3}[tab] ?? 0;
          return NoTransitionPage(
            key: const ValueKey('home'),
            child: HomeScreen(initialTab: idx),
          );
        },
      ),

      // ─── Profile (fade-through) ───
      GoRoute(
        path: '/profile',
        pageBuilder: (context, state) =>
            fadeThroughPage(child: const ProfileScreen()),
      ),
      GoRoute(
        path: '/account',
        pageBuilder: (context, state) => fadeThroughPage(
          child: const Scaffold(body: ProfileTab()),
        ),
      ),
      GoRoute(
        path: '/my-tickets',
        pageBuilder: (context, state) {
          final eventIdStr = state.uri.queryParameters['eventId'];
          final eventId = eventIdStr != null ? int.tryParse(eventIdStr) : null;
          return fadeThroughPage(child: MyTicketsScreen(filterEventId: eventId));
        },
      ),
      GoRoute(
        path: '/my-pledges',
        pageBuilder: (context, state) =>
            fadeThroughPage(child: const MyPledgesScreen()),
      ),

      // ─── Legal (fade-through) ───
      GoRoute(
        path: '/terms',
        pageBuilder: (context, state) {
          final role = state.uri.queryParameters['role'] ?? 'customer';
          return fadeThroughPage(child: TermsScreen(role: role));
        },
      ),

      // ─── Events ───
      GoRoute(
        path: '/events/create',
        pageBuilder: (context, state) =>
            sharedAxisPage(child: const CreateEventScreen()),
      ),
      GoRoute(
        path: '/events/:id',
        pageBuilder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          final extra = state.extra as Map<String, dynamic>? ?? {};
          final readOnly = extra['readOnly'] == true;
          return fadeScalePage(
              child: EventDetailScreen(eventId: id, readOnly: readOnly));
        },
      ),
      GoRoute(
        path: '/events/:id/edit',
        pageBuilder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return sharedAxisPage(child: EditEventScreen(eventId: id));
        },
      ),
      GoRoute(
        path: '/events/:id/waitlist',
        pageBuilder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return sharedAxisPage(child: WaitlistScreen(eventId: id));
        },
      ),
      GoRoute(
        path: '/events/:id/ticket-waitlist',
        pageBuilder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return sharedAxisPage(
              child: WaitlistScreen(eventId: id, initialTicketView: true));
        },
      ),
      GoRoute(
        path: '/events/:id/ticket-sales',
        pageBuilder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return sharedAxisPage(child: TicketSalesScreen(eventId: id));
        },
      ),
      GoRoute(
        path: '/events/:id/refund-requests',
        pageBuilder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return sharedAxisPage(child: RefundRequestsScreen(eventId: id));
        },
      ),
      GoRoute(
        path: '/events/:id/scanned-tickets',
        pageBuilder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return sharedAxisPage(
              child: TicketSalesScreen(eventId: id, scannedOnly: true));
        },
      ),
      GoRoute(
        path: '/events/:id/scan',
        pageBuilder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          final title = state.uri.queryParameters['title'];
          return sharedAxisPage(
              child: TicketScannerScreen(eventId: id, eventTitle: title));
        },
      ),
      GoRoute(
        path: '/events/:id/tickets/:saleId/receipt',
        pageBuilder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          final saleId = int.parse(state.pathParameters['saleId']!);
          return fadeScalePage(
              child: TicketReceiptScreen(eventId: id, saleId: saleId));
        },
      ),
      GoRoute(
        path: '/events/:id/co-organizers',
        pageBuilder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return sharedAxisPage(child: CoOrganizerScreen(eventId: id));
        },
      ),
      GoRoute(
        path: '/events/:id/discounts',
        pageBuilder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return sharedAxisPage(child: ClaimDiscountsScreen(eventId: id));
        },
      ),

      // ─── Global Manage pages (fade-through) ───
      GoRoute(
        path: '/manage/ticket-sales',
        pageBuilder: (context, state) {
          final eventStatus = state.uri.queryParameters['event_status'];
          final genre = state.uri.queryParameters['genre'];
          final eventIdStr = state.uri.queryParameters['event_id'];
          final eventId = eventIdStr != null ? int.tryParse(eventIdStr) : null;
          final eventTitle = state.uri.queryParameters['event_title'];
          return fadeThroughPage(
              child: GlobalTicketSalesScreen(scannedOnly: false, eventStatus: eventStatus, genre: genre, eventId: eventId, eventTitle: eventTitle));
        },
      ),
      GoRoute(
        path: '/manage/scanned-tickets',
        pageBuilder: (context, state) => fadeThroughPage(
            child: const GlobalTicketSalesScreen(scannedOnly: true)),
      ),
      GoRoute(
        path: '/manage/waitlist',
        pageBuilder: (context, state) =>
            fadeThroughPage(child: const GlobalWaitlistScreen()),
      ),
      GoRoute(
        path: '/manage/ticket-waitlist',
        pageBuilder: (context, state) => fadeThroughPage(
            child: const GlobalWaitlistScreen(initialTicketView: true)),
      ),
      GoRoute(
        path: '/manage/refunds',
        pageBuilder: (context, state) =>
            fadeThroughPage(child: const GlobalRefundRequestsScreen()),
      ),
      GoRoute(
        path: '/manage/discounts',
        pageBuilder: (context, state) =>
            fadeThroughPage(child: const GlobalDiscountsScreen()),
      ),
      GoRoute(
        path: '/manage/co-organized',
        pageBuilder: (context, state) =>
            fadeThroughPage(child: const CoOrganizedEventsScreen()),
      ),
      GoRoute(
        path: '/manage/pledges',
        pageBuilder: (context, state) {
          final eventStatus = state.uri.queryParameters['event_status'];
          final genre = state.uri.queryParameters['genre'];
          final eventIdStr = state.uri.queryParameters['event_id'];
          final eventId = eventIdStr != null ? int.tryParse(eventIdStr) : null;
          final eventTitle = state.uri.queryParameters['event_title'];
          return fadeThroughPage(
              child: OrganizerPledgesScreen(eventStatus: eventStatus, genre: genre, eventId: eventId, eventTitle: eventTitle));
        },
      ),

      // ─── Venues (fade-through) ───
      GoRoute(
        path: '/venues',
        pageBuilder: (context, state) =>
            fadeThroughPage(child: const VenueListScreen()),
      ),
      GoRoute(
        path: '/venues/create',
        pageBuilder: (context, state) =>
            fadeThroughPage(child: const CreateVenueScreen()),
      ),

      // ─── Ticket Strategies (fade-through) ───
      GoRoute(
        path: '/ticket-strategies',
        pageBuilder: (context, state) =>
            fadeThroughPage(child: const TicketStrategiesScreen()),
      ),

      // ─── Sponsor Category Templates (fade-through) ───
      GoRoute(
        path: '/sponsor-category-templates',
        pageBuilder: (context, state) =>
            fadeThroughPage(child: const SponsorCategoryTemplatesScreen()),
      ),

      // ─── Organizer: Sponsors (fade-through) ───
      GoRoute(
        path: '/manage/sponsors',
        pageBuilder: (context, state) {
          final eventStatus = state.uri.queryParameters['event_status'];
          final genre = state.uri.queryParameters['genre'];
          final eventIdStr = state.uri.queryParameters['event_id'];
          final eventId = eventIdStr != null ? int.tryParse(eventIdStr) : null;
          final eventTitle = state.uri.queryParameters['event_title'];
          return fadeThroughPage(
              child: OrganizerSponsorsScreen(eventStatus: eventStatus, genre: genre, eventId: eventId, eventTitle: eventTitle));
        },
      ),

      // ─── Sponsor (fade-through) ───
      GoRoute(
        path: '/sponsor/onboarding',
        pageBuilder: (context, state) =>
            fadeThroughPage(child: const SponsorOnboardingScreen()),
      ),
      GoRoute(
        path: '/events/:id/sponsorships',
        pageBuilder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return sharedAxisPage(
              child: SponsorshipCategoriesScreen(eventId: id));
        },
      ),
      GoRoute(
        path: '/sponsor/dashboard',
        pageBuilder: (context, state) =>
            fadeThroughPage(child: const SponsorDashboardScreen()),
      ),
      GoRoute(
        path: '/sponsor/tickets',
        pageBuilder: (context, state) =>
            fadeThroughPage(child: const SponsorTicketScreen()),
      ),
      GoRoute(
        path: '/events/:id/sponsorships/:catId/bids',
        pageBuilder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          final catId = int.parse(state.pathParameters['catId']!);
          final catName = state.uri.queryParameters['name'];
          return sharedAxisPage(
            child: BidManagementScreen(
                eventId: id, categoryId: catId, categoryName: catName),
          );
        },
      ),

      // ─── Chat (fade-through) ───
      GoRoute(
        path: '/chat',
        pageBuilder: (context, state) =>
            fadeThroughPage(child: const ConversationsScreen()),
      ),
      GoRoute(
        path: '/chat/bid/:bidId',
        pageBuilder: (context, state) {
          final bidId = int.parse(state.pathParameters['bidId']!);
          final name = state.uri.queryParameters['name'];
          final writable = state.uri.queryParameters['writable'] != 'false';
          final eventIdStr = state.uri.queryParameters['eventId'];
          final eventId = eventIdStr != null ? int.tryParse(eventIdStr) : null;
          return sharedAxisPage(
            child: BidChatScreen(
              bidId: bidId,
              participantName: name,
              isWritable: writable,
              eventId: eventId,
            ),
          );
        },
      ),

      // ─── Bookmarks (fade-through) ───
      GoRoute(
        path: '/bookmarks',
        pageBuilder: (context, state) =>
            fadeThroughPage(child: const BookmarkedEventsScreen()),
      ),

      // ─── Public Profiles (fade-scale) ───
      GoRoute(
        path: '/users/:id/profile',
        pageBuilder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return fadeScalePage(child: OrganizerProfileScreen(userId: id));
        },
      ),
      GoRoute(
        path: '/users/:id/sponsor-profile',
        pageBuilder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          final extra = state.extra as Map<String, dynamic>? ?? {};
          final isOrganizerView = extra['isOrganizerView'] == true;
          return fadeScalePage(
            child: SponsorProfileScreen(
              userId: id,
              isOrganizerView: isOrganizerView,
            ),
          );
        },
      ),

      // ─── Admin (fade-through) ───
      GoRoute(
        path: '/admin',
        pageBuilder: (context, state) =>
            fadeThroughPage(child: const AdminDashboardScreen()),
      ),
      GoRoute(
        path: '/admin/users/:id',
        pageBuilder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return fadeThroughPage(child: AdminUserDetailScreen(userId: id));
        },
      ),
      GoRoute(
        path: '/admin/payouts',
        pageBuilder: (context, state) =>
            fadeThroughPage(child: const AdminPayoutsScreen()),
      ),
      GoRoute(
        path: '/admin/transactions',
        pageBuilder: (context, state) =>
            fadeThroughPage(child: const AdminTransactionsScreen()),
      ),
      GoRoute(
        path: '/admin/escrow-pipeline',
        pageBuilder: (context, state) =>
            fadeThroughPage(child: const AdminEscrowPipelineScreen()),
      ),
      GoRoute(
        path: '/admin/run-logs',
        pageBuilder: (context, state) =>
            fadeThroughPage(child: const AdminRunLogsScreen()),
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
