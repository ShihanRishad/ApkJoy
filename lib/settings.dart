import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PreferenceUtils {
  static late SharedPreferences prefs;

  static Future<void> init() async {
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (e) {
      debugPrint('Error initializing SharedPreferences: $e');
    }
  }

  static String getThemeMode() => prefs.getString('themeMode') ?? 'light';
  static bool getShowSystemApps() => prefs.getBool('showSystemApps') ?? false;
  static int getPrimaryColorValue() =>
      prefs.getInt('primaryColor') ?? Colors.blue.value;

  static Future<void> setThemeMode(String mode) async {
    try {
      await prefs.setString('themeMode', mode);
    } catch (e) {
      debugPrint('Error setting theme mode: $e');
    }
  }

  static Future<void> setShowSystemApps(bool value) async {
    try {
      await prefs.setBool('showSystemApps', value);
    } catch (e) {
      debugPrint('Error setting show system apps: $e');
    }
  }

  static Future<void> setPrimaryColorValue(int colorValue) async {
    try {
      await prefs.setInt('primaryColor', colorValue);
    } catch (e) {
      debugPrint('Error setting primary color: $e');
    }
  }

  /// Reset all settings to defaults.
  static Future<void> resetSettings() async {
    await setThemeMode('light');
    await setShowSystemApps(false);
    await setPrimaryColorValue(Colors.blue.value);
  }
}
