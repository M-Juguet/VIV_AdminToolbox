import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast.dart';
import 'local_database_service.dart';

class BdcSentLogsService {
  static final BdcSentLogsService _singleton = BdcSentLogsService._internal();

  factory BdcSentLogsService() {
    return _singleton;
  }

  BdcSentLogsService._internal();

  final LocalDatabaseService _dbService = LocalDatabaseService();
  final _store = stringMapStoreFactory.store('bdc_sent_logs');

  /// Sauvegarde physiquement le fichier PDF dans le répertoire local '/bdc_history'
  Future<String> _savePdfFile(String consultantName, String period, Uint8List pdfBytes) async {
    final directory = await getApplicationSupportDirectory();
    final historyDir = Directory(join(directory.path, 'bdc_history'));
    
    if (!historyDir.existsSync()) {
      historyDir.createSync(recursive: true);
    }
    
    // Assainir le nom de fichier
    final sanitizedName = consultantName.replaceAll(RegExp(r'[^\w\s\-]'), '_').replaceAll(' ', '_');
    final sanitizedPeriod = period.replaceAll('/', '_');
    final filePath = join(historyDir.path, 'BDC_${sanitizedName}_$sanitizedPeriod.pdf');
    
    final file = File(filePath);
    await file.writeAsBytes(pdfBytes);
    return filePath;
  }

  /// Enregistre les métadonnées de l'envoi et archive le document PDF associé
  Future<void> logSentBdc({
    required String providerId,
    required String consultantName,
    required String clientName,
    required String projectName,
    required String prestationTitle,
    required String period,
    required String sentToEmail,
    required String bdcNumber,
    required double uoCount,
    required double totalHt,
    required Uint8List pdfBytes,
  }) async {
    // 1. Sauvegarder le PDF physiquement
    final pdfPath = await _savePdfFile(consultantName, period, pdfBytes);
    
    // 2. Enregistrer les métadonnées dans Sembast
    final db = await _dbService.database;
    final id = '${providerId}_${period.replaceAll('/', '_')}';
    
    await _store.record(id).put(db, {
      'id': id,
      'providerId': providerId,
      'consultantName': consultantName,
      'clientName': clientName,
      'projectName': projectName,
      'prestationTitle': prestationTitle,
      'period': period,
      'sentAt': DateTime.now().toIso8601String(),
      'sentToEmail': sentToEmail,
      'pdfPath': pdfPath,
      'bdcNumber': bdcNumber,
      'uoCount': uoCount,
      'totalHt': totalHt,
    });
  }

  /// Récupère l'historique d'envoi pour un fournisseur et une période donnée
  Future<Map<String, dynamic>?> getSentLog(String providerId, String period) async {
    final db = await _dbService.database;
    final id = '${providerId}_${period.replaceAll('/', '_')}';
    return await _store.record(id).get(db);
  }

  /// Récupère tous les logs d'envoi enregistrés (historique global)
  Future<List<Map<String, dynamic>>> getAllSentLogs() async {
    final db = await _dbService.database;
    final records = await _store.find(db);
    return records.map((r) => Map<String, dynamic>.from(r.value)).toList();
  }

  /// Supprime un log d'envoi et son fichier PDF associé
  Future<void> deleteSentLog(String providerId, String period) async {
    final db = await _dbService.database;
    final id = '${providerId}_${period.replaceAll('/', '_')}';
    
    final log = await _store.record(id).get(db);
    if (log != null) {
      final pdfPath = log['pdfPath'] as String?;
      if (pdfPath != null) {
        final file = File(pdfPath);
        if (file.existsSync()) {
          try {
            file.deleteSync();
          } catch (_) {
            // Ignorer si échec de suppression physique
          }
        }
      }
      await _store.record(id).delete(db);
    }
  }

  /// Vide complètement l'historique d'envois et supprime tous les PDF physiques
  Future<void> clearAllSentLogs() async {
    final db = await _dbService.database;
    
    // Supprimer tous les fichiers physiques
    final directory = await getApplicationSupportDirectory();
    final historyDir = Directory(join(directory.path, 'bdc_history'));
    if (historyDir.existsSync()) {
      try {
        historyDir.deleteSync(recursive: true);
      } catch (_) {
        // Ignorer si échec
      }
    }
    
    // Vider le store
    await _store.delete(db);
  }
}
