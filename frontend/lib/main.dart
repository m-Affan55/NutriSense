import 'package:flutter/material.dart';
import 'ui/core/theme.dart';
import 'ui/features/splash/splash_screen.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/reminder_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    publishableKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  // Initialize and schedule local notifications
  await ReminderManager.init();
  await ReminderManager.requestPermissions();
  await ReminderManager.scheduleAllReminders();

  runApp(const NutriSenseApp());
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
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NutriSense',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      home: const SplashScreen(),
    );
  }
}
