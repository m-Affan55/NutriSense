import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:win32_registry/win32_registry.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> initPlatformSetup(List<String> args) async {
  if (Platform.isWindows) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    // Register Custom URL Scheme on Windows for Deep Linking
    try {
      const scheme = 'io.supabase.nutrisense';
      final exePath = Platform.resolvedExecutable;
      
      final key = CURRENT_USER.create('Software\\Classes\\$scheme');
      key.setValue('', RegistryValue.string('URL:NutriSense Protocol'));
      key.setValue('URL Protocol', RegistryValue.string(''));
      
      final iconKey = key.create('DefaultIcon');
      iconKey.setValue('', RegistryValue.string('$exePath,1'));
      iconKey.close();

      final shellKey = key.create('shell\\open\\command');
      shellKey.setValue('', RegistryValue.string('"$exePath" "%1"'));
      shellKey.close();
      key.close();
    } catch (e) {
      debugPrint('Windows URL Protocol registration failed: $e');
    }

    // Handle Windows redirect parameter if launched via deep link
    if (args.isNotEmpty) {
      final launchUrl = args.first;
      if (launchUrl.startsWith('io.supabase.nutrisense://')) {
        try {
          final uri = Uri.parse(launchUrl.replaceAll('#', '?'));
          await Supabase.instance.client.auth.getSessionFromUrl(uri);
        } catch (e) {
          debugPrint('Windows deep link parsing failed: $e');
        }
      }
    }
  }
}
