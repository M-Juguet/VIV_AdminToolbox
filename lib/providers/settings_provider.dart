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
      var legacySecretsInPrefs = false;
      if (settingsJson != null) {
        current = AppSettings.fromJson(settingsJson);
        legacySecretsInPrefs = AppSettings.containsSecrets(settingsJson);
      }

      final boondPass = await _storage.read(key: 'boond_pass');
      final smtpPass = await _storage.read(key: 'smtp_pass');

      current = current.copyWith(
        boondPassword: AppSettings.resolveSecret(secure: boondPass, legacy: current.boondPassword),
        smtpPassword: AppSettings.resolveSecret(secure: smtpPass, legacy: current.smtpPassword),
      );

      state = current;

      if (legacySecretsInPrefs) {
        await _migrateLegacySecrets(prefs, current, boondPass: boondPass, smtpPass: smtpPass);
      }

      if (state.isFullScreen) {
        await windowManager.setFullScreen(true);
      }
    } catch (e) {
      // Error handling
    }
  }

  /// Migration v0.1.13 : les versions précédentes écrivaient aussi les mots de passe en clair dans les préférences.
  /// On s'assure d'abord qu'ils sont dans le stockage sécurisé, puis on réécrit les préférences sans eux.
  /// En cas d'échec d'écriture sécurisée, les préférences ne sont pas modifiées : aucun identifiant n'est perdu.
  Future<void> _migrateLegacySecrets(
    SharedPreferences prefs,
    AppSettings current, {
    required String? boondPass,
    required String? smtpPass,
  }) async {
    try {
      if ((boondPass ?? '').isEmpty && current.boondPassword.isNotEmpty) {
        await _storage.write(key: 'boond_pass', value: current.boondPassword);
      }
      if ((smtpPass ?? '').isEmpty && current.smtpPassword.isNotEmpty) {
        await _storage.write(key: 'smtp_pass', value: current.smtpPassword);
      }
      await prefs.setString(_settingsKey, current.toJson());
    } catch (_) {
      // Stockage sécurisé indisponible : on garde l'ancien format plutôt que de perdre les identifiants.
    }
  }

  Future<void> updateSettings(AppSettings newSettings) async {
    state = newSettings;

    final prefs = await SharedPreferences.getInstance();
    // toJson() n'inclut pas les mots de passe : ils ne sont écrits que dans le stockage sécurisé.
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
