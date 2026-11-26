import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opsis_app/models/app_settings.dart';

void main() {
  group('Mots de passe hors des préférences', () {
    test("toJson n'écrit aucun mot de passe", () {
      final s = AppSettings(boondPassword: 'secret-boond', smtpPassword: 'secret-smtp', smtpUser: 'u@viv-prod.com');
      final json = s.toJson();
      expect(json, isNot(contains('secret-boond')));
      expect(json, isNot(contains('secret-smtp')));
      expect(AppSettings.containsSecrets(json), isFalse);
      expect(jsonDecode(json)['smtpUser'], 'u@viv-prod.com');
    });

    test('lit encore les mots de passe écrits en clair par la v0.1.12, pour les migrer', () {
      final legacy = jsonEncode({
        'boondUrl': 'https://ui.boondmanager.com/api',
        'boondUser': 'admin',
        'boondPassword': 'ancien-boond',
        'smtpHost': 'ssl0.ovh.net',
        'smtpPort': 465,
        'smtpUser': 'fournisseurs@viv-prod.com',
        'smtpPassword': 'ancien-smtp',
        'isFullScreen': false,
      });
      expect(AppSettings.containsSecrets(legacy), isTrue);
      final s = AppSettings.fromJson(legacy);
      expect(s.boondPassword, 'ancien-boond');
      expect(s.smtpPassword, 'ancien-smtp');
      expect(s.smtpPort, 465);
      expect(s.bdcHourlyLimit, AppSettings.defaultBdcHourlyLimit);
      // Une fois réécrit, plus aucun secret
      expect(AppSettings.containsSecrets(s.toJson()), isFalse);
    });

    test('le stockage sécurisé est prioritaire ; l\'ancienne valeur ne sert que s\'il est vide', () {
      expect(AppSettings.resolveSecret(secure: 'coffre', legacy: 'clair'), 'coffre');
      expect(AppSettings.resolveSecret(secure: null, legacy: 'clair'), 'clair');
      expect(AppSettings.resolveSecret(secure: '', legacy: 'clair'), 'clair');
      expect(AppSettings.resolveSecret(secure: null, legacy: ''), '');
    });

    test('un JSON illisible ne déclenche pas de migration', () {
      expect(AppSettings.containsSecrets('pas du json'), isFalse);
    });
  });

  group('Plafond horaire des BDC', () {
    test('70 par défaut', () {
      expect(AppSettings().bdcHourlyLimit, 70);
    });

    test('borné entre 10 et 95, à la lecture comme à la modification', () {
      expect(AppSettings.fromJson(jsonEncode({'bdcHourlyLimit': 5})).bdcHourlyLimit, 10);
      expect(AppSettings.fromJson(jsonEncode({'bdcHourlyLimit': 500})).bdcHourlyLimit, 95);
      expect(AppSettings.fromJson(jsonEncode({'bdcHourlyLimit': 50})).bdcHourlyLimit, 50);
      expect(AppSettings().copyWith(bdcHourlyLimit: 3).bdcHourlyLimit, 10);
      expect(AppSettings().copyWith(bdcHourlyLimit: 90).bdcHourlyLimit, 90);
    });

    test('conservé après enregistrement et relecture', () {
      final s = AppSettings().copyWith(bdcHourlyLimit: 50);
      expect(AppSettings.fromJson(s.toJson()).bdcHourlyLimit, 50);
    });
  });
}
