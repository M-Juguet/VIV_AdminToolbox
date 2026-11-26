import 'dart:convert';

class AppSettings {
  /// Plafond d'envois de BDC par heure glissante (la boîte OVH perd les e-mails au-delà d'environ 100 par heure,
  /// et les rapports de production de n8n partagent ce quota).
  static const int defaultBdcHourlyLimit = 70;
  static const int minBdcHourlyLimit = 10;
  static const int maxBdcHourlyLimit = 95;

  /// Champs secrets : jamais écrits dans les préférences (fichier lisible), uniquement dans le stockage sécurisé.
  static const List<String> secretKeys = ['boondPassword', 'smtpPassword'];

  final String boondUrl;
  final String boondUser;
  final String boondPassword;
  final String boondFirstName;
  final String boondLastName;
  final String smtpHost;
  final int smtpPort;
  final String smtpUser;
  final String smtpPassword;
  final bool isFullScreen;
  final int bdcHourlyLimit;

  AppSettings({
    this.boondUrl = 'https://ui.boondmanager.com/api',
    this.boondUser = '',
    this.boondPassword = '',
    this.boondFirstName = '',
    this.boondLastName = '',
    this.smtpHost = '',
    this.smtpPort = 587,
    this.smtpUser = '',
    this.smtpPassword = '',
    this.isFullScreen = false,
    this.bdcHourlyLimit = defaultBdcHourlyLimit,
  });

  static int clampHourlyLimit(int value) => value.clamp(minBdcHourlyLimit, maxBdcHourlyLimit);

  AppSettings copyWith({
    String? boondUrl,
    String? boondUser,
    String? boondPassword,
    String? boondFirstName,
    String? boondLastName,
    String? smtpHost,
    int? smtpPort,
    String? smtpUser,
    String? smtpPassword,
    bool? isFullScreen,
    int? bdcHourlyLimit,
  }) {
    return AppSettings(
      boondUrl: boondUrl ?? this.boondUrl,
      boondUser: boondUser ?? this.boondUser,
      boondPassword: boondPassword ?? this.boondPassword,
      boondFirstName: boondFirstName ?? this.boondFirstName,
      boondLastName: boondLastName ?? this.boondLastName,
      smtpHost: smtpHost ?? this.smtpHost,
      smtpPort: smtpPort ?? this.smtpPort,
      smtpUser: smtpUser ?? this.smtpUser,
      smtpPassword: smtpPassword ?? this.smtpPassword,
      isFullScreen: isFullScreen ?? this.isFullScreen,
      bdcHourlyLimit: bdcHourlyLimit != null ? clampHourlyLimit(bdcHourlyLimit) : this.bdcHourlyLimit,
    );
  }

  /// Paramètres enregistrés dans les préférences. Les mots de passe en sont exclus : ils vivent dans le stockage
  /// sécurisé (voir SettingsNotifier).
  Map<String, dynamic> toMap() {
    return {
      'boondUrl': boondUrl,
      'boondUser': boondUser,
      'boondFirstName': boondFirstName,
      'boondLastName': boondLastName,
      'smtpHost': smtpHost,
      'smtpPort': smtpPort,
      'smtpUser': smtpUser,
      'isFullScreen': isFullScreen,
      'bdcHourlyLimit': bdcHourlyLimit,
    };
  }

  /// Lit aussi les mots de passe que les versions jusqu'à 0.1.12 écrivaient en clair, pour pouvoir les migrer.
  factory AppSettings.fromMap(Map<String, dynamic> map) {
    final limit = map['bdcHourlyLimit'];
    return AppSettings(
      boondUrl: map['boondUrl'] ?? 'https://ui.boondmanager.com/api',
      boondUser: map['boondUser'] ?? '',
      boondPassword: map['boondPassword'] ?? '',
      boondFirstName: map['boondFirstName'] ?? '',
      boondLastName: map['boondLastName'] ?? '',
      smtpHost: map['smtpHost'] ?? '',
      smtpPort: map['smtpPort'] ?? 587,
      smtpUser: map['smtpUser'] ?? '',
      smtpPassword: map['smtpPassword'] ?? '',
      isFullScreen: map['isFullScreen'] ?? false,
      bdcHourlyLimit: limit is num ? clampHourlyLimit(limit.toInt()) : defaultBdcHourlyLimit,
    );
  }

  String toJson() => json.encode(toMap());

  factory AppSettings.fromJson(String source) => AppSettings.fromMap(json.decode(source));

  /// Vrai si un JSON de préférences contient encore des champs secrets (format des versions jusqu'à 0.1.12).
  static bool containsSecrets(String source) {
    try {
      final map = json.decode(source);
      return map is Map && secretKeys.any(map.containsKey);
    } catch (_) {
      return false;
    }
  }

  /// Choisit le mot de passe à utiliser : celui du stockage sécurisé s'il existe, sinon l'ancienne valeur en clair
  /// (cas où le stockage sécurisé est vide ou illisible), pour ne jamais faire perdre un identifiant.
  static String resolveSecret({required String? secure, required String legacy}) {
    if (secure != null && secure.isNotEmpty) return secure;
    return legacy;
  }
}
