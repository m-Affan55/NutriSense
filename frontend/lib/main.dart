import 'package:flutter/material.dart';
import 'core/platform_setup.dart';
import 'ui/core/theme.dart';
import 'ui/features/splash/splash_screen.dart';
import 'ui/features/auth/update_password_screen.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'core/reminder_manager.dart';
import 'core/sync_service.dart';
import 'core/ramadan_controller.dart';

final GlobalKey<NavigatorState> globalNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize platform specific configurations (desktop registry/FFI database setup)
  await initPlatformSetup(args);

  // Load environmental variables safely
  await dotenv.load(fileName: ".env");

  // Initialize Supabase
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',
    publishableKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
  );

  // Initialize RamadanController state
  await RamadanController.instance.init();

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
    Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      final event = data.event;
      final session = data.session;

      if (event == AuthChangeEvent.signedIn && session != null) {
        // Handled primarily by auth screen navigation or deep links
      } else if (event == AuthChangeEvent.passwordRecovery) {
        globalNavigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const UpdatePasswordScreen()),
          (route) => false,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: RamadanController.instance,
      builder: (context, _) {
        final isRamadan = RamadanController.instance.isRamadanMode;
        return MaterialApp(
          title: 'NutriSense',
          navigatorKey: globalNavigatorKey,
          debugShowCheckedModeBanner: false,
          themeMode: _themeMode,
          theme: isRamadan ? buildRamadanTheme() : buildLightTheme(),
          darkTheme: isRamadan ? buildRamadanTheme() : buildDarkTheme(),
          home: const SplashScreen(),
        );
      },
    );
  }
}
