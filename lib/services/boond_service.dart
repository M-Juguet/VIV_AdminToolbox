import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';
import 'boond_cache_service.dart';

final boondServiceProvider = Provider((ref) {
  final settings = ref.watch(settingsProvider);
  return BoondService(
    baseUrl: settings.boondUrl,
    user: settings.boondUser,
    password: settings.boondPassword,
  );
});

class BoondService {
  final String baseUrl;
  final String user;
  final String password;
  late final Dio _dio;

  BoondService({
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
          'Accept': 'application/json',
        },
      ),
    );
  }

  /// Récupère le profil de l'utilisateur connecté avec cache
  Future<Map<String, dynamic>> getCurrentUserProfile({bool forceRefresh = false}) async {
    const cacheKey = 'currentUserProfile';
    final cache = BoondCacheService();
    if (!forceRefresh) {
      final cachedData = await cache.get(cacheKey, ttl: const Duration(days: 7));
      if (cachedData != null) {
        return Map<String, dynamic>.from(cachedData);
      }
    }

    try {
      final response = await _dio.get('application/currentUser');
      final data = response.data['data'] as Map<String, dynamic>;
      await cache.put(cacheKey, data);
      return data;
    } catch (e) {
      throw 'Erreur lors de la récupération du profil : $e';
    }
  }

  /// Récupère le dictionnaire complet (référentiels) avec cache
  Future<Map<String, dynamic>> getDictionary({bool forceRefresh = false}) async {
    const cacheKey = 'dictionary';
    final cache = BoondCacheService();
    if (!forceRefresh) {
      final cachedData = await cache.get(cacheKey, ttl: const Duration(days: 7));
      if (cachedData != null) {
        return Map<String, dynamic>.from(cachedData);
      }
    }

    try {
      final response = await _dio.get('application/dictionary');
      final data = response.data as Map<String, dynamic>;
      await cache.put(cacheKey, data);
      return data;
    } catch (e) {
      throw 'Erreur lors de la récupération du dictionnaire : $e';
    }
  }

  Future<List<dynamic>> getProjects({Map<String, dynamic>? filters}) async {
    try {
      final response = await _dio.get('projects', queryParameters: filters);
      return response.data['data'];
    } catch (e) {
      throw 'Erreur lors de la récupération des projets : $e';
    }
  }

  /// Récupère la liste des projets avec inclusions relationnelles (ex: include=deliveries,company) avec cache
  Future<Map<String, dynamic>> getProjectsWithInclusions({
    Map<String, dynamic>? filters,
    List<String>? inclusions,
    bool forceRefresh = false,
  }) async {
    final Map<String, dynamic> params = Map.from(filters ?? {});
    if (inclusions != null && inclusions.isNotEmpty) {
      params['include'] = inclusions.join(',');
    }

    // Générer une clé de cache unique basée sur les paramètres
    final cacheKey = 'projects_${jsonEncode(params)}';
    final cache = BoondCacheService();

    if (!forceRefresh) {
      final cachedData = await cache.get(cacheKey);
      if (cachedData != null) {
        return Map<String, dynamic>.from(cachedData);
      }
    }

    try {
      final response = await _dio.get('projects', queryParameters: params);
      final data = response.data as Map<String, dynamic>;
      await cache.put(cacheKey, data);
      return data;
    } catch (e) {
      throw 'Erreur lors de la récupération des projets avec inclusions : $e';
    }
  }

  /// Récupère un projet spécifique par son ID avec inclusions relationnelles (ex: include=company)
  Future<Map<String, dynamic>> getProjectWithInclusions(
    int id, {
    List<String>? inclusions,
  }) async {
    try {
      final Map<String, dynamic> params = {};
      if (inclusions != null && inclusions.isNotEmpty) {
        params['include'] = inclusions.join(',');
      }
      final response = await _dio.get('projects/$id', queryParameters: params);
      return response.data;
    } catch (e) {
      throw 'Erreur lors de la récupération du projet $id : $e';
    }
  }

  /// Récupère la liste des achats avec inclusions relationnelles (ex: include=project,providerCompany)
  Future<Map<String, dynamic>> getPurchasesWithInclusions({
    Map<String, dynamic>? filters,
    List<String>? inclusions,
  }) async {
    try {
      final Map<String, dynamic> params = Map.from(filters ?? {});
      if (inclusions != null && inclusions.isNotEmpty) {
        params['include'] = inclusions.join(',');
      }
      final response = await _dio.get('purchases', queryParameters: params);
      return response.data;
    } catch (e) {
      throw 'Erreur lors de la récupération des achats avec inclusions : $e';
    }
  }

  /// Récupère les prestations (deliveries) associées à un projet avec cache de 24h
  Future<List<dynamic>> getDeliveries(int projectId, {bool forceRefresh = false}) async {
    final cacheKey = 'deliveries_$projectId';
    final cache = BoondCacheService();
    
    if (!forceRefresh) {
      final cachedData = await cache.get(cacheKey, ttl: const Duration(hours: 24));
      if (cachedData != null) {
        return List<dynamic>.from(cachedData);
      }
    }

    try {
      final response = await _dio.get('projects/$projectId/deliveries-groupments');
      final dynamic data = response.data['data'];
      List<dynamic> results = [];
      if (data is List) {
        results = data;
      } else if (data != null) {
        results = [data];
      }
      await cache.put(cacheKey, results);
      return results;
    } on DioException catch (e) {
      // Extraction du message Boond détaillé si disponible
      final responseData = e.response?.data;
      if (responseData is Map && responseData.containsKey('errors')) {
        final errors = responseData['errors'] as List;
        if (errors.isNotEmpty) {
          throw errors[0]['detail'] ?? e.message;
        }
      }
      rethrow;
    } catch (e) {
      throw e.toString();
    }
  }

  /// Récupère la liste des prestations (deliveries) globales ou filtrées
  Future<Map<String, dynamic>> getDeliveriesWithFilters({
    Map<String, dynamic>? filters,
  }) async {
    try {
      final response = await _dio.get('deliveries', queryParameters: filters);
      return response.data;
    } catch (e) {
      throw 'Erreur lors de la récupération des prestations : $e';
    }
  }

  /// Récupère la liste des commandes (orders) avec filtres optionnels
  Future<List<dynamic>> getOrders({Map<String, dynamic>? filters}) async {
    try {
      final response = await _dio.get('orders', queryParameters: filters);
      return response.data['data'];
    } catch (e) {
      throw 'Erreur lors de la récupération des commandes : $e';
    }
  }

  /// Récupère la liste des calendriers configurés dans BoondManager
  Future<List<Map<String, dynamic>>> getCalendars() async {
    try {
      final response = await _dio.get('application/dictionary');
      final dynamic calendars = response.data['data']?['setting']?['calendar'];
      
      if (calendars is Map) {
        return calendars.entries.map((e) => {
          'id': e.key.toString(),
          'label': e.value.toString(),
        }).toList();
      } else if (calendars is List) {
        return calendars.map((e) => {
          'id': e['id']?.toString(),
          'label': e['label']?.toString(),
        }).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Récupère les jours fériés et week-ends pour une période donnée avec cache
  Future<List<String>> getHolidays(int year, {String? agencyId, bool forceRefresh = false}) async {
    final cacheKey = 'holidays_${year}_$agencyId';
    final cache = BoondCacheService();
    
    if (!forceRefresh) {
      final cachedData = await cache.get(cacheKey, ttl: const Duration(days: 30));
      if (cachedData != null) {
        return List<String>.from(cachedData);
      }
    }

    final startDate = '$year-01-01';
    final endDate = '$year-12-31';
    
    Future<List<String>> fetch(String? calId) async {
      final Map<String, dynamic> params = {
        'startDate': startDate,
        'endDate': endDate,
      };
      
      if (calId != null && calId.isNotEmpty && calId != '1') {
        params['calendar'] = calId;
      }

      final response = await _dio.get('application/weekendAndBankHolidays', queryParameters: params);
      final dynamic data = response.data['data'];
      final List<dynamic> results = data is List ? data : (data != null ? [data] : []);
      
      final Set<String> allHolidays = {};
      for (var result in results) {
        if (result['bankHoliday'] == true) {
          final dateStr = result['date']?.toString();
          if (dateStr != null) {
            allHolidays.add(dateStr);
          }
        }
      }
      return allHolidays.toList();
    }

    try {
      List<String> holidays = await fetch(agencyId);
      if (holidays.isEmpty) {
        final calendars = await getCalendars();
        for (var cal in calendars) {
          final calId = cal['id']?.toString();
          if (calId != null) {
            final result = await fetch(calId);
            if (result.isNotEmpty) {
              holidays = result;
              break; 
            }
          }
        }
      }
      
      await cache.put(cacheKey, holidays);
      return holidays;
    } on DioException catch (e) {
      final dynamic errorBody = e.response?.data;
      String detail = e.message ?? 'Erreur inconnue';
      if (errorBody is Map && errorBody.containsKey('errors')) {
        final errors = errorBody['errors'];
        if (errors is List && errors.isNotEmpty) {
          detail = errors[0]['detail'] ?? detail;
        }
      }
      throw 'Boond Error: $detail';
    } catch (e) {
       throw 'Erreur inattendue : $e';
    }
  }

  /// Récupère la liste des agences
  Future<List<Map<String, dynamic>>> getAgencies() async {
    try {
      final response = await _dio.get('agencies');
      final List<dynamic> data = response.data['data'];
      return data.map((e) => {
        'id': e['id']?.toString(),
        'name': e['attributes']?['name']?.toString() ?? 'Agence sans nom',
        'calendarId': e['relationships']?['calendar']?['data']?['id']?.toString(),
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// Récupère un achat spécifique avec cache de 24h
  Future<Map<String, dynamic>> getPurchase(int id, {bool forceRefresh = false}) async {
    final cacheKey = 'purchase_$id';
    final cache = BoondCacheService();
    if (!forceRefresh) {
      final cachedData = await cache.get(cacheKey, ttl: const Duration(hours: 24));
      if (cachedData != null) {
        return Map<String, dynamic>.from(cachedData);
      }
    }
    try {
      final response = await _dio.get('purchases/$id');
      final data = response.data['data'] as Map<String, dynamic>;
      await cache.put(cacheKey, data);
      return data;
    } catch (e) {
      throw e.toString();
    }
  }

  /// Récupère un achat avec ses inclusions de contact et de société fournisseur avec cache de 24h
  Future<Map<String, dynamic>> getPurchaseWithInclusions(int id, {bool forceRefresh = false}) async {
    final cacheKey = 'purchase_inc_$id';
    final cache = BoondCacheService();
    if (!forceRefresh) {
      final cachedData = await cache.get(cacheKey, ttl: const Duration(hours: 24));
      if (cachedData != null) {
        return Map<String, dynamic>.from(cachedData);
      }
    }
    try {
      final response = await _dio.get('purchases/$id', queryParameters: {
        'include': 'providerContact,providerCompany',
      });
      final data = response.data as Map<String, dynamic>;
      await cache.put(cacheKey, data);
      return data;
    } catch (e) {
      throw e.toString();
    }
  }

  /// Récupère une société spécifique (profil de base) avec cache de 3j
  Future<Map<String, dynamic>> getCompany(int id, {bool forceRefresh = false}) async {
    final cacheKey = 'company_$id';
    final cache = BoondCacheService();
    if (!forceRefresh) {
      final cachedData = await cache.get(cacheKey, ttl: const Duration(days: 3));
      if (cachedData != null) {
        return Map<String, dynamic>.from(cachedData);
      }
    }
    try {
      final response = await _dio.get('companies/$id');
      final data = response.data['data'] as Map<String, dynamic>;
      await cache.put(cacheKey, data);
      return data;
    } catch (e) {
      throw e.toString();
    }
  }

  /// Récupère les informations d'une société spécifique (adresse, numéro de fournisseur) avec cache de 3j
  Future<Map<String, dynamic>> getCompanyInformation(int id, {bool forceRefresh = false}) async {
    final cacheKey = 'company_info_$id';
    final cache = BoondCacheService();
    if (!forceRefresh) {
      final cachedData = await cache.get(cacheKey, ttl: const Duration(days: 3));
      if (cachedData != null) {
        return Map<String, dynamic>.from(cachedData);
      }
    }
    try {
      final response = await _dio.get('companies/$id/information');
      final data = response.data['data'] as Map<String, dynamic>;
      await cache.put(cacheKey, data);
      return data;
    } catch (e) {
      throw e.toString();
    }
  }

  /// Récupère les contacts d'une société
  Future<List<dynamic>> getCompanyContacts(int id) async {
    try {
      final response = await _dio.get('companies/$id/contacts');
      return response.data['data'];
    } catch (e) {
      throw e.toString();
    }
  }

  /// Récupère une ressource spécifique avec cache de 3j
  Future<Map<String, dynamic>> getResource(int id, {bool forceRefresh = false}) async {
    final cacheKey = 'resource_$id';
    final cache = BoondCacheService();
    if (!forceRefresh) {
      final cachedData = await cache.get(cacheKey, ttl: const Duration(days: 3));
      if (cachedData != null) {
        return Map<String, dynamic>.from(cachedData);
      }
    }
    try {
      final response = await _dio.get('resources/$id/information');
      final data = response.data['data'] as Map<String, dynamic>;
      await cache.put(cacheKey, data);
      return data;
    } catch (e) {
      throw e.toString();
    }
  }

  /// Exécute une requête GET brute (utile pour inspecter les en-têtes et les métadonnées de réponse)
  Future<Response<T>> getRaw<T>(String path, {Map<String, dynamic>? queryParameters}) {
    return _dio.get<T>(path, queryParameters: queryParameters);
  }

  /// Teste la connexion à BoondManager
  Future<void> testConnection() async {
    await getCurrentUserProfile();
  }
}
