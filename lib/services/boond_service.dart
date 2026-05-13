import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';

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

  /// Récupère le profil de l'utilisateur connecté
  Future<Map<String, dynamic>> getCurrentUserProfile() async {
    try {
      final response = await _dio.get('application/currentUser');
      return response.data['data'];
    } catch (e) {
      throw 'Erreur lors de la récupération du profil : $e';
    }
  }

  /// Récupère le dictionnaire complet (référentiels)
  Future<Map<String, dynamic>> getDictionary() async {
    try {
      final response = await _dio.get('application/dictionary');
      return response.data;
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

  /// Récupère les prestations (deliveries) associées à un projet
  Future<List<dynamic>> getDeliveries(int projectId) async {
    try {
      final response = await _dio.get('projects/$projectId/deliveries-groupments');
      final dynamic data = response.data['data'];
      if (data is List) return data;
      if (data != null) return [data];
      return [];
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

  /// Récupère les jours fériés et week-ends pour une période donnée
  Future<List<String>> getHolidays(int year, {String? agencyId}) async {
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

  /// Récupère un achat spécifique
  Future<Map<String, dynamic>> getPurchase(int id) async {
    try {
      final response = await _dio.get('purchases/$id');
      return response.data['data'];
    } catch (e) {
      throw e.toString();
    }
  }

  /// Récupère une société spécifique
  Future<Map<String, dynamic>> getCompany(int id) async {
    try {
      final response = await _dio.get('companies/$id');
      return response.data['data'];
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

  /// Teste la connexion à BoondManager
  Future<void> testConnection() async {
    await getCurrentUserProfile();
  }
}
