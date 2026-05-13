import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../models/github_release.dart';

class UpdateService {
  final Dio _dio = Dio();
  final String _repoOwner = 'M-Juguet';
  final String _repoName = 'VIV_AdminToolbox';

  // Le token peut être défini à la compilation via : --dart-define=GITHUB_TOKEN=xxx
  static const String _githubToken = String.fromEnvironment('GITHUB_TOKEN');

  Future<String> getCurrentVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return packageInfo.version;
    } catch (e) {
      return '0.1.0';
    }
  }

  Future<GithubRelease?> checkUpdate() async {
    try {
      final headers = <String, String>{
        'Accept': 'application/vnd.github.v3+json',
      };
      if (_githubToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $_githubToken';
      }

      final response = await _dio.get(
        'https://api.github.com/repos/$_repoOwner/$_repoName/releases/latest',
        options: Options(headers: headers),
      );

      if (response.statusCode == 200) {
        return GithubRelease.fromJson(response.data);
      }
    } catch (e) {
      // En cas d'absence de réseau ou de repo privé sans token correct, on retourne null
      debugPrint("Erreur lors de la vérification de mise à jour : $e");
    }
    return null;
  }

  Future<String?> downloadUpdate(String url, Function(int, int) onProgress) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final savePath = '${tempDir.path}\\opsis_update.exe';
      
      await _dio.download(
        url,
        savePath,
        onReceiveProgress: onProgress,
      );
      
      return savePath;
    } catch (e) {
      debugPrint("Erreur lors du téléchargement de la mise à jour : $e");
      return null;
    }
  }

  Future<void> installUpdate(String exePath) async {
    try {
      // Exécute le .exe et détache le processus de l'application Flutter
      await Process.start(
        exePath,
        [],
        mode: ProcessStartMode.detached,
      );
      // Fermeture de l'application
      exit(0);
    } catch (e) {
      debugPrint("Erreur lors du lancement de l'installeur : $e");
    }
  }
}
