import 'dart:convert';

class AppSettings {
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
  });

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
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'boondUrl': boondUrl,
      'boondUser': boondUser,
      'boondPassword': boondPassword,
      'boondFirstName': boondFirstName,
      'boondLastName': boondLastName,
      'smtpHost': smtpHost,
      'smtpPort': smtpPort,
      'smtpUser': smtpUser,
      'smtpPassword': smtpPassword,
      'isFullScreen': isFullScreen,
    };
  }

  factory AppSettings.fromMap(Map<String, dynamic> map) {
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
    );
  }

  String toJson() => json.encode(toMap());

  factory AppSettings.fromJson(String source) => AppSettings.fromMap(json.decode(source));
}
