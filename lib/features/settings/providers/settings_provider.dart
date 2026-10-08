import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/settings_model.dart';

class SettingsNotifier extends StateNotifier<AsyncValue<SettingsModel>> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _docId = 'restaurant_config';
  static const String _collection = 'settings';

  SettingsNotifier() : super(const AsyncValue.loading()) {
    loadSettings();
  }

  Future<void> loadSettings() async {
    try {
      final doc = await _db.collection(_collection).doc(_docId).get();
      if (doc.exists && doc.data() != null) {
        state = AsyncValue.data(SettingsModel.fromMap(doc.data()!));
      } else {
        // Initialize default settings in Firestore
        final defaultConf = SettingsModel.defaultConfig();
        await _db.collection(_collection).doc(_docId).set(defaultConf.toMap());
        state = AsyncValue.data(defaultConf);
      }
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> updateSettings(SettingsModel settings) async {
    try {
      state = const AsyncValue.loading();
      await _db.collection(_collection).doc(_docId).set(settings.toMap());
      state = AsyncValue.data(settings);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

// System settings provider
final settingsProvider = StateNotifierProvider<SettingsNotifier, AsyncValue<SettingsModel>>((ref) {
  return SettingsNotifier();
});

// App Theme Mode local persistence provider
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  static const String _themeKey = 'theme_mode';

  ThemeModeNotifier() : super(ThemeMode.dark) {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt(_themeKey);
    if (index != null) {
      state = ThemeMode.values[index];
    }
  }

  Future<void> toggleTheme(bool isDark) async {
    state = isDark ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeKey, state.index);
  }
}

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});
