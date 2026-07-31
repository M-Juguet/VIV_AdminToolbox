import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';

final extractionServiceProvider = Provider((ref) {
  final settings = ref.watch(settingsProvider);
  return ExtractionService(
    baseUrl: settings.boondUrl,
    user: settings.boondUser,
    password: settings.boondPassword,
  );
});

class ExtractionService {
  final String baseUrl;
  final String user;
  final String password;
  late final Dio _dio;

  ExtractionService({
    required String baseUrl,
    required this.user,
    required this.password,
  }) : baseUrl = baseUrl.isEmpty 
            ? "" 
            : (baseUrl.endsWith('/') ? baseUrl : '$baseUrl/') {
    _dio = Dio(
      BaseOptions(
        baseUrl: this.baseUrl.isEmpty ? 'https://localhost' : this.baseUrl,
        headers: {
          'Authorization': 'Basic ${base64Encode(utf8.encode('$user:$password'))}',
          'Accept': '*/*',
        },
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(minutes: 5), // Timeout étendu à 5 minutes pour les gros volumes
      ),
    );
  }

  /// Extrait des données CSV de manière paginée et les enregistre dans un fichier local
  Future<String> extractPagedCsv({
    required String path,
    required Map<String, dynamic> queryParameters,
    required String destinationDir,
    required String fileName,
    required Function(String) onProgress,
  }) async {
    final Directory dir = Directory(destinationDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final String outputFilePath = '$destinationDir${Platform.pathSeparator}$fileName';
    final File outputFile = File(outputFilePath);
    if (await outputFile.exists()) {
      try {
        await outputFile.delete();
      } catch (e) {
        throw "Impossible de remplacer le fichier existant (il est peut-être ouvert dans un autre programme) : $e";
      }
    }

    int page = 1;
    bool hasMore = true;
    final List<String> combinedLines = [];
    String? headerLine;
    String? previousPageRawData;

    // Paramètres de requête de base
    final Map<String, dynamic> params = Map.from(queryParameters);
    params['extraction'] = 'csv';
    params['encoding'] = 'UTF-8';
    
    // --- OPTIMISATION CIBLÉE : FORCER LA TAILLE DE PAGE MAX SUR LES ENDPOINTS COMPATIBLES ---
    // maxResults=500 est supporté et utile pour réduire les appels sur les ressources et les entreprises.
    final bool supportsMaxResults = path.contains('companies') || path.contains('resources');
    if (supportsMaxResults) {
      params['maxResults'] = 500;
    }

    final bool isPaged = !path.contains('download') && !path.contains('requests');

    onProgress("Démarrage de l'extraction...");

    while (hasMore) {
      // --- PROTECTION : LIMITE ABSOLUE DE PAGES POUR ÉVITER LES EMBALLEMENTS ---
      const int maxPages = 15; 
      if (page > maxPages) {
        throw "Sécurité : Limite de pages atteinte ($maxPages). L'API BoondManager semble boucler ou ignorer la pagination.";
      }

      params['page'] = page;
      final progressMsg = supportsMaxResults 
          ? "Téléchargement de la page $page (maxResults: 500)..."
          : "Téléchargement de la page $page...";
      onProgress(progressMsg);

      try {
        final response = await _dio.get<String>(
          path,
          queryParameters: params,
          options: Options(responseType: ResponseType.plain),
        );

        final String? csvContent = response.data;
        if (csvContent == null || csvContent.trim().isEmpty) {
          hasMore = false;
          break;
        }

        // --- PROTECTION : DÉTECTION DU HTML (ERREUR DE ROUTE OU SESSION EXPIRÉE) ---
        final String trimmedContent = csvContent.trim();
        if (trimmedContent.toLowerCase().startsWith('<!doctype html') ||
            trimmedContent.contains('<html') ||
            trimmedContent.contains('<head>')) {
          
          String diagnosticMessage = "L'API BoondManager a renvoyé du HTML au lieu d'un CSV (Redirection SPA/Login). L'URL est probablement incorrecte.";
          
          // Essai de requête de diagnostic pour comprendre si c'est un problème d'habilitation
          final parentPath = path.replaceAll('/extraction', '');
          try {
            final diagResponse = await _dio.get(
              parentPath,
              options: Options(
                headers: {'Accept': 'application/json'},
                responseType: ResponseType.plain, // Évite les crashs de parsing si le parent renvoie aussi du HTML
              ),
            );
            
            final String body = diagResponse.data?.toString() ?? '';
            if (body.trim().toLowerCase().startsWith('<!doctype html') || body.contains('<html')) {
              diagnosticMessage = "Le diagnostic sur '$parentPath' a également retourné du HTML. Authentification par session requise ou route parente invalide.";
            } else if (diagResponse.statusCode == 200) {
              diagnosticMessage = "L'utilisateur est habilité sur l'API REST parent '$parentPath' (200 OK), mais l'export CSV est refusé ou indisponible à l'adresse '$path' sur cette instance.";
            }
          } on DioException catch (de) {
            final code = de.response?.statusCode;
            final dynamic errorData = de.response?.data;
            String errorDetail = de.response?.statusMessage ?? de.message ?? "Erreur inconnue";
            
            // Tentative d'extraction du message d'erreur détaillé de BoondManager
            if (errorData != null) {
              try {
                final Map<String, dynamic> errJson = jsonDecode(errorData.toString());
                if (errJson.containsKey('errors')) {
                  final List<dynamic> errors = errJson['errors'];
                  if (errors.isNotEmpty) {
                    errorDetail = errors[0]['detail'] ?? errorDetail;
                  }
                }
              } catch (_) {}
            }

            if (code == 403) {
              diagnosticMessage = "Accès refusé (403) : Votre compte ne possède pas l'habilitation nécessaire en lecture sur ce module pour extraire ces données.";
            } else if (code == 401) {
              diagnosticMessage = "Erreur d'authentification (401) : Vos identifiants BoondManager sont incorrects.";
            } else if (code == 404) {
              diagnosticMessage = "L'URL parente de l'API REST '$parentPath' n'existe pas sur ce serveur (404).";
            } else {
              diagnosticMessage = "Erreur HTTP de diagnostic ($code) : $errorDetail";
            }
          } catch (e) {
            diagnosticMessage = "Échec du diagnostic de connexion ($e).";
          }
          
          throw diagnosticMessage;
        }

        // --- PROTECTION : DÉTECTION DU RETOUR EN BOUCLE (CONTENU BRUT IDENTIQUE) ---
        // Si BoondManager renvoie le même contenu que la page précédente (par exemple en ignorant 'page'
        // ou en bouclant sur la dernière page), on s'arrête immédiatement pour économiser les quotas.
        if (previousPageRawData != null && csvContent.trim() == previousPageRawData.trim()) {
          onProgress("Extraction terminée (fin de la liste détectée).");
          hasMore = false;
          break;
        }
        previousPageRawData = csvContent;

        // Découpage en lignes (supporte \n et \r\n)
        final lines = csvContent.split(RegExp(r'\r?\n'));
        
        // Nettoyage des lignes vides
        final cleanLines = lines.where((line) => line.trim().isNotEmpty).toList();

        if (cleanLines.isEmpty) {
          hasMore = false;
          break;
        }

        if (page == 1) {
          headerLine = cleanLines.first;
          combinedLines.addAll(cleanLines);
        } else {
          // Retrait de l'en-tête s'il est répété
          final firstLine = cleanLines.first;
          if (firstLine == headerLine) {
            cleanLines.removeAt(0);
          }
          
          if (cleanLines.isEmpty) {
            hasMore = false;
            break;
          }
          combinedLines.addAll(cleanLines);
        }

        // Si le nombre de nouvelles lignes récupérées est très faible (ex: uniquement l'en-tête), on s'arrête
        if (cleanLines.length < 2) {
          hasMore = false;
          break;
        }

        if (!isPaged) {
          hasMore = false;
          break;
        }
        page++;
        // Léger délai de courtoisie pour l'API
        await Future.delayed(const Duration(milliseconds: 200));
      } on DioException catch (e) {
        String errMsg = e.message ?? "Erreur réseau";
        if (e.response?.statusCode != null) {
          errMsg = "Erreur HTTP ${e.response?.statusCode} : ${e.response?.statusMessage}";
        }
        throw errMsg;
      } catch (e) {
        throw "Erreur de traitement : $e";
      }
    }

    if (combinedLines.isEmpty) {
      throw "Aucune donnée n'a pu être extraite de BoondManager.";
    }

    // Écriture du fichier final
    onProgress("Écriture du fichier...");
    final String finalContent = combinedLines.join('\r\n'); // Format standard Excel Windows
    await outputFile.writeAsString(finalContent, encoding: utf8);

    return outputFilePath;
  }
}
