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

class CreateResourceToolWidget extends ConsumerStatefulWidget {
  final VoidCallback onClose;
  const CreateResourceToolWidget({super.key, required this.onClose});

  @override
  ConsumerState<CreateResourceToolWidget> createState() => _CreateResourceToolWidgetState();
}

class _CreateResourceToolWidgetState extends ConsumerState<CreateResourceToolWidget> {
  // Indicateurs d'état
  bool _isLoadingMetadata = true;
  bool _isActionInProgress = false;
  String _errorMsg = "";

  // Dictionnaires et listes chargés depuis l'API
  List<Map<String, dynamic>> _civilities = [];
  List<Map<String, dynamic>> _resourceTypes = [];
  List<Map<String, dynamic>> _resourceStates = [];
  List<Map<String, dynamic>> _agencies = [];
  List<Map<String, dynamic>> _poles = [];
  List<Map<String, dynamic>> _users = [];

  // Données saisies dans le formulaire
  String? _selectedCivility;
  final _lastNameController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _functionController = TextEditingController();
  String? _selectedType;
  String? _selectedState;
  String? _selectedAgency;
  String? _selectedPole;
  String? _selectedManager;
  String? _selectedHrManager;
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
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
      // 1. Dictionnaire d'application
      final dict = await service.getDictionary();
      final settings = dict['data']?['setting'] as Map<String, dynamic>? ?? {};

      // Civilités
      final civList = settings['civility'] as List? ?? [];
      _civilities = civList.map<Map<String, dynamic>>((e) => {
        'id': e['id']?.toString() ?? '',
        'label': (e['value'] ?? e['label'] ?? e['name'] ?? '').toString()
      }).toList();

      // Types de ressource
      final typeList = settings['typeOf']?['resource'] as List? ?? [];
      _resourceTypes = typeList.map<Map<String, dynamic>>((e) => {
        'id': e['id']?.toString() ?? '',
        'label': (e['value'] ?? e['label'] ?? e['name'] ?? '').toString()
      }).toList();

      // États de ressource
      final stateList = settings['state']?['resource'] as List? ?? [];
      _resourceStates = stateList.map<Map<String, dynamic>>((e) => {
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
        _addLog("Remarque: Impossible de charger les pôles (peut-être absents de la sandbox) : $e");
      }

      // Pré-remplir les valeurs par défaut
      if (_resourceStates.isNotEmpty) {
        // Sélectionner l'état "En cours" par défaut si disponible
        final enCoursState = _resourceStates.firstWhere(
          (s) => s['label'].toString().toLowerCase().contains('en cours'),
          orElse: () => _resourceStates.first,
        );
        _selectedState = enCoursState['id'];
      }

      if (_resourceTypes.isNotEmpty) {
        // Interne par défaut (généralement ID 0)
        final internal = _resourceTypes.firstWhere(
          (t) => t['id'] == '0',
          orElse: () => _resourceTypes.first,
        );
        _selectedType = internal['id'];
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
      _addLog("ÉCHEC du chargement des référentiels: $e");
    }
  }

  void _addLog(String message) {
    final timestamp = DateTime.now().toLocal().toString().split(' ').last.substring(0, 8);
    setState(() {
      _logs.add("[$timestamp] $message");
    });
  }

  // Effectue la vérification des doublons (Étape 1)
  Future<void> _checkExistence() async {
    final lastName = _lastNameController.text.trim();
    final firstName = _firstNameController.text.trim();

    if (lastName.isEmpty || firstName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Le nom et le prénom sont obligatoires.")),
      );
      return;
    }

    setState(() {
      _isActionInProgress = true;
      _detectedDuplicate = null;
      _errorMsg = "";
    });

    final service = ref.read(boondServiceProvider);
    _addLog("Vérification de l'existence pour '$firstName $lastName'...");

    try {
      final List<dynamic> duplicateCandidates = await service.searchResources("$firstName $lastName");

      if (duplicateCandidates.isNotEmpty) {
        // Recherche de correspondance exacte (Nom et Prénom insensibles à la casse)
        final match = duplicateCandidates.firstWhere(
          (c) {
            final attrs = c['attributes'] as Map<String, dynamic>? ?? {};
            final cLastName = (attrs['lastName'] ?? '').toString().toLowerCase().trim();
            final cFirstName = (attrs['firstName'] ?? '').toString().toLowerCase().trim();
            return cLastName == lastName.toLowerCase() && cFirstName == firstName.toLowerCase();
          },
          orElse: () => duplicateCandidates.first,
        );

        final rId = match['id'].toString();
        _addLog("RESSOURCE EXISTANTE TROUVÉE (ID $rId). Récupération complète...");

        Map<String, dynamic> resourceAttrs = {};
        Map<String, dynamic> resourceRels = {};
        try {
          final response = await service.getRaw('resources/$rId');
          final rData = response.data as Map<String, dynamic>? ?? {};
          final resourceObj = rData['data'] as Map<String, dynamic>? ?? {};
          resourceAttrs = resourceObj['attributes'] as Map<String, dynamic>? ?? {};
          resourceRels = resourceObj['relationships'] as Map<String, dynamic>? ?? {};
        } catch (e) {
          _addLog("Erreur lors de la récupération racine : $e");
        }

        Map<String, dynamic> infoAttrs = {};
        try {
          final infoResp = await service.getRaw('resources/$rId/information');
          final infoData = infoResp.data as Map<String, dynamic>? ?? {};
          final infoObj = infoData['data'] as Map<String, dynamic>? ?? {};
          infoAttrs = infoObj['attributes'] as Map<String, dynamic>? ?? {};
        } catch (e) {
          _addLog("Erreur lors de la récupération d'information : $e");
        }

        Map<String, dynamic> adminAttrs = {};
        try {
          final adminResp = await service.getRaw('resources/$rId/administrative');
          final adminData = adminResp.data as Map<String, dynamic>? ?? {};
          final adminObj = adminData['data'] as Map<String, dynamic>? ?? {};
          adminAttrs = adminObj['attributes'] as Map<String, dynamic>? ?? {};
        } catch (e) {
          _addLog("Erreur lors de la récupération administrative : $e");
        }

        _addLog("DÉTAILS - Root attributes : $resourceAttrs");
        _addLog("DÉTAILS - Root relationships : $resourceRels");
        _addLog("DÉTAILS - Info attributes : $infoAttrs");
        _addLog("DÉTAILS - Admin attributes : $adminAttrs");

        setState(() {
          _detectedDuplicate = match;
          
          // Reprendre la casse exacte de la fiche existante de BoondManager
          _firstNameController.text = infoAttrs['firstName']?.toString() ?? resourceAttrs['firstName']?.toString() ?? match['attributes']?['firstName']?.toString() ?? firstName;
          _lastNameController.text = infoAttrs['lastName']?.toString() ?? resourceAttrs['lastName']?.toString() ?? match['attributes']?['lastName']?.toString() ?? lastName;
          
          _selectedCivility = infoAttrs['civility']?.toString() ?? resourceAttrs['civility']?.toString() ?? match['attributes']?['civility']?.toString();
          
          // Titre professionnel avec gestion des chaînes vides
          String title = '';
          if (infoAttrs['function'] != null && infoAttrs['function'].toString().isNotEmpty) {
            title = infoAttrs['function'].toString();
          } else if (infoAttrs['title'] != null && infoAttrs['title'].toString().isNotEmpty) {
            title = infoAttrs['title'].toString();
          } else if (adminAttrs['function'] != null && adminAttrs['function'].toString().isNotEmpty) {
            title = adminAttrs['function'].toString();
          } else if (resourceAttrs['title'] != null && resourceAttrs['title'].toString().isNotEmpty) {
            title = resourceAttrs['title'].toString();
          } else if (resourceAttrs['function'] != null && resourceAttrs['function'].toString().isNotEmpty) {
            title = resourceAttrs['function'].toString();
          } else {
            final matchAttrs = match['attributes'] as Map<String, dynamic>? ?? {};
            title = matchAttrs['title']?.toString() ?? matchAttrs['function']?.toString() ?? '';
          }
          _functionController.text = title;
          
          // Type de ressource
          _selectedType = infoAttrs['typeOf']?.toString() ?? adminAttrs['typeOf']?.toString() ?? resourceAttrs['typeOf']?.toString() ?? match['attributes']?['typeOf']?.toString();
          
          // État
          _selectedState = adminAttrs['state']?.toString() ?? resourceAttrs['state']?.toString() ?? match['attributes']?['state']?.toString();
          
          // Email avec gestion des chaînes vides
          String emailVal = '';
          if (infoAttrs['email1'] != null && infoAttrs['email1'].toString().isNotEmpty) {
            emailVal = infoAttrs['email1'].toString();
          } else if (infoAttrs['email'] != null && infoAttrs['email'].toString().isNotEmpty) {
            emailVal = infoAttrs['email'].toString();
          } else if (resourceAttrs['email1'] != null && resourceAttrs['email1'].toString().isNotEmpty) {
            emailVal = resourceAttrs['email1'].toString();
          } else {
            final matchAttrs = match['attributes'] as Map<String, dynamic>? ?? {};
            emailVal = matchAttrs['email1']?.toString() ?? matchAttrs['email']?.toString() ?? '';
          }
          _emailController.text = emailVal;
          
          // Téléphone avec gestion des chaînes vides
          String phoneVal = '';
          if (infoAttrs['phone1'] != null && infoAttrs['phone1'].toString().isNotEmpty) {
            phoneVal = infoAttrs['phone1'].toString();
          } else if (infoAttrs['phone'] != null && infoAttrs['phone'].toString().isNotEmpty) {
            phoneVal = infoAttrs['phone'].toString();
          } else if (resourceAttrs['phone1'] != null && resourceAttrs['phone1'].toString().isNotEmpty) {
            phoneVal = resourceAttrs['phone1'].toString();
          } else {
            final matchAttrs = match['attributes'] as Map<String, dynamic>? ?? {};
            phoneVal = matchAttrs['phone1']?.toString() ?? matchAttrs['phone']?.toString() ?? '';
          }
          _phoneController.text = phoneVal;
          
          // Localisation
          _postcodeController.text = infoAttrs['postcode']?.toString() ?? resourceAttrs['postcode']?.toString() ?? match['attributes']?['postcode']?.toString() ?? '';
          _townController.text = infoAttrs['town']?.toString() ?? resourceAttrs['town']?.toString() ?? match['attributes']?['town']?.toString() ?? '';
          _countryController.text = infoAttrs['country']?.toString() ?? resourceAttrs['country']?.toString() ?? match['attributes']?['country']?.toString() ?? 'France';

          // Relations (depuis la racine, avec fallback sur match)
          final agencyData = resourceRels['agency']?['data'] ?? match['relationships']?['agency']?['data'];
          _selectedAgency = agencyData?['id']?.toString();

          final poleData = resourceRels['pole']?['data'] ?? match['relationships']?['pole']?['data'];
          _selectedPole = poleData?['id']?.toString();

          final managerData = resourceRels['mainManager']?['data'] ?? match['relationships']?['mainManager']?['data'];
          _selectedManager = managerData?['id']?.toString();

          final hrManagerData = resourceRels['hrManager']?['data'] ?? match['relationships']?['hrManager']?['data'];
          _selectedHrManager = hrManagerData?['id']?.toString();

          _hasVerified = true;
          _isActionInProgress = false;
        });

        if (!mounted) return;
        ShadToaster.of(context).show(
          const ShadToast(
            title: Text("Ressource trouvée"),
            description: Text("Les informations de la fiche existante ont été pré-remplies."),
            backgroundColor: Colors.amber,
          ),
        );
      } else {
        _addLog("Aucune ressource trouvée avec ce nom. Formulaire de création vierge ouvert.");
        setState(() {
          _detectedDuplicate = null;
          // Appliquer le formatage de casse précis : Prénom et NOM
          _firstNameController.text = _formatFirstName(firstName);
          _lastNameController.text = lastName.toUpperCase();
          
          _hasVerified = true;
          _isActionInProgress = false;
        });

        if (!mounted) return;
        ShadToaster.of(context).show(
          const ShadToast(
            title: Text("Ressource non trouvée"),
            description: Text("Vous pouvez remplir le formulaire pour créer une nouvelle ressource."),
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

  // Formate un prénom composé ou simple en capitalisant le début de chaque partie (ex: Jean-Marc)
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

  // Crée une nouvelle ressource (Étape 2.2)
  Future<void> _processCreate() async {
    final lastName = _lastNameController.text.trim();
    final firstName = _firstNameController.text.trim();
    final email = _emailController.text.trim();

    if (lastName.isEmpty || firstName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Le nom et le prénom sont obligatoires.")),
      );
      return;
    }

    setState(() {
      _isActionInProgress = true;
      _errorMsg = "";
    });

    final service = ref.read(boondServiceProvider);
    _addLog("Création d'une nouvelle ressource...");

    try {
      final Map<String, dynamic> attributes = {
        'lastName': lastName,
        'firstName': firstName,
        'civility': _selectedCivility != null ? int.tryParse(_selectedCivility!) : null,
        'function': _functionController.text.trim(),
        'title': _functionController.text.trim(),
        'typeOf': _selectedType != null ? int.tryParse(_selectedType!) : null,
        'state': _selectedState != null ? int.tryParse(_selectedState!) : null,
        'email1': email,
        'phone1': _phoneController.text.trim(),
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
      if (_selectedHrManager != null) {
        relationships['hrManager'] = {
          'data': {'type': 'resource', 'id': _selectedHrManager}
        };
      }

      final payload = {
        'data': {
          'type': 'resources',
          'attributes': attributes,
          if (relationships.isNotEmpty) 'relationships': relationships,
        }
      };

      _lastRequestPayload = const JsonEncoder.withIndent('  ').convert(payload);
      _addLog("Envoi de la requête POST /resources...");

      final response = await service.createResource(payload);
      
      _lastResponsePayload = const JsonEncoder.withIndent('  ').convert(response.data);
      _lastResponseHeaders = response.headers.toString();

      _addLog("SUCCÈS : Ressource créée avec l'ID ${response.data['data']?['id']}");
      
      setState(() {
        _isActionInProgress = false;
        _hasVerified = false;
        _detectedDuplicate = null;
        _clearForm();
      });

      if (!mounted) return;
      ShadToaster.of(context).show(
        const ShadToast(
          title: Text("Ressource créée"),
          description: Text("La ressource a été créée avec succès."),
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

  // Met à jour une ressource existante (Étape 2.1)
  Future<void> _processUpdate() async {
    if (_detectedDuplicate == null) return;
    
    final id = _detectedDuplicate!['id'].toString();
    final lastName = _lastNameController.text.trim();
    final firstName = _firstNameController.text.trim();

    setState(() {
      _isActionInProgress = true;
      _errorMsg = "";
    });

    final service = ref.read(boondServiceProvider);
    _addLog("Mise à jour demandée pour la ressource ID $id...");

    try {
      // 1. Préparation des attributs d'information
      final Map<String, dynamic> infoAttributes = {
        'lastName': lastName,
        'firstName': firstName,
        'civility': _selectedCivility != null ? int.tryParse(_selectedCivility!) : null,
        'function': _functionController.text.trim(),
        'title': _functionController.text.trim(),
        'email1': _emailController.text.trim(),
        'phone1': _phoneController.text.trim(),
        'postcode': _postcodeController.text.trim(),
        'town': _townController.text.trim(),
        'country': _countryController.text.trim(),
      };
      if (_selectedType != null) {
        infoAttributes['typeOf'] = int.tryParse(_selectedType!);
      }
      if (_selectedState != null) {
        infoAttributes['state'] = int.tryParse(_selectedState!);
      }

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
      if (_selectedHrManager != null) {
        relationships['hrManager'] = {
          'data': {'type': 'resource', 'id': _selectedHrManager}
        };
      }

      final infoPayload = {
        'data': {
          'type': 'resources',
          'id': id,
          'attributes': infoAttributes,
          if (relationships.isNotEmpty) 'relationships': relationships,
        }
      };

      // 2. Préparation des attributs et relations administratives
      final Map<String, dynamic> adminAttributes = {
        'function': _functionController.text.trim(),
        'title': _functionController.text.trim(),
      };
      if (_selectedState != null) {
        adminAttributes['state'] = int.tryParse(_selectedState!);
      }

      final adminPayload = {
        'data': {
          'type': 'resources',
          'id': id,
          'attributes': adminAttributes,
          if (relationships.isNotEmpty) 'relationships': relationships,
        }
      };

      _lastRequestPayload = "--- PAYLOAD INFO (PUT /resources/$id/information) ---\n"
          "${const JsonEncoder.withIndent('  ').convert(infoPayload)}\n\n"
          "--- PAYLOAD ADMIN (PUT /resources/$id/administrative) ---\n"
          "${const JsonEncoder.withIndent('  ').convert(adminPayload)}";

      _addLog("Envoi de la mise à jour des informations personnelles...");
      final responseInfo = await service.updateResourceInformation(id, infoPayload);
      
      _addLog("Envoi de la mise à jour des données administratives et relations...");
      final responseAdmin = await service.updateResourceAdministrative(id, adminPayload);
      
      _lastResponseHeaders = "INFO HEADERS:\n${responseInfo.headers}\n\nADMIN HEADERS:\n${responseAdmin.headers}";
      _lastResponsePayload = "--- RÉPONSE INFO ---\n"
          "${const JsonEncoder.withIndent('  ').convert(responseInfo.data)}\n\n"
          "--- RÉPONSE ADMIN ---\n"
          "${const JsonEncoder.withIndent('  ').convert(responseAdmin.data)}";

      _addLog("SUCCÈS : Ressource ID $id entièrement mise à jour.");
      
      setState(() {
        _isActionInProgress = false;
        _hasVerified = false;
        _detectedDuplicate = null;
        _clearForm();
      });

      if (!mounted) return;
      ShadToaster.of(context).show(
        const ShadToast(
          title: Text("Ressource mise à jour"),
          description: Text("Les informations et les relations ont été enregistrées avec succès."),
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

  // Réinitialise tout le formulaire
  void _clearForm() {
    _lastNameController.clear();
    _firstNameController.clear();
    _functionController.clear();
    _emailController.clear();
    _phoneController.clear();
    _postcodeController.clear();
    _townController.clear();
    _countryController.text = "France";
    _selectedCivility = null;
    _selectedType = null;
    if (_resourceStates.isNotEmpty) {
      final enCoursState = _resourceStates.firstWhere(
        (s) => s['label'].toString().toLowerCase().contains('en cours'),
        orElse: () => _resourceStates.first,
      );
      _selectedState = enCoursState['id'];
    } else {
      _selectedState = null;
    }
    _selectedAgency = null;
    _selectedPole = null;
    _selectedManager = null;
    _selectedHrManager = null;
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
            Text("Test Pipeline : Créer une ressource", style: VivTypography.h4.copyWith(fontSize: 18)),
            const SizedBox(height: 4),
            Text(
              "Permet de valider l'existence ou la création de ressources BoondManager.",
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
    final title = isDuplicate ? "Fiche Existante Détectée (Mode Mise à Jour)" : "Nouvelle Ressource (Mode Création)";
    final description = isDuplicate 
        ? "Une ressource correspondante a été trouvée dans BoondManager (ID ${_detectedDuplicate!['id']}). Les champs ont été pré-remplis avec ses données actuelles. Vous pouvez les modifier puis cliquer sur 'Mettre à jour'." 
        : "Aucune ressource portant ce nom n'a été trouvée dans votre base BoondManager. Remplissez le formulaire ci-dessous pour créer cette ressource.";
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
          
          Text("IDENTITÉ", style: VivTypography.eyebrow.copyWith(fontSize: 10, color: VivColors.gray500)),
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
                      "Renseignez la civilité, le prénom et le nom de famille de la ressource ci-dessus, puis lancez la vérification d'existence pour continuer.",
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
                  child: _buildTextField("Fonction / Titre professionnel", _functionController, "ex: Développeur Senior"),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDropdownField(
                    label: "Type de ressource",
                    value: _selectedType,
                    options: _resourceTypes,
                    onChanged: (v) => setState(() => _selectedType = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text("ORGANISATION & CONTRAT", style: VivTypography.eyebrow.copyWith(fontSize: 10, color: VivColors.gray500)),
            const SizedBox(height: 8),
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
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildDropdownField(
                    label: "Responsable manager *",
                    value: _selectedManager,
                    options: _users,
                    onChanged: (v) => setState(() => _selectedManager = v),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDropdownField(
                    label: "Responsable RH *",
                    value: _selectedHrManager,
                    options: _users,
                    onChanged: (v) => setState(() => _selectedHrManager = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildDropdownField(
                    label: "État de la ressource",
                    value: _selectedState,
                    options: _resourceStates,
                    onChanged: (v) => setState(() => _selectedState = v),
                  ),
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 20),
            Text("COORDONNÉES & LOCALISATION", style: VivTypography.eyebrow.copyWith(fontSize: 10, color: VivColors.gray500)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildTextField("Email", _emailController, "ex: m.dupont@email.com"),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField("Téléphone", _phoneController, "ex: 0612345678"),
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
                  const SnackBar(content: Text("Contenu copié dans le presse-papiers.")),
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
                  : const Text("Mettre à jour la Ressource", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            )
          else
            ShadButton(
              backgroundColor: VivColors.lime,
              onPressed: _isActionInProgress ? null : _processCreate,
              child: _isActionInProgress
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text("Créer la Ressource", style: TextStyle(fontWeight: FontWeight.bold, color: VivColors.black)),
            ),
        ],
      ],
    );
  }
}
