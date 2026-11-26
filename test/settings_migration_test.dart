import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opsis_app/models/app_settings.dart';
import 'package:opsis_app/providers/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _key = 'opsis_settings';

String _legacyPrefs({String boond = 'pass-boond', String smtp = 'pass-smtp'}) => jsonEncode({
      'boondUrl': 'https://ui.boondmanager.com/api',
      'boondUser': 'admin@viv-prod.com',
      'boondPassword': boond,
      'boondFirstName': 'Prénom',
      'boondLastName': 'Nom',
      'smtpHost': 'ssl0.ovh.net',
      'smtpPort': 465,
      'smtpUser': 'fournisseurs@viv-prod.com',
      'smtpPassword': smtp,
      'isFullScreen': false,
    });

/// Lance le chargement des paramètres comme au démarrage de l'app et attend la fin de la migration.
Future<AppSettings> _startApp() async {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  container.read(settingsProvider);
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  return container.read(settingsProvider);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('passage de la v0.1.12 à la v0.1.13 : identifiants conservés, mots de passe retirés des préférences', () async {
    SharedPreferences.setMockInitialValues({_key: _legacyPrefs()});
    FlutterSecureStorage.setMockInitialValues({'boond_pass': 'pass-boond', 'smtp_pass': 'pass-smtp'});

    final s = await _startApp();

    expect(s.boondPassword, 'pass-boond');
    expect(s.smtpPassword, 'pass-smtp');
    expect(s.smtpUser, 'fournisseurs@viv-prod.com');
    expect(s.bdcHourlyLimit, 70);

    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_key)!;
    expect(stored, isNot(contains('pass-boond')));
    expect(stored, isNot(contains('pass-smtp')));
    expect(jsonDecode(stored)['smtpUser'], 'fournisseurs@viv-prod.com');
  });

  test('stockage sécurisé vide : les mots de passe sont recopiés dans le coffre avant d\'être retirés', () async {
    SharedPreferences.setMockInitialValues({_key: _legacyPrefs()});
    FlutterSecureStorage.setMockInitialValues({});

    final s = await _startApp();
    expect(s.boondPassword, 'pass-boond');
    expect(s.smtpPassword, 'pass-smtp');

    const storage = FlutterSecureStorage();
    expect(await storage.read(key: 'boond_pass'), 'pass-boond');
    expect(await storage.read(key: 'smtp_pass'), 'pass-smtp');

    final prefs = await SharedPreferences.getInstance();
    expect(AppSettings.containsSecrets(prefs.getString(_key)!), isFalse);

    // Au démarrage suivant, tout est toujours là
    final again = await _startApp();
    expect(again.smtpPassword, 'pass-smtp');
  });

  test('enregistrer les paramètres n\'écrit plus de mot de passe en clair', () async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(settingsProvider);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final notifier = container.read(settingsProvider.notifier);
    await notifier
        .updateSettings(AppSettings(smtpUser: 'fournisseurs@viv-prod.com', smtpPassword: 'nouveau', bdcHourlyLimit: 50))
        .catchError((_) {}); // windowManager n'existe pas en test : seule l'écriture des paramètres nous intéresse

    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_key)!;
    expect(stored, isNot(contains('nouveau')));
    expect(jsonDecode(stored)['bdcHourlyLimit'], 50);
    expect(await const FlutterSecureStorage().read(key: 'smtp_pass'), 'nouveau');
  });
}
