import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:dio/dio.dart';
import '../../design_system/viv_colors.dart';
import '../../design_system/viv_spacing.dart';
import '../../design_system/viv_typography.dart';
import '../../services/boond_service.dart';

class ApiQuotaDiagnosticScreen extends ConsumerStatefulWidget {
  final VoidCallback onClose;
  const ApiQuotaDiagnosticScreen({super.key, required this.onClose});

  @override
  ConsumerState<ApiQuotaDiagnosticScreen> createState() => _ApiQuotaDiagnosticScreenState();
}

class _ApiQuotaDiagnosticScreenState extends ConsumerState<ApiQuotaDiagnosticScreen> {
  bool _isLoading = false;
  bool _hasTested = false;
  String _statusText = "Prêt à tester.";
  bool _quotaDetected = false;
  bool _isPrivateEndpointRestricted = false;
  
  // Valeurs de quotas détectées
  String? _detectedReset;
  int? _limitValue;
  int? _remainingValue;
  int? _consumedValue;
  double? _usageRatio;

  // Liste de tous les headers
  Map<String, List<String>> _allHeaders = {};
  bool _showRawHeaders = false;

  // Helper pour trouver récursivement une clé numérique dans une structure Map/List
  int? _findKeyInMap(dynamic data, List<String> candidateKeys) {
    if (data is Map) {
      for (var key in candidateKeys) {
        if (data.containsKey(key) && data[key] != null) {
          final val = int.tryParse(data[key].toString());
          if (val != null) return val;
        }
      }
      for (var val in data.values) {
        if (val is Map || val is List) {
          final res = _findKeyInMap(val, candidateKeys);
          if (res != null) return res;
        }
      }
    } else if (data is List) {
      for (var item in data) {
        if (item is Map || item is List) {
          final res = _findKeyInMap(item, candidateKeys);
          if (res != null) return res;
        }
      }
    }
    return null;
  }

  // Analyse des en-têtes
  void _analyzeHeaders(Headers headers) {
    String? limitStr;
    String? remainingStr;
    String? resetStr;

    // Recherche de clés insensibles à la casse
    headers.forEach((name, values) {
      final lowerName = name.toLowerCase();
      if (lowerName.contains('ratelimit') || lowerName.contains('rate-limit') || lowerName.contains('quota')) {
        if (lowerName.contains('limit') && !lowerName.contains('remaining') && !lowerName.contains('reset')) {
          limitStr = values.isNotEmpty ? values.first : null;
        } else if (lowerName.contains('remaining')) {
          remainingStr = values.isNotEmpty ? values.first : null;
        } else if (lowerName.contains('reset')) {
          resetStr = values.isNotEmpty ? values.first : null;
        }
      } else if (lowerName == 'retry-after') {
        resetStr = values.isNotEmpty ? values.first : null;
      }
    });

    final hasLimit = limitStr != null;
    final hasRemaining = remainingStr != null;

    int? limitVal = hasLimit ? int.tryParse(limitStr!) : null;
    int? remainingVal = hasRemaining ? int.tryParse(remainingStr!) : null;

    if (limitVal != null && remainingVal != null) {
      _consumedValue = limitVal - remainingVal;
      if (_consumedValue! < 0) _consumedValue = 0;
      _limitValue = limitVal;
      _remainingValue = remainingVal;
      if (limitVal > 0) {
        _usageRatio = _consumedValue! / limitVal;
      }
      _quotaDetected = true;
    }
    
    if (resetStr != null) {
      _detectedReset = resetStr;
    }
  }

  // Analyse de la réponse JSON combinée aux en-têtes
  void _analyzeResponse(dynamic jsonData, Headers headers) {
    final Map<String, List<String>> tempHeaders = {};
    headers.forEach((name, values) {
      tempHeaders[name] = values;
    });

    // 1. Tenter d'abord l'analyse dans les en-têtes
    _analyzeHeaders(headers);

    // 2. Tenter d'extraire les données du corps de la réponse JSON de /consumptions
    int? parsedUsed = _findKeyInMap(jsonData, ['used', 'count']);
    int? parsedLimit = _findKeyInMap(jsonData, ['allowed', 'limit', 'max', 'quota', 'total']);

    if (parsedUsed != null) {
      _quotaDetected = true;
      _consumedValue = parsedUsed;
      
      if (parsedLimit != null) {
        _limitValue = parsedLimit;
        _remainingValue = parsedLimit - parsedUsed;
        if (parsedLimit > 0) {
          _usageRatio = parsedUsed / parsedLimit;
        }
      } else {
        // Si aucune limite n'est définie dans le JSON, on garde _limitValue = null
        // pour appliquer l'estimation par défaut dans l'UI.
        _limitValue = null;
        _remainingValue = null;
        _usageRatio = null;
      }
    }

    setState(() {
      _hasTested = true;
      _allHeaders = tempHeaders;
    });
  }

  Future<void> _runQuotaDiagnostic() async {
    setState(() {
      _isLoading = true;
      _statusText = "Appel de test en cours vers BoondManager...";
      _quotaDetected = false;
      _isPrivateEndpointRestricted = false;
      _detectedReset = null;
      _limitValue = null;
      _remainingValue = null;
      _consumedValue = null;
      _usageRatio = null;
      _allHeaders = {};
    });

    final service = ref.read(boondServiceProvider);
    final startTime = DateTime.now();
    Response? response;

    try {
      try {
        // Tenter d'appeler l'endpoint consumptions découvert
        response = await service.getRaw('consumptions');
      } on DioException catch (e) {
        // Fallback si la base URL se termine par /1.0/ et cause un 404
        if (e.response?.statusCode == 404) {
          response = await service.getRaw('../consumptions');
        } else {
          rethrow;
        }
      }

      final duration = DateTime.now().difference(startTime).inMilliseconds;
      _analyzeResponse(response.data, response.headers);
      
      setState(() {
        _isLoading = false;
        _statusText = "Connexion établie avec succès ($duration ms).\n"
            "Status Code: ${response!.statusCode}\n"
            "Réponse reçue : ${response.data}";
      });
    } on DioException catch (e) {
      final duration = DateTime.now().difference(startTime).inMilliseconds;
      final errResponse = e.response;
      final is401 = errResponse?.statusCode == 401;
      
      if (errResponse != null) {
        _analyzeResponse(errResponse.data, errResponse.headers);
        setState(() {
          _isLoading = false;
          _isPrivateEndpointRestricted = is401;
          _statusText = is401 
              ? "Erreur 401 : L'API privée `/api/consumptions` refuse l'accès en BasicAuth ($duration ms).\n"
                "Ce point d'accès est protégé et réservé aux sessions web d'utilisateurs connectés sur ui.boondmanager.com.\n\n"
                "Détail de la réponse : ${errResponse.data}"
              : "Réponse d'erreur reçue de BoondManager ($duration ms).\n"
                "Status Code: ${errResponse.statusCode}\n"
                "Erreur: ${e.message}\n"
                "Détail: ${errResponse.data}";
        });
      } else {
        // Pas de réponse (ex: pas d'internet ou serveur inaccessible)
        setState(() {
          _isLoading = false;
          _hasTested = true;
          _statusText = "Erreur de connexion physique ou réseau ($duration ms).\nMessage: ${e.message}";
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasTested = true;
        _statusText = "Erreur inattendue lors de l'appel : $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(VivSpacing.radiusLg),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: VivSpacing.space6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Panneau gauche : Actions
                  Expanded(
                    flex: 2,
                    child: _buildControlPanel(),
                  ),
                  const VerticalDivider(width: 24),
                  // Panneau droit : Diagnostic
                  Expanded(
                    flex: 3,
                    child: _buildResultPanel(),
                  ),
                ],
              ),
            ),
          ),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(VivSpacing.space6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Diagnostic des Quotas & Limites API", style: VivTypography.h3),
              const SizedBox(height: 4),
              Text(
                "Analyse des données de consommation de quota retournées par BoondManager.",
                style: VivTypography.small.copyWith(color: VivColors.gray500),
              ),
            ],
          ),
          ShadButton.ghost(
            padding: EdgeInsets.zero,
            width: 32,
            height: 32,
            onPressed: widget.onClose,
            child: const Icon(LucideIcons.x, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildControlPanel() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("CONTRÔLE DU TEST", style: VivTypography.eyebrow),
          const SizedBox(height: VivSpacing.space4),
          Text(
            "Le test va exécuter une requête GET vers l'endpoint de consommation `/api/consumptions` de BoondManager en utilisant les identifiants de l'application.",
            style: VivTypography.small.copyWith(color: VivColors.gray500, fontSize: 12, height: 1.5),
          ),
          const SizedBox(height: VivSpacing.space6),
          SizedBox(
            width: double.infinity,
            child: ShadButton(
              backgroundColor: VivColors.lime,
              onPressed: _isLoading ? null : _runQuotaDiagnostic,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.only(right: 8.0),
                      child: SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: VivColors.black),
                      ),
                    )
                  else
                    const Icon(LucideIcons.activity, size: 16),
                  const SizedBox(width: 8),
                  Text(_isLoading ? "Analyse en cours..." : "Lancer l'analyse"),
                ],
              ),
            ),
          ),
          const SizedBox(height: VivSpacing.space6),
          Text("RÉSULTAT DE LA CONNEXION", style: VivTypography.eyebrow),
          const SizedBox(height: VivSpacing.space3),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(VivSpacing.space3),
            decoration: BoxDecoration(
              color: VivColors.offWhite,
              borderRadius: BorderRadius.circular(VivSpacing.radiusMd),
              border: Border.all(color: VivColors.gray200),
            ),
            child: Text(
              _statusText,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: VivColors.black),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultPanel() {
    if (!_hasTested) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.info, size: 40, color: VivColors.gray400),
            SizedBox(height: 12),
            Text(
              "En attente de l'analyse.",
              style: TextStyle(color: VivColors.gray500, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 4),
            Text(
              "Cliquez sur 'Lancer l'analyse' pour exécuter le test.",
              style: TextStyle(color: VivColors.gray400, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("RÉSULTATS DE QUOTAS", style: VivTypography.eyebrow),
        const SizedBox(height: VivSpacing.space3),
        
        // Bandeau d'état (Trouvé / Non trouvé)
        _buildStatusBanner(),
        
        const SizedBox(height: VivSpacing.space6),
        
        if (_quotaDetected) ...[
          _buildQuotaDetails(),
        ] else ...[
          _buildNoQuotaBanner(),
        ],
        
        const Spacer(),
        const Divider(),
        
        // Section technique déroulante
        _buildRawHeadersSection(),
      ],
    );
  }

  Widget _buildStatusBanner() {
    final color = _quotaDetected ? VivColors.lime : Colors.orange;
    final icon = _quotaDetected ? LucideIcons.circleCheck : LucideIcons.circleAlert;
    final text = _quotaDetected 
        ? "Informations de consommation récupérées avec succès !" 
        : "Impossible de détecter les données de quota ou de consommation.";

    return Container(
      padding: const EdgeInsets.all(VivSpacing.space4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(VivSpacing.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: VivTypography.small.copyWith(
                fontWeight: FontWeight.bold,
                color: VivColors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuotaDetails() {
    final bool isLimitEstimated = _limitValue == null;
    final int limitVal = _limitValue ?? 600;
    final int consumedVal = _consumedValue ?? 0;
    final int remainingVal = _remainingValue ?? (limitVal - consumedVal);
    final double ratioVal = (_usageRatio ?? (consumedVal / limitVal)).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Chiffres Clés
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildStatItem("Limite globale", isLimitEstimated ? "$limitVal (Est.)" : "$limitVal"),
            _buildStatItem("Appels restants", "$remainingVal"),
            _buildStatItem("Consommation actuelle", "$consumedVal"),
          ],
        ),
        
        const SizedBox(height: VivSpacing.space6),
        Text(
          "Visualisation de la consommation",
          style: VivTypography.small.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratioVal,
            minHeight: 16,
            backgroundColor: VivColors.gray100,
            color: VivColors.lime,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "$consumedVal appels consommés",
              style: VivTypography.small.copyWith(fontSize: 11, color: VivColors.gray500),
            ),
            Text(
              "${(ratioVal * 100).toStringAsFixed(1)}%",
              style: VivTypography.small.copyWith(
                fontSize: 11, 
                fontWeight: FontWeight.bold,
                color: VivColors.black,
              ),
            ),
          ],
        ),
        
        if (isLimitEstimated) ...[
          const SizedBox(height: VivSpacing.space4),
          Text(
            "* Note : La limite globale de $limitVal a été estimée par défaut pour l'API.",
            style: VivTypography.small.copyWith(fontSize: 10, color: VivColors.gray400, fontStyle: FontStyle.italic),
          ),
        ],
        
        if (_detectedReset != null) ...[
          const SizedBox(height: VivSpacing.space5),
          Row(
            children: [
              const Icon(LucideIcons.clock, size: 14, color: VivColors.gray500),
              const SizedBox(width: 8),
              Text(
                "Temps avant réinitialisation : ",
                style: VivTypography.small.copyWith(color: VivColors.gray500, fontSize: 12),
              ),
              Text(
                _detectedReset!,
                style: VivTypography.small.copyWith(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: VivTypography.small.copyWith(color: VivColors.gray500, fontSize: 11),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: VivTypography.h2.copyWith(color: VivColors.black, fontSize: 20),
        ),
      ],
    );
  }

  Widget _buildNoQuotaBanner() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Pourquoi cette information est absente ?",
          style: VivTypography.small.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          _isPrivateEndpointRestricted
              ? "L'endpoint de consommation `/api/consumptions` a retourné une erreur HTTP 401 (Non autorisé).\n\n"
                "Cela confirme que cette URL est privée et réservée aux sessions web d'utilisateurs connectés dans le navigateur.\n\n"
                "L'authentification technique standard par clé API ou BasicAuth (utilisée par cette application) ne possède pas les privilèges suffisants pour interroger cet endpoint. BoondManager n'expose pas cette métrique de quota via l'API publique standard."
              : "L'appel à `/api/consumptions` de BoondManager n'a pas retourné de clés exploitables de consommation (comme `used` ou `count`) et aucun en-tête HTTP de quota n'a été détecté.\n\nVérifiez que les identifiants configurés possèdent bien les privilèges nécessaires dans l'administration pour interroger cet endpoint.",
          style: VivTypography.small.copyWith(color: VivColors.gray500, height: 1.6, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildRawHeadersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => setState(() => _showRawHeaders = !_showRawHeaders),
            child: Row(
              children: [
                Icon(
                  _showRawHeaders ? LucideIcons.chevronDown : LucideIcons.chevronRight,
                  size: 16,
                  color: VivColors.gray500,
                ),
                const SizedBox(width: 6),
                Text(
                  "Voir tous les en-têtes HTTP de réponse (${_allHeaders.length})",
                  style: VivTypography.small.copyWith(
                    color: VivColors.gray500,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_showRawHeaders) ...[
          const SizedBox(height: 8),
          Container(
            height: 150,
            width: double.infinity,
            padding: const EdgeInsets.all(VivSpacing.space3),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(VivSpacing.radiusMd),
            ),
            child: SingleChildScrollView(
              child: SelectableText(
                _allHeaders.entries
                    .map((e) => "${e.key}: ${e.value.join(', ')}")
                    .join('\n'),
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10,
                  color: Color(0xFF9CDCFE),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: VivSpacing.space6, vertical: 16),
      decoration: const BoxDecoration(
        color: VivColors.offWhite,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(VivSpacing.radiusLg),
          bottomRight: Radius.circular(VivSpacing.radiusLg),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          ShadButton.outline(
            onPressed: widget.onClose,
            child: const Text("Fermer"),
          ),
        ],
      ),
    );
  }
}
