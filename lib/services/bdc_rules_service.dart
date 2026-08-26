import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';

class BdcRuleKeyword {
  String text;
  bool caseSensitive;

  BdcRuleKeyword({required this.text, this.caseSensitive = false});

  Map<String, dynamic> toJson() => {
        'text': text,
        'caseSensitive': caseSensitive,
      };

  factory BdcRuleKeyword.fromJson(Map<String, dynamic> json) => BdcRuleKeyword(
        text: json['text'] ?? '',
        caseSensitive: json['caseSensitive'] ?? false,
      );
}

class BdcRule {
  final String id;
  final String clientName;
  final String clientCsoc;
  final String contactName;
  final String contactCcon;
  final String projectId;
  final List<BdcRuleKeyword> keywords;
  final String calculationMode; // 'standard', 'sold', 'manual'
  final double manualDays;
  final String titleMode; // 'delivery_title', 'resource_title'

  BdcRule({
    required this.id,
    required this.clientName,
    required this.clientCsoc,
    required this.contactName,
    required this.contactCcon,
    required this.projectId,
    required this.keywords,
    required this.calculationMode,
    required this.manualDays,
    required this.titleMode,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'clientName': clientName,
        'clientCsoc': clientCsoc,
        'contactName': contactName,
        'contactCcon': contactCcon,
        'projectId': projectId,
        'keywords': keywords.map((k) => k.toJson()).toList(),
        'calculationMode': calculationMode,
        'manualDays': manualDays,
        'titleMode': titleMode,
      };

  factory BdcRule.fromJson(Map<String, dynamic> json) => BdcRule(
        id: json['id'] ?? '',
        clientName: json['clientName'] ?? '',
        clientCsoc: json['clientCsoc'] ?? '',
        contactName: json['contactName'] ?? '',
        contactCcon: json['contactCcon'] ?? '',
        projectId: json['projectId'] ?? '',
        keywords: (json['keywords'] as List? ?? [])
            .map((k) => BdcRuleKeyword.fromJson(k))
            .toList(),
        calculationMode: json['calculationMode'] ?? 'standard',
        manualDays: (json['manualDays'] as num? ?? 1.0).toDouble(),
        titleMode: json['titleMode'] ?? 'delivery_title',
      );
}

class BdcRulesService {
  static final BdcRulesService _singleton = BdcRulesService._internal();

  factory BdcRulesService() {
    return _singleton;
  }

  BdcRulesService._internal();

  Future<File> get _localFile async {
    final directory = await getApplicationSupportDirectory();
    return File(join(directory.path, 'bdc_rules.json'));
  }

  /// Charge toutes les règles depuis le fichier local
  Future<List<BdcRule>> loadRules() async {
    try {
      final file = await _localFile;
      if (!await file.exists()) {
        // Retourner des règles par défaut si le fichier n'existe pas
        return _getDefaultRules();
      }
      final contents = await file.readAsString();
      final List<dynamic> jsonList = jsonDecode(contents);
      return jsonList.map((j) => BdcRule.fromJson(j)).toList();
    } catch (_) {
      return _getDefaultRules();
    }
  }

  /// Enregistre les règles dans le fichier local
  Future<void> saveRules(List<BdcRule> rules) async {
    try {
      final file = await _localFile;
      final contents = jsonEncode(rules.map((r) => r.toJson()).toList());
      await file.writeAsString(contents);
    } catch (_) {
      // Ignorer l'erreur
    }
  }

  List<BdcRule> _getDefaultRules() {
    return [
      BdcRule(
        id: "R-1",
        clientName: "LOUIS VUITTON",
        clientCsoc: "15",
        contactName: "",
        contactCcon: "",
        projectId: "",
        keywords: [BdcRuleKeyword(text: "Montage vidéo", caseSensitive: false)],
        calculationMode: "manual",
        manualDays: 10,
        titleMode: "delivery_title",
      ),
      BdcRule(
        id: "R-2",
        clientName: "STELLANTIS",
        clientCsoc: "8",
        contactName: "",
        contactCcon: "",
        projectId: "",
        keywords: [],
        calculationMode: "sold",
        manualDays: 0,
        titleMode: "resource_title",
      ),
    ];
  }
}
