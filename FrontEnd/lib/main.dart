import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'config/theme.dart';
import 'config/router.dart';
import 'screens/auth/splash_screen.dart';
import 'services/api_service.dart';
import 'providers/auth_provider.dart';
import 'providers/event_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/config_provider.dart';
import 'providers/notification_provider.dart';

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

class CrowdFundApp extends StatelessWidget {
  const CrowdFundApp({super.key});

  @override
  Widget build(BuildContext context) {
    final apiService = ApiService();

    return MultiProvider(
      providers: [
        Provider<ApiService>.value(value: apiService),
        ChangeNotifierProvider(create: (_) => AuthProvider(apiService)),
        ChangeNotifierProvider(create: (_) => EventProvider(apiService)),
        ChangeNotifierProvider(create: (_) => ConfigProvider(apiService)..fetchConfig()),
        ChangeNotifierProvider(create: (_) => NotificationProvider(apiService)),
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
      final data = message.data;
      final eventId = data['event_id'];
      if (eventId != null && _router != null) {
        _router!.go('/events/$eventId');
      }
    });

    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        final eventId = message.data['event_id'];
        if (eventId != null && _router != null) {
          _router!.go('/events/$eventId');
        }
      }
    });
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final themeProvider = context.watch<ThemeProvider>();

    final notifProvider = context.read<NotificationProvider>();
    if (authProvider.isAuthenticated) {
      notifProvider.startPolling();
      _setupFcmListeners(notifProvider);
    } else {
      notifProvider.stopPolling();
      _teardownFcm(notifProvider);
    }

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
