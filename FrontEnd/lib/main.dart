import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:dio/dio.dart';

import 'config/theme.dart';
import 'config/router.dart';
import 'db/app_database.dart';
import 'screens/auth/splash_screen.dart';
import 'config/dio_factory.dart';
import 'repositories/payment_repository.dart';
import 'services/sync_service.dart';
import 'providers/auth_provider.dart';
import 'providers/event_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/config_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/pledge_provider.dart';
import 'providers/admin_provider.dart';
import 'providers/sponsor_provider.dart';
import 'providers/ticket_provider.dart';
import 'providers/user_provider.dart';
import 'providers/venue_provider.dart';
import 'providers/bookmark_provider.dart';
import 'repositories/admin_repository.dart';
import 'repositories/bookmark_repository.dart';
import 'repositories/chat_repository.dart';
import 'repositories/event_repository.dart';
import 'repositories/funding_repository.dart';
import 'repositories/ticket_repository.dart';
import 'repositories/notification_repository.dart';
import 'repositories/sponsor_repository.dart';
import 'repositories/user_repository.dart';
import 'repositories/venue_repository.dart';
import 'models/notification_model.dart' show NotificationPayload;
import 'screens/notification/notification_screen.dart' show resolveNotificationRoute;
import 'services/chat_socket_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_stripe/flutter_stripe.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('Background push: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();

  await dotenv.load(fileName: '.env');

  await Firebase.initializeApp(
    options: FirebaseOptions(
      apiKey: dotenv.env['FIREBASE_API_KEY']!,
      authDomain: dotenv.env['FIREBASE_AUTH_DOMAIN']!,
      projectId: dotenv.env['FIREBASE_PROJECT_ID']!,
      storageBucket: dotenv.env['FIREBASE_STORAGE_BUCKET']!,
      messagingSenderId: dotenv.env['FIREBASE_MESSAGING_SENDER_ID']!,
      appId: dotenv.env['FIREBASE_APP_ID']!,
      measurementId: dotenv.env['FIREBASE_MEASUREMENT_ID'],
    ),
  );

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Stripe — publishable key set dynamically after /stripe/config API call.
  // flutter_stripe uses dart:io Platform which crashes on web.
  if (!kIsWeb) {
    Stripe.publishableKey = '';
  }

  runApp(const CrowdFundApp());
}

class CrowdFundApp extends StatefulWidget {
  const CrowdFundApp({super.key});

  @override
  State<CrowdFundApp> createState() => _CrowdFundAppState();
}

class _CrowdFundAppState extends State<CrowdFundApp> {
  late final Dio _dio;
  late final ChatSocketService _chatSocket;
  late final AppDatabase _appDatabase;
  @override
  void initState() {
    super.initState();
    _dio = createAuthDio();
    _chatSocket = ChatSocketService();
    _appDatabase = AppDatabase();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Shared Dio — repositories receive this same instance (has auth interceptors).
        Provider<Dio>.value(value: _dio),
        Provider<EventRepository>(create: (ctx) => EventRepository(ctx.read<Dio>())),
        Provider<FundingRepository>(create: (ctx) => FundingRepository(ctx.read<Dio>())),
        Provider<TicketRepository>(create: (ctx) => TicketRepository(ctx.read<Dio>())),
        Provider<UserRepository>(create: (ctx) => UserRepository(ctx.read<Dio>())),
        Provider<SponsorRepository>(create: (ctx) => SponsorRepository(ctx.read<Dio>())),
        Provider<VenueRepository>(create: (ctx) => VenueRepository(ctx.read<Dio>())),
        Provider<BookmarkRepository>(create: (ctx) => BookmarkRepository(ctx.read<Dio>())),
        Provider<NotificationRepository>(create: (ctx) => NotificationRepository(ctx.read<Dio>())),
        Provider<ChatRepository>(create: (ctx) => ChatRepository(ctx.read<Dio>())),
        Provider<AdminRepository>(create: (ctx) => AdminRepository(ctx.read<Dio>())),
        Provider<PaymentRepository>(create: (ctx) => PaymentRepository(ctx.read<Dio>())),
        Provider<ChatSocketService>.value(value: _chatSocket),
        Provider<AppDatabase>.value(value: _appDatabase),
        Provider<SyncService>(create: (ctx) => SyncService(
          db: _appDatabase,
          eventRepo: ctx.read<EventRepository>(),
          ticketRepo: ctx.read<TicketRepository>(),
          sponsorRepo: ctx.read<SponsorRepository>(),
          bookmarkRepo: ctx.read<BookmarkRepository>(),
        )),
        ChangeNotifierProvider(create: (ctx) => AuthProvider(ctx.read<UserRepository>())),
        ChangeNotifierProvider(create: (ctx) => EventProvider(ctx.read<EventRepository>())),
        ChangeNotifierProvider(create: (ctx) => ConfigProvider(ctx.read<EventRepository>(), ctx.read<PaymentRepository>())..fetchConfig()),
        ChangeNotifierProvider(create: (ctx) => NotificationProvider(ctx.read<NotificationRepository>())),
        ChangeNotifierProvider(create: (ctx) => ChatProvider(ctx.read<ChatRepository>(), _chatSocket)),
        ChangeNotifierProvider(create: (ctx) => PledgeProvider(ctx.read<FundingRepository>())),
        ChangeNotifierProvider(create: (ctx) => AdminProvider(ctx.read<AdminRepository>())),
        ChangeNotifierProvider(create: (ctx) => SponsorProvider(ctx.read<SponsorRepository>())),
        ChangeNotifierProvider(create: (ctx) => TicketProvider(ctx.read<TicketRepository>())),
        ChangeNotifierProvider(create: (ctx) => UserProvider(ctx.read<UserRepository>())),
        ChangeNotifierProvider(create: (ctx) => VenueProvider(ctx.read<VenueRepository>())),
        ChangeNotifierProvider(create: (ctx) => BookmarkProvider(ctx.read<BookmarkRepository>())),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const _AppShell(),
    );
  }
}

class _AppShell extends StatefulWidget {
  const _AppShell();

  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> {
  GoRouter? _router;
  bool _fcmInitialized = false;
  bool _wasAuthenticated = false;
  bool _syncInitialized = false;
  SyncService? _syncService;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _openedAppSub;

  void _setupFcmListeners(NotificationProvider notifProvider) {
    if (_fcmInitialized) return;
    _fcmInitialized = true;

    // Wire pre-signout hook so device token is unregistered while
    // the Firebase auth session is still active (avoids 401).
    context.read<AuthProvider>().onBeforeSignOut = () async {
      await notifProvider.unregisterDevice();
    };

    notifProvider.initFcm();

    _foregroundSub = FirebaseMessaging.onMessage.listen((message) {
      notifProvider.loadNotifications();
    });

    _openedAppSub = FirebaseMessaging.onMessageOpenedApp.listen((message) {
      final payload = NotificationPayload.fromMap(message.data);
      final route = resolveNotificationRoute(payload);
      if (route != null && _router != null) {
        _router!.go(route);
      }
    });

    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        final payload = NotificationPayload.fromMap(message.data);
        final route = resolveNotificationRoute(payload);
        if (route != null && _router != null) {
          _router!.go(route);
        }
      }
    });
  }

  Future<void> _connectChat() async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) return;
    final token = await firebaseUser.getIdToken();
    if (token == null || !mounted) return;
    context.read<ChatSocketService>().connect(token);
    context.read<ChatProvider>().startListening();
  }

  void _disconnectChat() {
    context.read<ChatProvider>().stopListening();
    context.read<ChatSocketService>().disconnect();
  }

  void _initSync() {
    if (_syncInitialized) return;
    _syncInitialized = true;
    _syncService = context.read<SyncService>();
    _syncService!.init();
    final role = context.read<AuthProvider>().user?.role.name;
    _syncService!.syncOnLaunch(role: role);
  }

  void _teardownFcm(NotificationProvider notifProvider) {
    if (!_fcmInitialized) return;
    _fcmInitialized = false;
    _foregroundSub?.cancel();
    _openedAppSub?.cancel();
    // Clear the pre-signout hook. Device token was already unregistered
    // by the hook before Firebase signed out; calling unregisterDevice()
    // here would 401 because the auth session is already gone.
    context.read<AuthProvider>().onBeforeSignOut = null;
  }

  @override
  void dispose() {
    _router?.dispose();
    _foregroundSub?.cancel();
    _openedAppSub?.cancel();
    _syncService?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final themeProvider = context.watch<ThemeProvider>();

    // Detect auth transitions and schedule side-effects after the frame.
    final isAuth = authProvider.isAuthenticated;
    if (isAuth != _wasAuthenticated) {
      _wasAuthenticated = isAuth;
      final notifProvider = context.read<NotificationProvider>();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (isAuth) {
          notifProvider.startPolling();
          _setupFcmListeners(notifProvider);
          _connectChat();
          _initSync();
        } else {
          notifProvider.stopPolling();
          _teardownFcm(notifProvider);
          _disconnectChat();
        }
      });
    }

    _router ??= createRouter(authProvider);

    // Show SplashScreen only during the one-time initial Firebase session
    // check. After that, isLoading may still be true during signIn/signUp —
    // but we must NOT replace the router child then, because doing so unmounts
    // the entire Navigator and destroys form state on the login/register pages.
    final initializing = !authProvider.initialCheckDone;

    return MaterialApp.router(
      title: 'CrowdFund Events',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.mode,
      routerConfig: _router!,
      builder: (context, child) {
        if (initializing) return const SplashScreen();
        return child ?? const SizedBox.shrink();
      },
    );
  }
}
