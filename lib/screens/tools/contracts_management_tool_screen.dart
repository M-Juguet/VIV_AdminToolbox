import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import '../../design_system/viv_colors.dart';
import '../../design_system/viv_spacing.dart';
import '../../design_system/viv_typography.dart';
import '../../services/boond_service.dart';

class ContractsManagementToolWidget extends ConsumerStatefulWidget {
  final VoidCallback onClose;
  const ContractsManagementToolWidget({super.key, required this.onClose});

  @override
  ConsumerState<ContractsManagementToolWidget> createState() => _ContractsManagementToolWidgetState();
}

class _ContractsManagementToolWidgetState extends ConsumerState<ContractsManagementToolWidget> {
  // Indicateurs d'état
  bool _isLoadingMetadata = true;
  bool _isActionInProgress = false;
  String _errorMsg = "";

  // Référentiels
  List<Map<String, dynamic>> _contractTypes = [];
  List<Map<String, dynamic>> _resourcesList = [];

  // Ressource sélectionnée
  Map<String, dynamic>? _selectedResource;
  final _resourceSearchController = TextEditingController();
  List<Map<String, dynamic>> _existingContracts = [];

  // Formulaire de création de nouveau contrat
  String? _selectedContractType;
  final _startDateController = TextEditingController();
  final _endDateController = TextEditingController();
  final _tjmController = TextEditingController();

  // Diagnostic / Logs
  final List<String> _logs = [];
  String _lastRequestPayload = "";
  String _lastResponsePayload = "";
  String _lastResponseHeaders = "";

  @override
  void initState() {
    super.initState();
    _initDefaultDates();
    _loadMetadata();
  }

  void _initDefaultDates() {
    final now = DateTime.now();
    final year = now.year.toString().padLeft(4, '0');
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    _startDateController.text = "$year-$month-$day";
    _endDateController.clear();
    _tjmController.clear();
  }

  Future<void> _loadMetadata() async {
    setState(() {
      _isLoadingMetadata = true;
      _errorMsg = "";
      _addLog("Chargement des référentiels de contrats BoondManager...");
    });

    final service = ref.read(boondServiceProvider);

    try {
      // 1. Dictionnaire d'application pour les types de contrats
      final dict = await service.getDictionary();
      final settings = dict['data']?['setting'] as Map<String, dynamic>? ?? {};

      final typeList = (settings['typeOf']?['contract'] ?? 
                        settings['typeOf']?['contracts'] ?? 
                        settings['typeOf']?['resourceContract'] ?? 
                        settings['contractType']) as List? ?? [];
      _contractTypes = typeList.map<Map<String, dynamic>>((e) => {
        'id': e['id']?.toString() ?? '',
        'label': (e['value'] ?? e['label'] ?? e['name'] ?? '').toString()
      }).toList();

      // Sélectionner "Sous-traitant" / "Sous-traitance" par défaut si trouvé
      if (_contractTypes.isNotEmpty) {
        final sousTraitantType = _contractTypes.firstWhere(
          (t) {
            final l = t['label'].toString().toLowerCase();
            return l.contains('sous-trait') || l.contains('soustrait') || l.contains('prestataire') || l.contains('fournisseur');
          },
          orElse: () => _contractTypes.first,
        );
        _selectedContractType = sousTraitantType['id'];
      }

      // 2. Charger les ressources récentes pour faciliter la sélection
      try {
        final resRaw = await service.searchResources('');
        _resourcesList = resRaw.map<Map<String, dynamic>>((r) {
          final attrs = r['attributes'] as Map<String, dynamic>? ?? {};
          final first = (attrs['firstName'] ?? '').toString();
          final last = (attrs['lastName'] ?? '').toString();
          final reference = (attrs['reference'] ?? '').toString();
          final label = reference.isNotEmpty 
              ? "$first $last ($reference)" 
              : "$first $last";
          return {
            'id': r['id']?.toString() ?? '',
            'label': label.trim().isNotEmpty ? label : "Ressource #${r['id']}",
            'raw': r,
          };
        }).toList();
        _addLog("Ressources chargées avec succès (${_resourcesList.length} trouvées).");
      } catch (e) {
        _addLog("Remarque: Chargement initial de la liste des ressources : $e");
      }

      setState(() {
        _isLoadingMetadata = false;
      });
      _addLog("Référentiels chargés (${_contractTypes.length} types de contrats disponibles).");
    } catch (e) {
      setState(() {
        _isLoadingMetadata = false;
        _errorMsg = "Erreur lors du chargement des référentiels : $e";
      });
      _addLog("ERREUR Référentiels : $e");
    }
  }

  void _addLog(String msg) {
    final time = DateTime.now().toIso8601String().substring(11, 19);
    setState(() {
      _logs.add("[$time] $msg");
    });
  }

  // Recherche et sélection d'une ressource
  Future<void> _searchAndLoadResource(String query) async {
    query = query.trim();
    if (query.isEmpty) {
      ShadToaster.of(context).show(
        const ShadToast(
          title: Text("Champ requis"),
          description: Text("Veuillez renseigner un nom, prénom ou une référence de ressource."),
          backgroundColor: Colors.amber,
        ),
      );
      return;
    }

    setState(() {
      _isActionInProgress = true;
      _errorMsg = "";
      _selectedResource = null;
      _existingContracts = [];
    });

    final service = ref.read(boondServiceProvider);
    _addLog("Recherche de la ressource '$query'...");

    try {
      final resources = await service.searchResources(query);

      if (resources.isEmpty) {
        _addLog("Aucune ressource trouvée pour '$query'.");
        setState(() {
          _isActionInProgress = false;
          _errorMsg = "Aucune ressource trouvée correspondant à '$query'.";
        });
        if (!mounted) return;
        ShadToaster.of(context).show(
          const ShadToast(
            title: Text("Ressource non trouvée"),
            description: Text("Aucune ressource ne correspond à votre recherche."),
            backgroundColor: Colors.amber,
          ),
        );
        return;
      }

      final matchedResource = resources.first;
      final resId = matchedResource['id'].toString();
      final attrs = matchedResource['attributes'] as Map<String, dynamic>? ?? {};
      final resName = "${attrs['firstName'] ?? ''} ${attrs['lastName'] ?? ''}".trim();

      _addLog("Ressource sélectionnée : $resName (ID $resId). Chargement des contrats...");

      // Récupérer les contrats existants
      List<dynamic> rawContracts = [];
      try {
        rawContracts = await service.getContractsForResource(resId);
        _addLog("${rawContracts.length} contrat(s) trouvé(s) pour la ressource ID $resId.");
      } catch (e) {
        _addLog("Remarque sur la récupération directe des contrats : $e");
        // Tentative alternative via GET /resources/{id}/administrative
        try {
          final adminResp = await service.getRaw('resources/$resId/administrative');
          final included = adminResp.data['included'] as List? ?? [];
          rawContracts = included.where((item) => item['type'] == 'contract' || item['type'] == 'contracts').toList();
          _addLog("Récupération via onglet administratif : ${rawContracts.length} contrat(s).");
        } catch (e2) {
          _addLog("Erreur lors de la récupération des contrats : $e2");
        }
      }

      // Enrichir chaque contrat avec ses données détaillées pour récupérer le TJM exact
      final detailedContracts = <Map<String, dynamic>>[];
      for (final c in rawContracts) {
        final cId = c['id']?.toString();
        if (cId != null && cId.isNotEmpty) {
          try {
            final cDetailResp = await service.getRaw('contracts/$cId');
            final cData = cDetailResp.data?['data'] as Map<String, dynamic>?;
            if (cData != null) {
              _addLog("Détails Contrat ID $cId chargés : ${cData['attributes']}");
              detailedContracts.add(cData);
              continue;
            }
          } catch (e) {
            _addLog("Note récupération détails contrat $cId : $e");
          }
        }
        detailedContracts.add(Map<String, dynamic>.from(c));
      }

      setState(() {
        _selectedResource = matchedResource;
        _existingContracts = detailedContracts;
        _isActionInProgress = false;
      });

      if (!mounted) return;
      ShadToaster.of(context).show(
        ShadToast(
          title: const Text("Ressource chargée"),
          description: Text("Fiche de $resName chargée avec ${_existingContracts.length} contrat(s)."),
          backgroundColor: Colors.teal,
        ),
      );
    } catch (e) {
      _addLog("ERREUR lors de la recherche : $e");
      setState(() {
        _isActionInProgress = false;
        _errorMsg = "Erreur lors de la recherche : $e";
      });
    }
  }

  // Création d'un nouveau contrat (POST /contracts)
  Future<void> _processCreateContract() async {
    if (_selectedResource == null) {
      ShadToaster.of(context).show(
        const ShadToast(
          title: Text("Ressource requise"),
          description: Text("Veuillez sélectionner une ressource avant de créer un contrat."),
          backgroundColor: Colors.amber,
        ),
      );
      return;
    }

    final resId = _selectedResource!['id'].toString();
    final startDate = _startDateController.text.trim();
    final endDate = _endDateController.text.trim();
    final tjmStr = _tjmController.text.trim();

    if (startDate.isEmpty) {
      ShadToaster.of(context).show(
        const ShadToast(
          title: Text("Champ requis"),
          description: Text("La date de début du contrat est obligatoire."),
          backgroundColor: Colors.amber,
        ),
      );
      return;
    }

    if (_selectedContractType == null || _selectedContractType!.isEmpty) {
      ShadToaster.of(context).show(
        const ShadToast(
          title: Text("Champ requis"),
          description: Text("Le type de contrat est obligatoire."),
          backgroundColor: Colors.amber,
        ),
      );
      return;
    }

    setState(() {
      _isActionInProgress = true;
      _errorMsg = "";
    });

    final service = ref.read(boondServiceProvider);
    _addLog("Création d'un nouveau contrat pour la ressource ID $resId...");

    try {
      final double? tjmVal = double.tryParse(tjmStr.replaceAll(',', '.'));
      final int? typeVal = int.tryParse(_selectedContractType!);

      final Map<String, dynamic> attributes = {
        'startDate': startDate,
        if (endDate.isNotEmpty) 'endDate': endDate,
      };
      if (typeVal != null) {
        attributes['typeOf'] = typeVal;
      }
      if (tjmVal != null) {
        attributes['contractAverageDailyCost'] = tjmVal;
        attributes['contractAverageDailyProductionCost'] = tjmVal;
        attributes['averageDailyCost'] = tjmVal;
        attributes['averageDailyPrice'] = tjmVal;
      }

      // BoondManager exige la relation "dependsOn" pointant vers la ressource parente
      final Map<String, dynamic> relationships = {
        'dependsOn': {
          'data': {'type': 'resource', 'id': resId}
        },
        'resource': {
          'data': {'type': 'resource', 'id': resId}
        },
      };

      final payload = {
        'data': {
          'type': 'contracts',
          'attributes': attributes,
          'relationships': relationships,
        }
      };

      _lastRequestPayload = const JsonEncoder.withIndent('  ').convert(payload);
      _addLog("Envoi de la requête POST /contracts...");

      final response = await service.createContract(payload);
      
      _lastResponsePayload = const JsonEncoder.withIndent('  ').convert(response.data);
      _lastResponseHeaders = response.headers.toString();

      final createdContractId = response.data['data']?['id'];
      _addLog("SUCCÈS : Contrat créé avec l'ID $createdContractId pour la ressource ID $resId !");

      // Recharger les contrats de la ressource
      final updatedRawContracts = await service.getContractsForResource(resId);
      final updatedDetailedContracts = <Map<String, dynamic>>[];
      for (final c in updatedRawContracts) {
        final cId = c['id']?.toString();
        if (cId != null && cId.isNotEmpty) {
          try {
            final cDetailResp = await service.getRaw('contracts/$cId');
            final cData = cDetailResp.data?['data'] as Map<String, dynamic>?;
            if (cData != null) {
              updatedDetailedContracts.add(cData);
              continue;
            }
          } catch (_) {}
        }
        updatedDetailedContracts.add(Map<String, dynamic>.from(c));
      }

      setState(() {
        _existingContracts = updatedDetailedContracts;
        _isActionInProgress = false;
        // Réinitialiser les champs optionnels
        _endDateController.clear();
        _tjmController.clear();
      });

      if (!mounted) return;
      ShadToaster.of(context).show(
        const ShadToast(
          title: Text("Contrat créé avec succès"),
          description: Text("Le nouveau contrat a été enregistré et rattaché à la ressource."),
          backgroundColor: Colors.teal,
        ),
      );
    } on DioException catch (e) {
      final errResponse = e.response;
      _lastResponseHeaders = errResponse?.headers.toString() ?? "";
      if (errResponse != null) {
        _lastResponsePayload = const JsonEncoder.withIndent('  ').convert(errResponse.data);
        _addLog("ERREUR API (${errResponse.statusCode}) : ${errResponse.data}");
      } else {
        _lastResponsePayload = "";
        _addLog("ERREUR Réseau : ${e.message}");
      }

      setState(() {
        _isActionInProgress = false;
        _errorMsg = "Une erreur s'est produite lors de la création du contrat.";
      });
    } catch (e) {
      _addLog("ERREUR Inattendue : $e");
      setState(() {
        _isActionInProgress = false;
        _errorMsg = e.toString();
      });
    }
  }

  String _resolveContractTypeLabel(dynamic typeId) {
    if (typeId == null) return "Non spécifié";
    final match = _contractTypes.firstWhere(
      (t) => t['id'].toString() == typeId.toString(),
      orElse: () => {'label': 'Type #$typeId'},
    );
    return match['label'].toString();
  }

  String? _extractContractRate(Map<String, dynamic> cAttrs) {
    final tjm = cAttrs['contractAverageDailyCost'] ?? 
                cAttrs['contractAverageDailyProductionCost'] ?? 
                cAttrs['averageDailyCost'] ?? 
                cAttrs['averageDailyCostProduction'] ?? 
                cAttrs['averageDailyPrice'] ?? 
                cAttrs['tjm'] ?? 
                cAttrs['cjm'] ?? 
                cAttrs['cost'];
    if (tjm != null && tjm.toString().isNotEmpty && tjm.toString() != '0' && tjm.toString() != '0.00' && tjm.toString() != '0.0') {
      return "TJM : $tjm €";
    }
    
    final salary = cAttrs['monthlyGrossSalary'] ?? cAttrs['salary'];
    if (salary != null && salary.toString().isNotEmpty && salary.toString() != '0' && salary.toString() != '0.00' && salary.toString() != '0.0') {
      return "Salaire : $salary €/mois";
    }
    
    final hourly = cAttrs['hourlyGrossSalary'];
    if (hourly != null && hourly.toString().isNotEmpty && hourly.toString() != '0' && hourly.toString() != '0.00' && hourly.toString() != '0.0') {
      return "Taux : $hourly €/h";
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(VivSpacing.radiusLg),
      child: Container(
        width: 1000,
        height: 800,
        padding: const EdgeInsets.all(VivSpacing.space6),
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: VivSpacing.space4),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Volet Gestion des Contrats (Gauche)
                  Expanded(
                    flex: 11,
                    child: _isLoadingMetadata 
                        ? const Center(child: CircularProgressIndicator(color: VivColors.lime))
                        : _buildMainContent(),
                  ),
                  const VerticalDivider(width: 32, indent: 8, endIndent: 8),
                  // Volet Diagnostic/Logs (Droite)
                  Expanded(
                    flex: 9,
                    child: _buildDiagnosticPanel(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: VivSpacing.space4),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Test Pipeline : Gestion des contrats", style: VivTypography.h4.copyWith(fontSize: 18)),
            const SizedBox(height: 4),
            Text(
              "Consultez les contrats existants d'une ressource (lecture seule) et créez de nouveaux contrats RH.",
              style: VivTypography.small.copyWith(color: VivColors.gray500, fontSize: 12),
            ),
          ],
        ),
        ShadButton.ghost(
          padding: EdgeInsets.zero,
          width: 28,
          height: 28,
          onPressed: widget.onClose,
          child: const Icon(LucideIcons.x, size: 18),
        ),
      ],
    );
  }

  Widget _buildMainContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildResourceSelector(),
          const SizedBox(height: 16),
          if (_selectedResource != null) ...[
            _buildSelectedResourceCard(),
            const SizedBox(height: 16),
            _buildContractsListSection(),
            const SizedBox(height: 20),
            _buildNewContractSection(),
          ],
        ],
      ),
    );
  }

  Widget _buildResourceSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("SÉLECTION DE LA RESSOURCE", style: VivTypography.eyebrow.copyWith(fontSize: 10, color: VivColors.gray500)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ShadInput(
                controller: _resourceSearchController,
                placeholder: const Text("Rechercher par nom, prénom ou référence (ex: COMP3, DOE...)", style: TextStyle(fontSize: 12, color: VivColors.gray400)),
                onSubmitted: (val) => _searchAndLoadResource(val),
              ),
            ),
            const SizedBox(width: 8),
            ShadButton(
              backgroundColor: VivColors.lime,
              onPressed: _isActionInProgress 
                  ? null 
                  : () => _searchAndLoadResource(_resourceSearchController.text),
              child: _isActionInProgress
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: VivColors.black))
                  : const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.search, size: 14, color: VivColors.black),
                        SizedBox(width: 4),
                        Text("Rechercher", style: TextStyle(fontWeight: FontWeight.bold, color: VivColors.black, fontSize: 12)),
                      ],
                    ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSelectedResourceCard() {
    final attrs = _selectedResource!['attributes'] as Map<String, dynamic>? ?? {};
    final fullName = "${attrs['firstName'] ?? ''} ${attrs['lastName'] ?? ''}".trim();
    final resId = _selectedResource!['id'];
    final reference = attrs['reference']?.toString() ?? '';
    final function = attrs['function']?.toString() ?? attrs['title']?.toString() ?? 'Ressource';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: VivColors.offWhite,
        border: Border.all(color: VivColors.gray200),
        borderRadius: BorderRadius.circular(VivSpacing.radiusMd),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: VivColors.lime.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: const Icon(LucideIcons.user, size: 18, color: VivColors.black),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 2),
                Text(
                  "ID: $resId  •  Réf: ${reference.isNotEmpty ? reference : 'N/A'}  •  $function",
                  style: const TextStyle(fontSize: 11, color: VivColors.gray500),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.teal[50],
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.teal[200]!),
            ),
            child: Text(
              "${_existingContracts.length} contrat(s)",
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.teal[800]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContractsListSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("HISTORIQUE DES CONTRATS (LECTURE SEULE)", style: VivTypography.eyebrow.copyWith(fontSize: 10, color: VivColors.gray500)),
            const Row(
              children: [
                Icon(LucideIcons.lock, size: 12, color: VivColors.gray400),
                SizedBox(width: 4),
                Text("Modification via avenant uniquement", style: TextStyle(fontSize: 10, color: VivColors.gray500, fontStyle: FontStyle.italic)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_existingContracts.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.amber[50],
              border: Border.all(color: Colors.amber[200]!),
              borderRadius: BorderRadius.circular(VivSpacing.radiusMd),
            ),
            child: Row(
              children: [
                Icon(LucideIcons.info, size: 16, color: Colors.amber[800]),
                const SizedBox(width: 8),
                Text(
                  "Aucun contrat enregistré pour cette ressource.",
                  style: TextStyle(fontSize: 12, color: Colors.amber[900]),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _existingContracts.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final contract = _existingContracts[index];
              final cAttrs = contract['attributes'] as Map<String, dynamic>? ?? contract;
              final cId = contract['id'] ?? '#${index + 1}';
              final typeId = cAttrs['typeOf'] ?? cAttrs['type'];
              final typeLabel = _resolveContractTypeLabel(typeId);
              final startDate = cAttrs['startDate'] ?? 'N/A';
              final endDate = cAttrs['endDate'] ?? 'Indéterminée';
              final rateLabel = _extractContractRate(cAttrs);

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: VivColors.gray200),
                  borderRadius: BorderRadius.circular(VivSpacing.radiusMd),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Text(
                        typeLabel,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue[900]),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Contrat ID $cId", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          const SizedBox(height: 2),
                          Text("Début : $startDate  •  Fin : $endDate", style: const TextStyle(fontSize: 11, color: VivColors.gray500)),
                        ],
                      ),
                    ),
                    if (rateLabel != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: VivColors.offWhite,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: VivColors.gray300),
                        ),
                        child: Text(
                          rateLabel,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: VivColors.black),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildNewContractSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.teal[50]!.withValues(alpha: 0.5),
        border: Border.all(color: Colors.teal[200]!),
        borderRadius: BorderRadius.circular(VivSpacing.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.circlePlus, size: 16, color: Colors.teal[800]),
              const SizedBox(width: 8),
              Text("CRÉER UN NOUVEAU CONTRAT", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.teal[900])),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 6,
                child: _buildDropdownField(
                  label: "Type de contrat *",
                  value: _selectedContractType,
                  options: _contractTypes,
                  onChanged: (v) => setState(() => _selectedContractType = v),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 6,
                child: _buildTextField("Tarif journalier TJM (€)", _tjmController, "ex: 450.00"),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 6,
                child: _buildTextField("Date de début *", _startDateController, "AAAA-MM-JJ (ex: 2026-08-31)"),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 6,
                child: _buildTextField("Date de fin (Optionnelle)", _endDateController, "AAAA-MM-JJ (ex: 2027-08-31)"),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: ShadButton(
              backgroundColor: VivColors.lime,
              onPressed: _isActionInProgress ? null : _processCreateContract,
              child: _isActionInProgress
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: VivColors.black))
                  : const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.filePlus, size: 16, color: VivColors.black),
                        SizedBox(width: 6),
                        Text("Créer le Contrat", style: TextStyle(fontWeight: FontWeight.bold, color: VivColors.black)),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, String placeholder) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: VivColors.black)),
        const SizedBox(height: 4),
        ShadInput(
          controller: controller,
          placeholder: Text(placeholder, style: const TextStyle(fontSize: 12, color: VivColors.gray400)),
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String? value,
    required List<Map<String, dynamic>> options,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: VivColors.black)),
        const SizedBox(height: 4),
        SizedBox(
          width: double.infinity,
          child: ShadSelect<String>(
            initialValue: value,
            placeholder: const Text("Choisir...", style: TextStyle(fontSize: 12, color: VivColors.gray400)),
            options: options.map((opt) => ShadOption(
              value: opt['id'].toString(),
              child: Text((opt['label'] ?? opt['name'] ?? opt['id'] ?? '').toString(), style: const TextStyle(fontSize: 12)),
            )).toList(),
            selectedOptionBuilder: (context, val) {
              final selected = options.firstWhere((o) => o['id'].toString() == val, orElse: () => {'label': val});
              return Text((selected['label'] ?? selected['name'] ?? val).toString(), style: const TextStyle(fontSize: 12));
            },
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildDiagnosticPanel() {
    return DefaultTabController(
      length: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TabBar(
            labelColor: VivColors.black,
            unselectedLabelColor: VivColors.gray400,
            indicatorColor: VivColors.lime,
            labelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
            tabs: const [
              Tab(text: "Logs Diagnostic"),
              Tab(text: "Payload Envoyé"),
              Tab(text: "Réponse API"),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: TabBarView(
              children: [
                _buildLogTab(),
                _buildCodeTab(_lastRequestPayload, "Aucun payload envoyé pour le moment."),
                _buildCodeTab(
                  _lastResponsePayload.isNotEmpty 
                      ? "HEADERS:\n$_lastResponseHeaders\n\nBODY:\n$_lastResponsePayload" 
                      : "", 
                  "Aucune réponse API reçue pour le moment."
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ShadButton.outline(
              size: ShadButtonSize.sm,
              onPressed: _logs.isEmpty ? null : () {
                Clipboard.setData(ClipboardData(text: _logs.join('\n')));
                ShadToaster.of(context).show(
                  const ShadToast(
                    title: Text("Logs copiés !"),
                    description: Text("Les logs ont été placés dans le presse-papiers."),
                    backgroundColor: Colors.teal,
                  ),
                );
              },
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.copy, size: 14),
                  SizedBox(width: 4),
                  Text("Copier", style: TextStyle(fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: VivColors.offWhite,
              borderRadius: BorderRadius.circular(VivSpacing.radiusMd),
            ),
            padding: const EdgeInsets.all(8),
            child: ListView.builder(
              itemCount: _logs.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: SelectableText(
                    _logs[index],
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.black87),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCodeTab(String content, String placeholder) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ShadButton.outline(
              size: ShadButtonSize.sm,
              onPressed: content.isEmpty ? null : () {
                Clipboard.setData(ClipboardData(text: content));
                ShadToaster.of(context).show(
                  const ShadToast(
                    title: Text("Copié !"),
                    description: Text("Le contenu a été placé dans le presse-papiers."),
                    backgroundColor: Colors.teal,
                  ),
                );
              },
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.copy, size: 14),
                  SizedBox(width: 4),
                  Text("Copier", style: TextStyle(fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: VivColors.offWhite,
              borderRadius: BorderRadius.circular(VivSpacing.radiusMd),
            ),
            padding: const EdgeInsets.all(8),
            child: content.isEmpty
                ? Center(child: Text(placeholder, style: const TextStyle(fontSize: 12, color: VivColors.gray400)))
                : SingleChildScrollView(
                    child: SelectableText(
                      content,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 9, color: Colors.black87),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (_errorMsg.isNotEmpty)
          Expanded(
            child: Text(
              _errorMsg,
              style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          )
        else
          const Spacer(),
        ShadButton.outline(
          onPressed: widget.onClose,
          child: const Text("Fermer"),
        ),
      ],
    );
  }
}
