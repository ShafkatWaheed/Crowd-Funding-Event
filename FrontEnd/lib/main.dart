import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'config/theme.dart';
import 'config/router.dart';
import 'db/app_database.dart';
import 'screens/auth/splash_screen.dart';
import 'services/api_service.dart';
import 'services/sync_service.dart';
import 'providers/auth_provider.dart';
import 'providers/event_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/config_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/notification_provider.dart';
import 'screens/notification/notification_screen.dart' show resolveNotificationRoute;
import 'services/chat_socket_service.dart';

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

  runApp(const CrowdFundApp());
}

class CrowdFundApp extends StatefulWidget {
  const CrowdFundApp({super.key});

  @override
  State<CrowdFundApp> createState() => _CrowdFundAppState();
}

class _CrowdFundAppState extends State<CrowdFundApp> {
  late final ApiService _apiService;
  late final ChatSocketService _chatSocket;
  late final AppDatabase _appDatabase;
  late final SyncService _syncService;

  @override
  void initState() {
    super.initState();
    _apiService = ApiService();
    _chatSocket = ChatSocketService();
    _appDatabase = AppDatabase();
    _syncService = SyncService(db: _appDatabase, api: _apiService);
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiService>.value(value: _apiService),
        Provider<ChatSocketService>.value(value: _chatSocket),
        Provider<AppDatabase>.value(value: _appDatabase),
        Provider<SyncService>.value(value: _syncService),
        ChangeNotifierProvider(create: (_) => AuthProvider(_apiService)),
        ChangeNotifierProvider(create: (_) => EventProvider(_apiService)),
        ChangeNotifierProvider(create: (_) => ConfigProvider(_apiService)..fetchConfig()),
        ChangeNotifierProvider(create: (_) => NotificationProvider(_apiService)),
        ChangeNotifierProvider(create: (_) => ChatProvider(_apiService, _chatSocket)),
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
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _openedAppSub;

  void _setupFcmListeners(NotificationProvider notifProvider) {
    if (_fcmInitialized) return;
    _fcmInitialized = true;

    notifProvider.initFcm();

    _foregroundSub = FirebaseMessaging.onMessage.listen((message) {
      notifProvider.loadNotifications();
    });

    _openedAppSub = FirebaseMessaging.onMessageOpenedApp.listen((message) {
      final data = Map<String, dynamic>.from(message.data);
      final type = data['type'] as String? ?? '';
      final route = resolveNotificationRoute(type, data);
      if (route != null && _router != null) {
        _router!.go(route);
      }
    });

    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        final data = Map<String, dynamic>.from(message.data);
        final type = data['type'] as String? ?? '';
        final route = resolveNotificationRoute(type, data);
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
    final syncService = context.read<SyncService>();
    syncService.init();
    syncService.syncOnLaunch();
  }

  void _teardownFcm(NotificationProvider notifProvider) {
    if (!_fcmInitialized) return;
    _fcmInitialized = false;
    _foregroundSub?.cancel();
    _openedAppSub?.cancel();
    notifProvider.unregisterDevice();
  }

  @override
  void dispose() {
    _router?.dispose();
    _foregroundSub?.cancel();
    _openedAppSub?.cancel();
    if (_syncInitialized) {
      context.read<SyncService>().dispose();
    }
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final authProvider = context.read<AuthProvider>();
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
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final themeProvider = context.watch<ThemeProvider>();

    _router ??= createRouter(authProvider);

    return MaterialApp.router(
      title: 'CrowdFund Events',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.mode,
      routerConfig: _router!,
      builder: (context, child) {
        if (authProvider.isLoading) {
          return const SplashScreen();
        }
        return child ?? const SizedBox.shrink();
      },
    );
  }
}
