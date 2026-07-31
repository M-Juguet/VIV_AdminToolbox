import 'dart:async';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast_io.dart';

class LocalDatabaseService {
  static final LocalDatabaseService _singleton = LocalDatabaseService._internal();

  factory LocalDatabaseService() {
    return _singleton;
  }

  LocalDatabaseService._internal();

  Database? _database;
  final Completer<Database> _dbOpenCompleter = Completer();

  /// Initialise la base de données et retourne l'instance active
  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    if (!_dbOpenCompleter.isCompleted) {
      _initDatabase();
    }

    return _dbOpenCompleter.future;
  }

  Future<void> _initDatabase() async {
    try {
      // Récupérer le dossier de stockage système pour l'application
      final directory = await getApplicationSupportDirectory();
      
      // S'assurer que le dossier existe
      if (!directory.existsSync()) {
        directory.createSync(recursive: true);
      }

      final dbPath = join(directory.path, 'opsis_local_db.db');
      final DatabaseFactory dbFactory = databaseFactoryIo;
      
      final db = await dbFactory.openDatabase(dbPath);
      _database = db;
      _dbOpenCompleter.complete(db);
    } catch (e, stacktrace) {
      _dbOpenCompleter.completeError(e, stacktrace);
    }
  }

  /// Ferme proprement la base de données
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
