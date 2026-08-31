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

class CreateCompanyToolWidget extends ConsumerStatefulWidget {
  final VoidCallback onClose;
  const CreateCompanyToolWidget({super.key, required this.onClose});

  @override
  ConsumerState<CreateCompanyToolWidget> createState() => _CreateCompanyToolWidgetState();
}

class _CreateCompanyToolWidgetState extends ConsumerState<CreateCompanyToolWidget> {
  // Indicateurs d'état
  bool _isLoadingMetadata = true;
  bool _isActionInProgress = false;
  String _errorMsg = "";

  // Dictionnaires et listes chargés depuis l'API
  List<Map<String, dynamic>> _companyStates = [];
  List<Map<String, dynamic>> _agencies = [];
  List<Map<String, dynamic>> _poles = [];
  List<Map<String, dynamic>> _users = [];

  // Données saisies dans le formulaire
  final _nameController = TextEditingController();
  final _sirenController = TextEditingController();
  final _vatController = TextEditingController();
  final _legalStatusController = TextEditingController();
  final _apeController = TextEditingController();
  final _providerNumberController = TextEditingController();

  String? _selectedState;
  String? _selectedAgency;
  String? _selectedPole;
  String? _selectedManager;

  final _addressController = TextEditingController();
  final _postcodeController = TextEditingController();
  final _townController = TextEditingController();
  final _countryController = TextEditingController(text: "France");

  // Données de diagnostic de l'API
  final List<String> _logs = [];
  String _lastRequestPayload = "";
  String _lastResponsePayload = "";
  String _lastResponseHeaders = "";
  Map<String, dynamic>? _detectedDuplicate;
  bool _hasVerified = false;

  @override
  void initState() {
    super.initState();
    _loadMetadata();
  }

  Future<void> _loadMetadata() async {
    setState(() {
      _isLoadingMetadata = true;
      _errorMsg = "";
      _addLog("Chargement des référentiels BoondManager...");
    });

    final service = ref.read(boondServiceProvider);

    try {
      // 1. Dictionnaire d'application pour les états de société
      final dict = await service.getDictionary();
      final settings = dict['data']?['setting'] as Map<String, dynamic>? ?? {};

      final companyStateList = (settings['state']?['company'] ?? 
                                settings['state']?['companies'] ?? 
                                settings['typeOf']?['company'] ?? 
                                settings['typeOf']?['companies']) as List? ?? [];
      _companyStates = companyStateList.map<Map<String, dynamic>>((e) => {
        'id': e['id']?.toString() ?? '',
        'label': (e['value'] ?? e['label'] ?? e['name'] ?? '').toString()
      }).toList();

      // 2. Agences
      try {
        _agencies = await service.getAgencies();
        _addLog("Agences récupérées avec succès (${_agencies.length} trouvées).");
      } catch (e) {
        _addLog("Erreur lors de la récupération des agences: $e");
      }

      // 3. Utilisateurs/Managers
      try {
        _users = await service.getUsers(forceRefresh: true);
        _addLog("Utilisateurs/Managers récupérés avec succès (${_users.length} trouvés).");
      } catch (e) {
        _addLog("Erreur lors de la récupération des utilisateurs/managers: $e");
      }

      // 4. Pôles
      try {
        _poles = await service.getPoles();
        _addLog("Pôles récupérés avec succès (${_poles.length} trouvés).");
      } catch (e) {
        _addLog("Remarque: Impossible de charger les pôles : $e");
      }

      // Pré-sélectionner l'état Fournisseur par défaut si disponible
      if (_companyStates.isNotEmpty) {
        final fournisseurState = _companyStates.firstWhere(
          (s) {
            final l = s['label'].toString().toLowerCase();
            return l.contains('fournisseur') || l.contains('provider');
          },
          orElse: () => _companyStates.first,
        );
        _selectedState = fournisseurState['id'];
      }

      setState(() {
        _isLoadingMetadata = false;
      });
      _addLog("Référentiels chargés avec succès.");
    } catch (e) {
      setState(() {
        _isLoadingMetadata = false;
        _errorMsg = "Erreur de chargement des métadonnées : $e";
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

  void _clearForm() {
    _nameController.clear();
    _sirenController.clear();
    _vatController.clear();
    _legalStatusController.clear();
    _apeController.clear();
    _providerNumberController.clear();
    _selectedAgency = null;
    _selectedPole = null;
    _selectedManager = null;
    _addressController.clear();
    _postcodeController.clear();
    _townController.clear();
    _countryController.text = "France";
    
    if (_companyStates.isNotEmpty) {
      final fournisseurState = _companyStates.firstWhere(
        (s) {
          final l = s['label'].toString().toLowerCase();
          return l.contains('fournisseur') || l.contains('provider');
        },
        orElse: () => _companyStates.first,
      );
      _selectedState = fournisseurState['id'];
    }
  }

  // Vérifie l'existence d'une société dans BoondManager (Étape 1)
  Future<void> _checkExistence() async {
    final name = _nameController.text.trim();
    final siren = _sirenController.text.trim();

    if (name.isEmpty && siren.isEmpty) {
      ShadToaster.of(context).show(
        const ShadToast(
          title: Text("Champ requis"),
          description: Text("Veuillez renseigner au moins le nom de la société ou le SIRET."),
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
    final searchKeyword = siren.isNotEmpty ? siren : name;
    _addLog("Vérification de l'existence pour '$searchKeyword'...");

    try {
      final List<dynamic> duplicateCandidates = await service.searchCompanies(searchKeyword);

      if (duplicateCandidates.isNotEmpty) {
        // Recherche de correspondance (par SIRET ou par nom insensible à la casse)
        final match = duplicateCandidates.firstWhere(
          (c) {
            final attrs = c['attributes'] as Map<String, dynamic>? ?? {};
            final cName = (attrs['name'] ?? '').toString().toLowerCase().trim();
            final cSiren = (attrs['registrationNumber'] ?? attrs['siren'] ?? '').toString().trim();
            
            if (siren.isNotEmpty && cSiren.isNotEmpty && cSiren == siren) {
              return true;
            }
            if (name.isNotEmpty && cName == name.toLowerCase()) {
              return true;
            }
            return false;
          },
          orElse: () => duplicateCandidates.first,
        );

        final cId = match['id'].toString();
        _addLog("SOCIÉTÉ EXISTANTE TROUVÉE (ID $cId). Récupération complète...");

        Map<String, dynamic> companyAttrs = {};
        Map<String, dynamic> companyRels = {};
        try {
          final response = await service.getRaw('companies/$cId');
          final cData = response.data as Map<String, dynamic>? ?? {};
          final companyObj = cData['data'] as Map<String, dynamic>? ?? {};
          companyAttrs = companyObj['attributes'] as Map<String, dynamic>? ?? {};
          companyRels = companyObj['relationships'] as Map<String, dynamic>? ?? {};
        } catch (e) {
          _addLog("Erreur lors de la récupération racine : $e");
        }

        Map<String, dynamic> infoAttrs = {};
        try {
          final infoResp = await service.getRaw('companies/$cId/information');
          final infoData = infoResp.data as Map<String, dynamic>? ?? {};
          final infoObj = infoData['data'] as Map<String, dynamic>? ?? {};
          infoAttrs = infoObj['attributes'] as Map<String, dynamic>? ?? {};
        } catch (e) {
          _addLog("Erreur lors de la récupération d'information : $e");
        }

        _addLog("DÉTAILS - Root attributes : $companyAttrs");
        _addLog("DÉTAILS - Root relationships : $companyRels");
        _addLog("DÉTAILS - Info attributes : $infoAttrs");

        setState(() {
          _detectedDuplicate = match;
          
          // Reprendre la casse exacte de la fiche existante de BoondManager
          _nameController.text = _extractFirstNonEmpty([
            infoAttrs['name'],
            companyAttrs['name'],
            match['attributes']?['name'],
            name,
          ]);

          _legalStatusController.text = _extractFirstNonEmpty([
            infoAttrs['legalStatus'],
            companyAttrs['legalStatus'],
            match['attributes']?['legalStatus'],
          ]);

          _sirenController.text = _extractFirstNonEmpty([
            infoAttrs['registrationNumber'],
            infoAttrs['siren'],
            companyAttrs['registrationNumber'],
            companyAttrs['siren'],
            match['attributes']?['registrationNumber'],
            match['attributes']?['siren'],
            siren,
          ]);

          _vatController.text = _extractFirstNonEmpty([
            infoAttrs['vatNumber'],
            infoAttrs['vat'],
            companyAttrs['vatNumber'],
            companyAttrs['vat'],
            match['attributes']?['vatNumber'],
            match['attributes']?['vat'],
          ]);

          _apeController.text = _extractFirstNonEmpty([
            infoAttrs['apeCode'],
            infoAttrs['ape'],
            companyAttrs['apeCode'],
            companyAttrs['ape'],
            match['attributes']?['apeCode'],
            match['attributes']?['ape'],
          ]);

          _providerNumberController.text = _extractFirstNonEmpty([
            infoAttrs['number'],
            infoAttrs['providerNumber'],
            infoAttrs['reference'],
            companyAttrs['number'],
            companyAttrs['providerNumber'],
            companyAttrs['reference'],
            match['attributes']?['number'],
            match['attributes']?['providerNumber'],
            match['attributes']?['reference'],
          ]);

          // État
          _selectedState = infoAttrs['state']?.toString() ?? companyAttrs['state']?.toString() ?? match['attributes']?['state']?.toString();

          // Localisation
          _addressController.text = _extractFirstNonEmpty([
            infoAttrs['address'],
            companyAttrs['address'],
            match['attributes']?['address'],
          ]);

          _postcodeController.text = _extractFirstNonEmpty([
            infoAttrs['postcode'],
            companyAttrs['postcode'],
            match['attributes']?['postcode'],
          ]);

          _townController.text = _extractFirstNonEmpty([
            infoAttrs['town'],
            companyAttrs['town'],
            match['attributes']?['town'],
          ]);

          _countryController.text = _extractFirstNonEmpty([
            infoAttrs['country'],
            companyAttrs['country'],
            match['attributes']?['country'],
            'France',
          ]);

          // Relations (depuis la racine, avec fallback sur match)
          final agencyData = companyRels['agency']?['data'] ?? match['relationships']?['agency']?['data'];
          _selectedAgency = agencyData?['id']?.toString();

          final poleData = companyRels['pole']?['data'] ?? match['relationships']?['pole']?['data'];
          _selectedPole = poleData?['id']?.toString();

          final managerData = companyRels['mainManager']?['data'] ?? match['relationships']?['mainManager']?['data'];
          _selectedManager = managerData?['id']?.toString();

          _hasVerified = true;
          _isActionInProgress = false;
        });

        if (!mounted) return;
        ShadToaster.of(context).show(
          const ShadToast(
            title: Text("Société trouvée"),
            description: Text("Les informations existantes ont été pré-remplies."),
            backgroundColor: Colors.amber,
          ),
        );
      } else {
        _addLog("Aucune société trouvée avec ce nom/SIRET. Formulaire de création vierge ouvert.");
        setState(() {
          _detectedDuplicate = null;
          // Formatage obligatoire en majuscules pour une nouvelle société
          _nameController.text = name.toUpperCase();
          _sirenController.text = siren;
          
          _hasVerified = true;
          _isActionInProgress = false;
        });

        if (!mounted) return;
        ShadToaster.of(context).show(
          const ShadToast(
            title: Text("Nouvelle société"),
            description: Text("Vous pouvez remplir le formulaire pour créer cette société."),
            backgroundColor: Colors.teal,
          ),
        );
      }
    } catch (e) {
      _addLog("ERREUR lors de la vérification : $e");
      setState(() {
        _isActionInProgress = false;
        _errorMsg = "Erreur lors de la vérification : $e";
      });
    }
  }

  String _extractFirstNonEmpty(List<dynamic> values) {
    for (final v in values) {
      if (v != null && v.toString().trim().isNotEmpty) {
        return v.toString().trim();
      }
    }
    return '';
  }

  // Crée une nouvelle société (Étape 2.2)
  Future<void> _processCreate() async {
    final name = _nameController.text.trim().toUpperCase();

    if (name.isEmpty) {
      ShadToaster.of(context).show(
        const ShadToast(
          title: Text("Champ requis"),
          description: Text("Le nom de la société est obligatoire."),
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
    _addLog("Création d'une nouvelle société...");

    try {
      final Map<String, dynamic> attributes = {
        'name': name,
        if (_selectedState != null) 'state': int.tryParse(_selectedState!),
        'legalStatus': _legalStatusController.text.trim(),
        'siren': _sirenController.text.trim(),
        'registrationNumber': _sirenController.text.trim(),
        'vat': _vatController.text.trim(),
        'vatNumber': _vatController.text.trim(),
        'ape': _apeController.text.trim(),
        'apeCode': _apeController.text.trim(),
        'providerNumber': _providerNumberController.text.trim(),
        'number': _providerNumberController.text.trim(),
        'address': _addressController.text.trim(),
        'postcode': _postcodeController.text.trim(),
        'town': _townController.text.trim(),
        'country': _countryController.text.trim(),
      };

      final Map<String, dynamic> relationships = {};
      if (_selectedAgency != null) {
        relationships['agency'] = {
          'data': {'type': 'agency', 'id': _selectedAgency}
        };
      }
      if (_selectedPole != null) {
        relationships['pole'] = {
          'data': {'type': 'pole', 'id': _selectedPole}
        };
      }
      if (_selectedManager != null) {
        relationships['mainManager'] = {
          'data': {'type': 'resource', 'id': _selectedManager}
        };
      }

      final payload = {
        'data': {
          'type': 'companies',
          'attributes': attributes,
          if (relationships.isNotEmpty) 'relationships': relationships,
        }
      };

      _lastRequestPayload = const JsonEncoder.withIndent('  ').convert(payload);
      _addLog("Envoi de la requête POST /companies...");

      final response = await service.createCompany(payload);
      
      _lastResponsePayload = const JsonEncoder.withIndent('  ').convert(response.data);
      _lastResponseHeaders = response.headers.toString();

      final createdId = response.data['data']?['id'];
      _addLog("SUCCÈS : Société créée avec l'ID $createdId");
      
      setState(() {
        _isActionInProgress = false;
      });

      if (!mounted) return;
      ShadToaster.of(context).show(
        const ShadToast(
          title: Text("Société créée"),
          description: Text("La société a été créée avec succès dans BoondManager."),
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
        _errorMsg = "Une erreur s'est produite lors de la création.";
      });
    } catch (e) {
      _addLog("ERREUR Inattendue : $e");
      setState(() {
        _isActionInProgress = false;
        _errorMsg = e.toString();
      });
    }
  }

  // Met à jour une société existante (Étape 2.1)
  Future<void> _processUpdate() async {
    if (_detectedDuplicate == null) return;
    
    final id = _detectedDuplicate!['id'].toString();
    final name = _nameController.text.trim();

    setState(() {
      _isActionInProgress = true;
      _errorMsg = "";
    });

    final service = ref.read(boondServiceProvider);
    _addLog("Mise à jour demandée pour la société ID $id...");

    try {
      final Map<String, dynamic> attributes = {
        'name': name,
        if (_selectedState != null) 'state': int.tryParse(_selectedState!),
        'legalStatus': _legalStatusController.text.trim(),
        'siren': _sirenController.text.trim(),
        'registrationNumber': _sirenController.text.trim(),
        'vat': _vatController.text.trim(),
        'vatNumber': _vatController.text.trim(),
        'ape': _apeController.text.trim(),
        'apeCode': _apeController.text.trim(),
        'providerNumber': _providerNumberController.text.trim(),
        'number': _providerNumberController.text.trim(),
        'address': _addressController.text.trim(),
        'postcode': _postcodeController.text.trim(),
        'town': _townController.text.trim(),
        'country': _countryController.text.trim(),
      };

      final Map<String, dynamic> relationships = {};
      if (_selectedAgency != null) {
        relationships['agency'] = {
          'data': {'type': 'agency', 'id': _selectedAgency}
        };
      }
      if (_selectedPole != null) {
        relationships['pole'] = {
          'data': {'type': 'pole', 'id': _selectedPole}
        };
      }
      if (_selectedManager != null) {
        relationships['mainManager'] = {
          'data': {'type': 'resource', 'id': _selectedManager}
        };
      }

      final payload = {
        'data': {
          'type': 'companies',
          'id': id,
          'attributes': attributes,
          if (relationships.isNotEmpty) 'relationships': relationships,
        }
      };

      _lastRequestPayload = "--- PAYLOAD UPDATE (PUT /companies/$id/information) ---\n"
          "${const JsonEncoder.withIndent('  ').convert(payload)}";

      _addLog("Envoi de la mise à jour vers PUT /companies/$id/information...");
      final response = await service.updateCompanyInformation(id, payload);
      
      _lastResponsePayload = "--- RÉPONSE UPDATE ---\n${const JsonEncoder.withIndent('  ').convert(response.data)}";
      _lastResponseHeaders = response.headers.toString();

      _addLog("SUCCÈS : Société ID $id mise à jour avec succès !");

      setState(() {
        _isActionInProgress = false;
      });

      if (!mounted) return;
      ShadToaster.of(context).show(
        const ShadToast(
          title: Text("Société mise à jour"),
          description: Text("Les modifications ont bien été enregistrées dans BoondManager."),
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
        _errorMsg = "Une erreur s'est produite lors de la mise à jour.";
      });
    } catch (e) {
      _addLog("ERREUR Inattendue : $e");
      setState(() {
        _isActionInProgress = false;
        _errorMsg = e.toString();
      });
    }
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
                  // Section Formulaire (Gauche)
                  Expanded(
                    flex: 11,
                    child: _isLoadingMetadata 
                        ? const Center(child: CircularProgressIndicator(color: VivColors.lime))
                        : _buildForm(),
                  ),
                  const VerticalDivider(width: 32, indent: 8, endIndent: 8),
                  // Section Diagnostic/Logs (Droite)
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
            Text("Test Pipeline : Créer une société", style: VivTypography.h4.copyWith(fontSize: 18)),
            const SizedBox(height: 4),
            Text(
              "Permet de valider l'existence ou la création de sociétés BoondManager.",
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

  Widget _buildStatusBanner() {
    final isDuplicate = _detectedDuplicate != null;
    final title = isDuplicate ? "Fiche Existante Détectée (Mode Mise à Jour)" : "Nouvelle Société (Mode Création)";
    final description = isDuplicate 
        ? "Une société correspondante a été trouvée dans BoondManager (ID ${_detectedDuplicate!['id']}). Les champs ont été pré-remplis avec ses données actuelles. Vous pouvez les modifier puis cliquer sur 'Mettre à jour'." 
        : "Aucun doublon trouvé dans votre base BoondManager. Le nom a été formaté en majuscules. Complétez les informations pour créer la société.";
    final bgColor = isDuplicate ? Colors.amber[50]! : Colors.teal[50]!;
    final borderColor = isDuplicate ? Colors.amber[300]! : Colors.teal[300]!;
    final iconColor = isDuplicate ? Colors.amber[800]! : Colors.teal[800]!;
    final icon = isDuplicate ? LucideIcons.shieldAlert : LucideIcons.check;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(VivSpacing.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: iconColor)),
                const SizedBox(height: 4),
                Text(description, style: const TextStyle(fontSize: 11, color: Colors.black87)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_hasVerified) _buildStatusBanner(),
          
          Text("IDENTITÉ & LÉGAL", style: VivTypography.eyebrow.copyWith(fontSize: 10, color: VivColors.gray500)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 6,
                child: _buildTextField("Nom de la société *", _nameController, "ex: ACME CORP"),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 4,
                child: _buildTextField("SIRET / SIREN", _sirenController, "ex: 12345678900012"),
              ),
            ],
          ),
          
          if (!_hasVerified) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: VivColors.offWhite,
                borderRadius: BorderRadius.circular(VivSpacing.radiusMd),
              ),
              child: const Row(
                children: [
                  Icon(LucideIcons.info, size: 16, color: VivColors.gray500),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Renseignez le nom de la société (et éventuellement son SIRET) ci-dessus, puis lancez la vérification d'existence pour continuer.",
                      style: TextStyle(fontSize: 12, color: VivColors.gray500),
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          if (_hasVerified) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 4,
                  child: _buildTextField("Statut juridique", _legalStatusController, "ex: SAS, SARL, SA..."),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 4,
                  child: _buildTextField("TVA Intracommunautaire", _vatController, "ex: FR12345678901"),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: _buildTextField("Code APE", _apeController, "ex: 6201Z"),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildTextField("Numéro fournisseur", _providerNumberController, "ex: FOURN-0012"),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text("ORGANISATION & ÉTAT", style: VivTypography.eyebrow.copyWith(fontSize: 10, color: VivColors.gray500)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildDropdownField(
                    label: "État de la société *",
                    value: _selectedState,
                    options: _companyStates,
                    onChanged: (v) => setState(() => _selectedState = v),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDropdownField(
                    label: "Responsable manager",
                    value: _selectedManager,
                    options: _users,
                    onChanged: (v) => setState(() => _selectedManager = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildDropdownField(
                    label: "Agence *",
                    value: _selectedAgency,
                    options: _agencies.map((a) => {'id': a['id'], 'label': a['name']}).toList(),
                    onChanged: (v) => setState(() => _selectedAgency = v),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDropdownField(
                    label: "Pôle (Optionnel)",
                    value: _selectedPole,
                    options: _poles.map((p) => {'id': p['id'], 'label': p['name']}).toList(),
                    onChanged: (v) => setState(() => _selectedPole = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text("COORDONNÉES & LOCALISATION", style: VivTypography.eyebrow.copyWith(fontSize: 10, color: VivColors.gray500)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildTextField("Adresse", _addressController, "ex: 12 avenue des Champs-Élysées"),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: _buildTextField("Code postal", _postcodeController, "ex: 75008"),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 5,
                  child: _buildTextField("Ville", _townController, "ex: Paris"),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 5,
                  child: _buildTextField("Pays", _countryController, "ex: France"),
                ),
              ],
            ),
          ],
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
            placeholder: Text("Choisir...", style: TextStyle(fontSize: 12, color: VivColors.gray400)),
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
                // Logs
                _buildLogTab(),
                // Request Payload
                _buildCodeTab(_lastRequestPayload, "Aucun payload envoyé pour le moment."),
                // Response Payload
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
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Les logs ont été copiés dans le presse-papiers.")),
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
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Le contenu a été copié dans le presse-papiers.")),
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
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (_errorMsg.isNotEmpty)
          Expanded(
            child: Text(
              _errorMsg,
              style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        const Spacer(),
        if (!_hasVerified) ...[
          ShadButton.outline(
            onPressed: widget.onClose,
            child: const Text("Annuler"),
          ),
          const SizedBox(width: 8),
          ShadButton(
            backgroundColor: VivColors.lime,
            onPressed: _isActionInProgress || _isLoadingMetadata 
                ? null 
                : _checkExistence,
            child: _isActionInProgress
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text("Vérifier l'existence", style: TextStyle(fontWeight: FontWeight.bold, color: VivColors.black)),
          ),
        ] else ...[
          ShadButton.outline(
            onPressed: _isActionInProgress 
                ? null 
                : () {
                    setState(() {
                      _hasVerified = false;
                      _detectedDuplicate = null;
                      _clearForm();
                    });
                  },
            child: const Text("Retour"),
          ),
          const SizedBox(width: 8),
          if (_detectedDuplicate != null)
            ShadButton(
              backgroundColor: Colors.amber[800]!,
              onPressed: _isActionInProgress ? null : _processUpdate,
              child: _isActionInProgress
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text("Mettre à jour la Société", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            )
          else
            ShadButton(
              backgroundColor: VivColors.lime,
              onPressed: _isActionInProgress ? null : _processCreate,
              child: _isActionInProgress
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text("Créer la Société", style: TextStyle(fontWeight: FontWeight.bold, color: VivColors.black)),
            ),
        ],
      ],
    );
  }
}
