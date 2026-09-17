import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sembast/sembast.dart';
import 'local_database_service.dart';
import 'bdc_sent_logs_service.dart';

class PstBdcItem {
  final String providerId;
  final String bdcNumber;
  final String periodSuffix;
  final String subject;
  final String receivedTime;

  PstBdcItem({
    required this.providerId,
    required this.bdcNumber,
    required this.periodSuffix,
    required this.subject,
    required this.receivedTime,
  });

  factory PstBdcItem.fromJson(Map<String, dynamic> json) {
    return PstBdcItem(
      providerId: json['ProviderId']?.toString() ?? '',
      bdcNumber: json['BdcNumber']?.toString() ?? '',
      periodSuffix: json['Period']?.toString() ?? '',
      subject: json['Subject']?.toString() ?? '',
      receivedTime: json['ReceivedTime']?.toString() ?? '',
    );
  }
}

class ReconciliationEntry {
  final String providerId;
  final String? bdcNumber;
  final String? consultantName;
  final String? clientName;
  final String? sentToEmail;
  final double? uoCount;
  final double? totalHt;
  final bool isConfirmedInPst;
  final String? receivedTime;

  ReconciliationEntry({
    required this.providerId,
    this.bdcNumber,
    this.consultantName,
    this.clientName,
    this.sentToEmail,
    this.uoCount,
    this.totalHt,
    required this.isConfirmedInPst,
    this.receivedTime,
  });
}

class BdcReconciliationReport {
  final String period;
  final String pstPath;
  final int totalInDatabase;
  final int confirmedCount;
  final int missingCount;
  final List<ReconciliationEntry> entries;
  final Set<String> confirmedProviderIds;
  final Set<String> missingProviderIds;

  BdcReconciliationReport({
    required this.period,
    required this.pstPath,
    required this.totalInDatabase,
    required this.confirmedCount,
    required this.missingCount,
    required this.entries,
    required this.confirmedProviderIds,
    required this.missingProviderIds,
  });
}

class BdcReconciliationService {
  final LocalDatabaseService _dbService = LocalDatabaseService();
  final _store = stringMapStoreFactory.store('bdc_sent_logs');

  /// Extrait tous les BDC d'un fichier PST via PowerShell natif Windows
  Future<List<PstBdcItem>> parsePstFile(String pstPath) async {
    final file = File(pstPath);
    if (!file.existsSync()) {
      throw 'Le fichier PST spécifié n\'existe pas : $pstPath';
    }

    final psScript = '''
\$ErrorActionPreference = "SilentlyContinue"
\$pst = "$pstPath"
\$outlook = New-Object -ComObject Outlook.Application
\$namespace = \$outlook.GetNamespace("MAPI")
\$namespace.AddStore(\$pst)
\$store = \$namespace.Stores | Where-Object { \$_.FilePath -eq \$pst }
\$items = @()
function Scan-Folder(\$folder) {
    foreach (\$item in \$folder.Items) {
        foreach (\$att in \$item.Attachments) {
            if (\$att.FileName -match 'VIV-PO-CSOC(\\d+)-(\\d+)\\.pdf') {
                \$script:items += [PSCustomObject]@{
                    ProviderId = \$matches[1]
                    BdcNumber = "VIV-PO-CSOC\$(\$matches[1])-\$(\$matches[2])"
                    Period = \$matches[2]
                    Subject = \$item.Subject
                    ReceivedTime = if (\$item.ReceivedTime) { \$item.ReceivedTime.ToString("yyyy-MM-dd HH:mm:ss") } else { "" }
                }
                break
            }
        }
    }
    foreach (\$sub in \$folder.Folders) {
        Scan-Folder \$sub
    }
}
if (\$store) {
    \$root = \$store.GetRootFolder()
    Scan-Folder \$root
    \$namespace.RemoveStore(\$root)
}
if (\$items.Count -gt 0) {
    \$items | ConvertTo-Json -Compress
} else {
    "[]"
}
''';

    try {
      final result = await Process.run(
        'powershell.exe',
        ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', psScript],
      );

      if (result.exitCode != 0 && (result.stderr as String).isNotEmpty) {
        throw 'Erreur PowerShell lors de l\'analyse du PST: ${result.stderr}';
      }

      final rawOutput = (result.stdout as String).trim();
      if (rawOutput.isEmpty || rawOutput == '[]') {
        return [];
      }

      final dynamic decoded = jsonDecode(rawOutput);
      if (decoded is List) {
        return decoded.map((e) => PstBdcItem.fromJson(Map<String, dynamic>.from(e))).toList();
      } else if (decoded is Map) {
        return [PstBdcItem.fromJson(Map<String, dynamic>.from(decoded))];
      }
      return [];
    } catch (e) {
      debugPrint('Erreur parsePstFile: $e');
      rethrow;
    }
  }

  /// Croise les e-mails trouvés dans le PST avec la base locale pour la période
  Future<BdcReconciliationReport> reconcileWithDatabase({
    required String pstPath,
    required String period, // ex: "09/2026"
  }) async {
    // 1. Extraire les items du PST
    final pstItems = await parsePstFile(pstPath);
    final Map<String, PstBdcItem> pstMapByProviderId = {};
    for (var it in pstItems) {
      pstMapByProviderId[it.providerId] = it;
    }

    // 2. Charger les logs existants pour la période
    final logsService = BdcSentLogsService();
    final allLogs = await logsService.getAllSentLogs();
    final periodLogs = allLogs.where((l) => l['period'] == period).toList();

    final List<ReconciliationEntry> entries = [];
    final Set<String> confirmedIds = {};
    final Set<String> missingIds = {};

    for (var log in periodLogs) {
      final pId = log['providerId']?.toString() ?? '';
      final isConfirmed = pstMapByProviderId.containsKey(pId);
      final pstItem = pstMapByProviderId[pId];

      if (isConfirmed) {
        confirmedIds.add(pId);
      } else {
        missingIds.add(pId);
      }

      entries.add(ReconciliationEntry(
        providerId: pId,
        bdcNumber: log['bdcNumber'] as String?,
        consultantName: log['consultantName'] as String?,
        clientName: log['clientName'] as String?,
        sentToEmail: log['sentToEmail'] as String?,
        uoCount: (log['uoCount'] as num?)?.toDouble(),
        totalHt: (log['totalHt'] as num?)?.toDouble(),
        isConfirmedInPst: isConfirmed,
        receivedTime: pstItem?.receivedTime,
      ));
    }

    return BdcReconciliationReport(
      period: period,
      pstPath: pstPath,
      totalInDatabase: periodLogs.length,
      confirmedCount: confirmedIds.length,
      missingCount: missingIds.length,
      entries: entries,
      confirmedProviderIds: confirmedIds,
      missingProviderIds: missingIds,
    );
  }

  /// Supprime de Sembast uniquement les enregistrements qui n'ont pas été confirmés
  Future<int> deleteMissingLogs({
    required String period,
    required Set<String> missingProviderIds,
  }) async {
    final db = await _dbService.database;
    int deletedCount = 0;

    for (var pId in missingProviderIds) {
      final id = '${pId}_${period.replaceAll('/', '_')}';
      final record = _store.record(id);
      final exists = await record.exists(db);
      if (exists) {
        final val = await record.get(db);
        // Supprimer le PDF physique s'il existe
        final pdfPath = val?['pdfPath'] as String?;
        if (pdfPath != null) {
          final f = File(pdfPath);
          if (f.existsSync()) {
            try {
              f.deleteSync();
            } catch (_) {}
          }
        }
        await record.delete(db);
        deletedCount++;
      }
    }

    return deletedCount;
  }
}
