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

class CreateContactToolWidget extends ConsumerStatefulWidget {
  final VoidCallback onClose;
  const CreateContactToolWidget({super.key, required this.onClose});

  @override
  ConsumerState<CreateContactToolWidget> createState() => _CreateContactToolWidgetState();
}

class _CreateContactToolWidgetState extends ConsumerState<CreateContactToolWidget> {
  // Indicateurs d'état
  bool _isLoadingMetadata = true;
  bool _isActionInProgress = false;
  String _errorMsg = "";

  // Dictionnaires et listes chargés depuis l'API
  List<Map<String, dynamic>> _civilities = [];
  List<Map<String, dynamic>> _contactStates = [];
  List<Map<String, dynamic>> _contactTypes = [];
  List<Map<String, dynamic>> _companies = [];
  List<Map<String, dynamic>> _agencies = [];
  List<Map<String, dynamic>> _poles = [];
  List<Map<String, dynamic>> _users = [];

  // Données saisies dans le formulaire
  String? _selectedCivility;
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  String? _selectedCompanyId;

  final _functionController = TextEditingController();
  String? _selectedState;
  String? _selectedType;
  String? _selectedManager;
  String? _selectedAgency;
  String? _selectedPole;

  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
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
      // 1. Dictionnaire d'application pour civilités, états et types de contact
      final dict = await service.getDictionary();
      final settings = dict['data']?['setting'] as Map<String, dynamic>? ?? {};

      // Civilités
      final civList = settings['civility'] as List? ?? [];
      _civilities = civList.map<Map<String, dynamic>>((e) => {
        'id': e['id']?.toString() ?? '',
        'label': (e['value'] ?? e['label'] ?? e['name'] ?? '').toString()
      }).toList();

      // États de contact
      final stateList = (settings['state']?['contact'] ?? 
                         settings['state']?['contacts'] ?? 
                         settings['typeOf']?['contact']) as List? ?? [];
      _contactStates = stateList.map<Map<String, dynamic>>((e) => {
        'id': e['id']?.toString() ?? '',
        'label': (e['value'] ?? e['label'] ?? e['name'] ?? '').toString()
      }).toList();

      // Types de contact (optionnel)
      final typeList = (settings['typeOf']?['contact'] ?? 
                        settings['typeOf']?['contacts'] ?? 
                        settings['type']?['contact'] ?? 
                        settings['types']?['contact'] ?? 
                        settings['contactType']) as List? ?? [];
      _contactTypes = typeList.map<Map<String, dynamic>>((e) => {
        'id': e['id']?.toString() ?? '',
        'label': (e['value'] ?? e['label'] ?? e['name'] ?? '').toString()
      }).toList();

      // 2. Sociétés existantes
      try {
        final companiesRaw = await service.searchCompanies('');
        _companies = companiesRaw.map<Map<String, dynamic>>((c) {
          final attrs = c['attributes'] as Map<String, dynamic>? ?? {};
          return {
            'id': c['id']?.toString() ?? '',
            'label': (attrs['name'] ?? "Société #${c['id']}").toString(),
          };
        }).toList();
        _addLog("Sociétés chargées avec succès (${_companies.length} trouvées).");
      } catch (e) {
        _addLog("Erreur lors de la récupération des sociétés: $e");
      }

      // 3. Agences
      try {
        _agencies = await service.getAgencies();
        _addLog("Agences récupérées avec succès (${_agencies.length} trouvées).");
      } catch (e) {
        _addLog("Erreur lors de la récupération des agences: $e");
      }

      // 4. Utilisateurs/Managers
      try {
        _users = await service.getUsers(forceRefresh: true);
        _addLog("Utilisateurs/Managers récupérés avec succès (${_users.length} trouvés).");
      } catch (e) {
        _addLog("Erreur lors de la récupération des utilisateurs/managers: $e");
      }

      // 5. Pôles
      try {
        _poles = await service.getPoles();
        _addLog("Pôles récupérés avec succès (${_poles.length} trouvés).");
      } catch (e) {
        _addLog("Remarque: Impossible de charger les pôles : $e");
      }

      // Présélectionner l'état Fournisseur par défaut si disponible
      if (_contactStates.isNotEmpty) {
        final fournisseurState = _contactStates.firstWhere(
          (s) {
            final l = s['label'].toString().toLowerCase();
            return l.contains('fournisseur') || l.contains('provider');
          },
          orElse: () => _contactStates.first,
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
    _firstNameController.clear();
    _lastNameController.clear();
    _selectedCivility = null;
    _selectedCompanyId = null;
    _functionController.clear();
    _selectedType = null;
    _selectedManager = null;
    _selectedAgency = null;
    _selectedPole = null;
    _emailController.clear();
    _phoneController.clear();
    _addressController.clear();
    _postcodeController.clear();
    _townController.clear();
    _countryController.text = "France";

    if (_contactStates.isNotEmpty) {
      final fournisseurState = _contactStates.firstWhere(
        (s) {
          final l = s['label'].toString().toLowerCase();
          return l.contains('fournisseur') || l.contains('provider');
        },
        orElse: () => _contactStates.first,
      );
      _selectedState = fournisseurState['id'];
    }
  }

  String _formatFirstName(String val) {
    val = val.trim();
    if (val.isEmpty) return "";
    
    final pattern = RegExp(r'([-\s])');
    final parts = val.split(pattern);
    final matches = pattern.allMatches(val).toList();
    
    final formattedParts = parts.map((part) {
      if (part.isEmpty) return "";
      return part[0].toUpperCase() + part.substring(1).toLowerCase();
    }).toList();
    
    final sb = StringBuffer();
    for (int i = 0; i < formattedParts.length; i++) {
      sb.write(formattedParts[i]);
      if (i < matches.length) {
        sb.write(matches[i].group(0));
      }
    }
    return sb.toString();
  }

  String _extractFirstNonEmpty(List<dynamic> values) {
    for (final v in values) {
      if (v != null && v.toString().trim().isNotEmpty) {
        return v.toString().trim();
      }
    }
    return '';
  }

  String? _extractContactType(dynamic val) {
    if (val == null) return null;
    if (val is List && val.isNotEmpty) {
      return val.first.toString();
    }
    if (val is String && val.trim().isNotEmpty) {
      if (val.contains('|')) {
        return val.split('|').first.trim();
      }
      return val.trim();
    }
    if (val is int) {
      return val.toString();
    }
    return null;
  }

  // Vérifie l'existence d'un contact dans BoondManager (Étape 1)
  Future<void> _checkExistence() async {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();

    if (firstName.isEmpty || lastName.isEmpty) {
      ShadToaster.of(context).show(
        const ShadToast(
          title: Text("Champs requis"),
          description: Text("Veuillez renseigner le nom et le prénom du contact."),
          backgroundColor: Colors.amber,
        ),
      );
      return;
    }

    if (_selectedCompanyId == null || _selectedCompanyId!.isEmpty) {
      ShadToaster.of(context).show(
        const ShadToast(
          title: Text("Société requise"),
          description: Text("Veuillez sélectionner la société de rattachement du contact."),
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
    _addLog("Vérification de l'existence pour '$firstName $lastName'...");

    try {
      // Recherche globale ou filtrée par société
      final List<dynamic> duplicateCandidates = await service.searchContacts(
        "$firstName $lastName",
        companyId: _selectedCompanyId,
      );

      if (duplicateCandidates.isNotEmpty) {
        // Recherche de correspondance exacte
        final match = duplicateCandidates.firstWhere(
          (c) {
            final attrs = c['attributes'] as Map<String, dynamic>? ?? {};
            final cLastName = (attrs['lastName'] ?? '').toString().toLowerCase().trim();
            final cFirstName = (attrs['firstName'] ?? '').toString().toLowerCase().trim();
            return cLastName == lastName.toLowerCase() && cFirstName == firstName.toLowerCase();
          },
          orElse: () => duplicateCandidates.first,
        );

        final cId = match['id'].toString();
        _addLog("CONTACT EXISTANT TROUVÉ (ID $cId). Récupération complète...");

        Map<String, dynamic> contactAttrs = {};
        Map<String, dynamic> contactRels = {};
        try {
          final response = await service.getRaw('contacts/$cId');
          final cData = response.data as Map<String, dynamic>? ?? {};
          final contactObj = cData['data'] as Map<String, dynamic>? ?? {};
          contactAttrs = contactObj['attributes'] as Map<String, dynamic>? ?? {};
          contactRels = contactObj['relationships'] as Map<String, dynamic>? ?? {};
        } catch (e) {
          _addLog("Erreur lors de la récupération racine : $e");
        }

        Map<String, dynamic> infoAttrs = {};
        try {
          final infoResp = await service.getRaw('contacts/$cId/information');
          final infoData = infoResp.data as Map<String, dynamic>? ?? {};
          final infoObj = infoData['data'] as Map<String, dynamic>? ?? {};
          infoAttrs = infoObj['attributes'] as Map<String, dynamic>? ?? {};
        } catch (e) {
          _addLog("Erreur lors de la récupération d'information : $e");
        }

        _addLog("DÉTAILS - Root attributes : $contactAttrs");
        _addLog("DÉTAILS - Root relationships : $contactRels");
        _addLog("DÉTAILS - Info attributes : $infoAttrs");

        setState(() {
          _detectedDuplicate = match;
          
          // Reprendre la casse exacte de la fiche existante
          _firstNameController.text = _extractFirstNonEmpty([
            infoAttrs['firstName'],
            contactAttrs['firstName'],
            match['attributes']?['firstName'],
            firstName,
          ]);

          _lastNameController.text = _extractFirstNonEmpty([
            infoAttrs['lastName'],
            contactAttrs['lastName'],
            match['attributes']?['lastName'],
            lastName,
          ]);

          _selectedCivility = infoAttrs['civility']?.toString() ?? contactAttrs['civility']?.toString() ?? match['attributes']?['civility']?.toString();

          _functionController.text = _extractFirstNonEmpty([
            infoAttrs['function'],
            infoAttrs['title'],
            contactAttrs['function'],
            contactAttrs['title'],
            match['attributes']?['function'],
            match['attributes']?['title'],
          ]);

          _selectedState = infoAttrs['state']?.toString() ?? contactAttrs['state']?.toString() ?? match['attributes']?['state']?.toString();
          _selectedType = _extractContactType(infoAttrs['typesOf']) ??
              _extractContactType(infoAttrs['types']) ??
              _extractContactType(infoAttrs['typeOf']) ??
              _extractContactType(infoAttrs['type']) ??
              _extractContactType(contactAttrs['typesOf']) ??
              _extractContactType(contactAttrs['types']) ??
              _extractContactType(contactAttrs['typeOf']) ??
              _extractContactType(contactAttrs['type']) ??
              _extractContactType(match['attributes']?['typesOf']) ??
              _extractContactType(match['attributes']?['types']) ??
              _extractContactType(match['attributes']?['typeOf']);

          _emailController.text = _extractFirstNonEmpty([
            infoAttrs['email1'],
            infoAttrs['email'],
            contactAttrs['email1'],
            contactAttrs['email'],
            match['attributes']?['email1'],
            match['attributes']?['email'],
          ]);

          _phoneController.text = _extractFirstNonEmpty([
            infoAttrs['phone1'],
            infoAttrs['phone'],
            contactAttrs['phone1'],
            contactAttrs['phone'],
            match['attributes']?['phone1'],
            match['attributes']?['phone'],
          ]);

          _addressController.text = _extractFirstNonEmpty([
            infoAttrs['address'],
            contactAttrs['address'],
            match['attributes']?['address'],
          ]);

          _postcodeController.text = _extractFirstNonEmpty([
            infoAttrs['postcode'],
            contactAttrs['postcode'],
            match['attributes']?['postcode'],
          ]);

          _townController.text = _extractFirstNonEmpty([
            infoAttrs['town'],
            contactAttrs['town'],
            match['attributes']?['town'],
          ]);

          _countryController.text = _extractFirstNonEmpty([
            infoAttrs['country'],
            contactAttrs['country'],
            match['attributes']?['country'],
            'France',
          ]);

          // Relations
          final companyData = contactRels['company']?['data'] ?? match['relationships']?['company']?['data'];
          if (companyData?['id'] != null) {
            _selectedCompanyId = companyData['id'].toString();
          }

          final agencyData = contactRels['agency']?['data'] ?? match['relationships']?['agency']?['data'];
          _selectedAgency = agencyData?['id']?.toString();

          final poleData = contactRels['pole']?['data'] ?? match['relationships']?['pole']?['data'];
          _selectedPole = poleData?['id']?.toString();

          final managerData = contactRels['mainManager']?['data'] ?? match['relationships']?['mainManager']?['data'];
          _selectedManager = managerData?['id']?.toString();

          _hasVerified = true;
          _isActionInProgress = false;
        });

        if (!mounted) return;
        ShadToaster.of(context).show(
          const ShadToast(
            title: Text("Contact trouvé"),
            description: Text("Les informations du contact existant ont été pré-remplies."),
            backgroundColor: Colors.amber,
          ),
        );
      } else {
        _addLog("Aucun contact trouvé avec ce nom pour cette société. Formulaire de création vierge ouvert.");
        setState(() {
          _detectedDuplicate = null;
          // Formatage obligatoire : Prénom et NOM
          _firstNameController.text = _formatFirstName(firstName);
          _lastNameController.text = lastName.toUpperCase();
          
          _hasVerified = true;
          _isActionInProgress = false;
        });

        if (!mounted) return;
        ShadToaster.of(context).show(
          const ShadToast(
            title: Text("Nouveau contact"),
            description: Text("Vous pouvez remplir le formulaire pour créer ce contact."),
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

  // Crée un nouveau contact (Étape 2.2)
  Future<void> _processCreate() async {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();

    if (firstName.isEmpty || lastName.isEmpty || _selectedCompanyId == null) {
      ShadToaster.of(context).show(
        const ShadToast(
          title: Text("Champs requis"),
          description: Text("Le nom, prénom et la société de rattachement sont obligatoires."),
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
    _addLog("Création d'un nouveau contact...");

    try {
      final Map<String, dynamic> attributes = {
        'lastName': lastName,
        'firstName': firstName,
        if (_selectedCivility != null) 'civility': int.tryParse(_selectedCivility!),
        'function': _functionController.text.trim(),
        'title': _functionController.text.trim(),
        if (_selectedState != null) 'state': int.tryParse(_selectedState!),
        'email': _emailController.text.trim(),
        'email1': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'phone1': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'postcode': _postcodeController.text.trim(),
        'town': _townController.text.trim(),
        'country': _countryController.text.trim(),
      };

      if (_selectedType != null && _selectedType!.isNotEmpty) {
        final parsedTypeId = int.tryParse(_selectedType!);
        if (parsedTypeId != null) {
          attributes['typesOf'] = [parsedTypeId];
          attributes['types'] = [parsedTypeId];
          attributes['typeOf'] = parsedTypeId;
          attributes['type'] = parsedTypeId;
        } else {
          attributes['typesOf'] = [_selectedType!];
          attributes['types'] = [_selectedType!];
          attributes['typeOf'] = _selectedType!;
        }
      } else {
        attributes['typesOf'] = [];
        attributes['types'] = [];
      }

      final Map<String, dynamic> relationships = {
        'company': {
          'data': {'type': 'company', 'id': _selectedCompanyId}
        },
      };

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
          'type': 'contacts',
          'attributes': attributes,
          'relationships': relationships,
        }
      };

      _lastRequestPayload = const JsonEncoder.withIndent('  ').convert(payload);
      _addLog("Envoi de la requête POST /contacts...");

      final response = await service.createContact(payload);
      
      _lastResponsePayload = const JsonEncoder.withIndent('  ').convert(response.data);
      _lastResponseHeaders = response.headers.toString();

      final createdId = response.data['data']?['id'];
      _addLog("SUCCÈS : Contact créé avec l'ID $createdId");
      
      setState(() {
        _isActionInProgress = false;
      });

      if (!mounted) return;
      ShadToaster.of(context).show(
        const ShadToast(
          title: Text("Contact créé"),
          description: Text("Le contact a été créé avec succès dans BoondManager."),
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

  // Met à jour un contact existant (Étape 2.1)
  Future<void> _processUpdate() async {
    if (_detectedDuplicate == null) return;
    
    final id = _detectedDuplicate!['id'].toString();
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();

    setState(() {
      _isActionInProgress = true;
      _errorMsg = "";
    });

    final service = ref.read(boondServiceProvider);
    _addLog("Mise à jour demandée pour le contact ID $id...");

    try {
      final Map<String, dynamic> attributes = {
        'lastName': lastName,
        'firstName': firstName,
        if (_selectedCivility != null) 'civility': int.tryParse(_selectedCivility!),
        'function': _functionController.text.trim(),
        'title': _functionController.text.trim(),
        if (_selectedState != null) 'state': int.tryParse(_selectedState!),
        'email': _emailController.text.trim(),
        'email1': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'phone1': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'postcode': _postcodeController.text.trim(),
        'town': _townController.text.trim(),
        'country': _countryController.text.trim(),
      };

      if (_selectedType != null && _selectedType!.isNotEmpty) {
        final parsedTypeId = int.tryParse(_selectedType!);
        if (parsedTypeId != null) {
          attributes['typesOf'] = [parsedTypeId];
          attributes['types'] = [parsedTypeId];
          attributes['typeOf'] = parsedTypeId;
          attributes['type'] = parsedTypeId;
        } else {
          attributes['typesOf'] = [_selectedType!];
          attributes['types'] = [_selectedType!];
          attributes['typeOf'] = _selectedType!;
        }
      } else {
        attributes['typesOf'] = [];
        attributes['types'] = [];
      }

      final Map<String, dynamic> relationships = {};
      if (_selectedCompanyId != null) {
        relationships['company'] = {
          'data': {'type': 'company', 'id': _selectedCompanyId}
        };
      }
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
          'type': 'contacts',
          'id': id,
          'attributes': attributes,
          if (relationships.isNotEmpty) 'relationships': relationships,
        }
      };

      _lastRequestPayload = "--- PAYLOAD UPDATE (PUT /contacts/$id/information) ---\n"
          "${const JsonEncoder.withIndent('  ').convert(payload)}";

      _addLog("Envoi de la mise à jour vers PUT /contacts/$id/information...");
      final response = await service.updateContactInformation(id, payload);
      
      _lastResponsePayload = "--- RÉPONSE UPDATE ---\n${const JsonEncoder.withIndent('  ').convert(response.data)}";
      _lastResponseHeaders = response.headers.toString();

      _addLog("SUCCÈS : Contact ID $id mis à jour avec succès !");

      setState(() {
        _isActionInProgress = false;
      });

      if (!mounted) return;
      ShadToaster.of(context).show(
        const ShadToast(
          title: Text("Contact mis à jour"),
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
            Text("Test Pipeline : Créer un contact", style: VivTypography.h4.copyWith(fontSize: 18)),
            const SizedBox(height: 4),
            Text(
              "Permet de valider l'existence ou la création de contacts rattachés à une société dans BoondManager.",
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
    final title = isDuplicate ? "Fiche Existante Détectée (Mode Mise à Jour)" : "Nouveau Contact (Mode Création)";
    final description = isDuplicate 
        ? "Un contact correspondant a été trouvé dans BoondManager (ID ${_detectedDuplicate!['id']}). Les champs ont été pré-remplis avec ses données actuelles. Vous pouvez les modifier puis cliquer sur 'Mettre à jour'." 
        : "Aucun contact portant ce nom n'a été trouvé pour cette société. Remplissez le formulaire ci-dessous pour créer ce contact.";
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
          
          Text("IDENTITÉ DU CONTACT & SOCIÉTÉ", style: VivTypography.eyebrow.copyWith(fontSize: 10, color: VivColors.gray500)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: _buildDropdownField(
                  label: "Civilité",
                  value: _selectedCivility,
                  options: _civilities,
                  onChanged: (v) => setState(() => _selectedCivility = v),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 5,
                child: _buildTextField("Prénom *", _firstNameController, "ex: Marie"),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 5,
                child: _buildTextField("Nom *", _lastNameController, "ex: Dupont"),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildDropdownField(
                  label: "Société de rattachement *",
                  value: _selectedCompanyId,
                  options: _companies,
                  onChanged: (v) => setState(() => _selectedCompanyId = v),
                ),
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
                      "Renseignez la civilité, le prénom, le nom et la société de rattachement ci-dessus, puis lancez la vérification d'existence pour continuer.",
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
                  flex: 6,
                  child: _buildTextField("Fonction / Titre", _functionController, "ex: Responsable Achats"),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 6,
                  child: _buildDropdownField(
                    label: "Type de contact (Optionnel)",
                    value: _selectedType,
                    options: _contactTypes,
                    onChanged: (v) => setState(() => _selectedType = v),
                  ),
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
                    label: "État du contact *",
                    value: _selectedState,
                    options: _contactStates,
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
                  child: _buildTextField("Email", _emailController, "ex: contact@societe.com"),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField("Téléphone", _phoneController, "ex: 0123456789"),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildTextField("Adresse", _addressController, "ex: 10 rue de la Paix"),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: _buildTextField("Code postal", _postcodeController, "ex: 75001"),
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
                  : const Text("Mettre à jour le Contact", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            )
          else
            ShadButton(
              backgroundColor: VivColors.lime,
              onPressed: _isActionInProgress ? null : _processCreate,
              child: _isActionInProgress
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text("Créer le Contact", style: TextStyle(fontWeight: FontWeight.bold, color: VivColors.black)),
            ),
        ],
      ],
    );
  }
}
