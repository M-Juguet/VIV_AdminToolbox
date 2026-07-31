import 'package:sembast/sembast.dart';
import 'local_database_service.dart';

class BoondCacheService {
  static final BoondCacheService _singleton = BoondCacheService._internal();

  factory BoondCacheService() {
    return _singleton;
  }

  BoondCacheService._internal();

  final LocalDatabaseService _dbService = LocalDatabaseService();
  final _store = stringMapStoreFactory.store('api_cache');

  /// Lit une réponse du cache pour une clé donnée, si elle n'a pas expiré (TTL)
  Future<dynamic> get(String key, {Duration ttl = const Duration(hours: 24)}) async {
    try {
      final db = await _dbService.database;
      final record = await _store.record(key).get(db);
      
      if (record == null) return null;
      
      final cachedAtStr = record['cachedAt'] as String?;
      if (cachedAtStr == null) return null;
      
      final cachedAt = DateTime.parse(cachedAtStr);
      final difference = DateTime.now().difference(cachedAt);
      
      if (difference > ttl) {
        // Le cache a expiré
        await _store.record(key).delete(db);
        return null;
      }
      
      return record['data'];
    } catch (_) {
      return null;
    }
  }

  /// Écrit une réponse dans le cache pour une clé donnée avec l'horodatage actuel
  Future<void> put(String key, dynamic data) async {
    try {
      final db = await _dbService.database;
      await _store.record(key).put(db, {
        'id': key,
        'data': data,
        'cachedAt': DateTime.now().toIso8601String(),
      });
    } catch (_) {
      // Ignorer les erreurs d'écriture de cache pour ne pas bloquer l'application
    }
  }

  /// Invalide / efface tout le cache d'appels API
  Future<void> clear() async {
    try {
      final db = await _dbService.database;
      await _store.delete(db);
    } catch (_) {}
  }
}
