import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import '../models/app_settings.dart';

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(() {
  return SettingsNotifier();
});

class SettingsNotifier extends Notifier<AppSettings> {
  static const _storage = FlutterSecureStorage();
  static const _settingsKey = 'opsis_settings';

  @override
  AppSettings build() {
    _loadSettings();
    return AppSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString(_settingsKey);
      
      AppSettings current = AppSettings();
      if (settingsJson != null) {
        current = AppSettings.fromJson(settingsJson);
      }
      
      final boondPass = await _storage.read(key: 'boond_pass');
      final smtpPass = await _storage.read(key: 'smtp_pass');
      
      current = current.copyWith(
        boondPassword: boondPass ?? '',
        smtpPassword: smtpPass ?? '',
      );

      state = current;

      if (state.isFullScreen) {
        await windowManager.setFullScreen(true);
      }
    } catch (e) {
      // Error handling
    }
  }

  Future<void> updateSettings(AppSettings newSettings) async {
    state = newSettings;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsKey, state.toJson());
    
    await _storage.write(key: 'boond_pass', value: state.boondPassword);
    await _storage.write(key: 'smtp_pass', value: state.smtpPassword);
    
    await windowManager.setFullScreen(state.isFullScreen);
  }

  Future<void> setFullScreen(bool value) async {
    state = state.copyWith(isFullScreen: value);
    await updateSettings(state);
  }

  Future<void> logout() async {
    await _storage.delete(key: 'boond_pass');
    await _storage.delete(key: 'smtp_pass');
    
    state = state.copyWith(
      boondUrl: 'https://ui.boondmanager.com/api',
      boondUser: '',
      boondPassword: '',
      boondFirstName: '',
      boondLastName: '',
      smtpHost: '',
      smtpUser: '',
      smtpPassword: '',
    );
    
    await updateSettings(state);
  }
}
