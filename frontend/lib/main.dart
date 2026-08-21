import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:win32_registry/win32_registry.dart';
import 'ui/core/theme.dart';
import 'ui/features/splash/splash_screen.dart';
import 'ui/features/auth/update_password_screen.dart';
import 'ui/features/navigation/main_navigation_screen.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'core/reminder_manager.dart';
import 'core/sync_service.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    publishableKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  // Setup Windows Registry protocol if on Windows
  if (!kIsWeb && Platform.isWindows) {
    try {
      final path = Platform.resolvedExecutable;
      final key = Registry.currentUser.createKey('Software\\Classes\\io.supabase.nutrisense');
      key.createValue(RegistryValue.string('', 'URL:io.supabase.nutrisense Protocol'));
      key.createValue(RegistryValue.string('URL Protocol', ''));
      final shellKey = key.createKey('shell\\open\\command');
      shellKey.createValue(RegistryValue.string('', '"$path" "%1"'));
    } catch (e) {
      debugPrint('Protocol registration failed: $e');
    }
  }

  // Handle Windows redirect parameter if launched via deep link
  if (!kIsWeb && Platform.isWindows && args.isNotEmpty) {
    final launchUrl = args.first;
    if (launchUrl.startsWith('io.supabase.nutrisense://')) {
      try {
        final uri = Uri.parse(launchUrl.replaceAll('#', '?'));
        await Supabase.instance.client.auth.getSessionFromUrl(uri);
      } catch (e) {
        debugPrint('Error restoring session from Windows launch URL: $e');
      }
    }
  }

  // Initialize and schedule local notifications
  try {
    await ReminderManager.init();
    await ReminderManager.requestPermissions();
    await ReminderManager.scheduleAllReminders();
  } catch (e) {
    debugPrint('[ReminderManager] Notification init failed: $e');
  }

  // Attempt to sync any offline-cached logs on startup
  _triggerSyncIfLoggedIn();

  // Re-sync whenever connectivity is restored
  Connectivity().onConnectivityChanged.listen((results) {
    final isOnline = results.any((r) => r != ConnectivityResult.none);
    if (isOnline) _triggerSyncIfLoggedIn();
  });

  runApp(const NutriSenseApp());
}

/// Triggers sync only when a user is authenticated.
void _triggerSyncIfLoggedIn() {
  final user = Supabase.instance.client.auth.currentUser;
  if (user != null) {
    SyncService.instance.syncPending(user.id);
  }
}

class NutriSenseApp extends StatefulWidget {
  const NutriSenseApp({super.key});

  static NutriSenseAppState of(BuildContext context) =>
      context.findAncestorStateOfType<NutriSenseAppState>()!;

  @override
  State<NutriSenseApp> createState() => NutriSenseAppState();
}

class NutriSenseAppState extends State<NutriSenseApp> {
  ThemeMode _themeMode = ThemeMode.dark;
  final _navigatorKey = GlobalKey<NavigatorState>();

  ThemeMode get themeMode => _themeMode;

  void toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  void initState() {
    super.initState();
    _initAuthListener();
  }

  void _initAuthListener() {
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      final session = data.session;

      if (event == AuthChangeEvent.signedIn && session != null) {
        _navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
          (route) => false,
        );
      } else if (event == AuthChangeEvent.passwordRecovery) {
        _navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const UpdatePasswordScreen()),
          (route) => false,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NutriSense',
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      home: const SplashScreen(),
    );
  }
}
