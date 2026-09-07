import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../../design_system/viv_colors.dart';
import '../../design_system/viv_spacing.dart';
import '../../design_system/viv_typography.dart';
import '../../services/boond_service.dart';
import '../../services/bdc_rules_service.dart';

class BdcRulesDiagnosticScreen extends ConsumerStatefulWidget {
  final VoidCallback onClose;

  const BdcRulesDiagnosticScreen({super.key, required this.onClose});

  @override
  ConsumerState<BdcRulesDiagnosticScreen> createState() => _BdcRulesDiagnosticScreenState();
}

class _BdcRulesDiagnosticScreenState extends ConsumerState<BdcRulesDiagnosticScreen> {
  // Liste locale des règles enregistrées
  List<BdcRule> _rulesList = [];

  // Données BoondManager chargées
  bool _isLoadingBoondData = false;
  String _boondLoadError = "";
  List<Map<String, dynamic>> _allClients = []; // id, name
  List<Map<String, dynamic>> _allProjects = []; // id, name, clientId
  List<Map<String, dynamic>> _allResources = []; // id, name
  List<Map<String, dynamic>> _allProviders = []; // id, name

  // Données contextuelles pour le formulaire
  List<Map<String, dynamic>> _filteredProjectsForClient = [];
  List<Map<String, dynamic>> _clientContacts = []; // id, name (prenom + nom)
  bool _isLoadingContacts = false;

  // État du mode d'édition
  bool _isFormOpen = false;
  String? _editingRuleId;

  // Champs du formulaire
  String _clientName = "";
  String _clientCsoc = "";
  
  // Visibilité et valeurs des options progressives
  bool _showContactFields = false;
  String _contactName = "";
  String _contactCcon = "";

  bool _showProjectField = false;
  String _projectId = "";

  bool _showResourceField = false;
  String _resourceId = "";
  String _resourceName = "";

  bool _showProviderField = false;
  String _providerId = "";
  String _providerName = "";

  List<BdcRuleKeyword> _keywords = [];

  String _calculationMode = "standard"; 
  double _manualDays = 1.0;
  String _titleMode = "delivery_title"; 

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRules();
      _loadBoondData();
    });
  }

  Future<void> _loadRules() async {
    final rules = await BdcRulesService().loadRules();
    if (mounted) {
      setState(() {
        _rulesList = rules;
      });
    }
  }

  Future<void> _loadBoondData() async {
    setState(() {
      _isLoadingBoondData = true;
      _boondLoadError = "";
    });

    final service = ref.read(boondServiceProvider);

    try {
      // 1. Récupérer les projets actifs avec inclusion de la société cliente
      final response = await service.getProjectsWithInclusions(
        filters: {'states[]': 1},
        inclusions: ['company'],
      );

      final projectsData = response['data'] as List? ?? [];
      final includedData = response['included'] as List? ?? [];

      // Extraire les clients uniques
      final Map<String, Map<String, dynamic>> clientsMap = {};
      for (var item in includedData) {
        if (item['type'] == 'company') {
          final id = item['id']?.toString() ?? '';
          final name = item['attributes']?['name']?.toString() ?? 'Société sans nom';
          if (id.isNotEmpty) {
            clientsMap[id] = {
              'id': id,
              'name': name.toUpperCase(),
            };
          }
        }
      }

      // Extraire les projets
      final List<Map<String, dynamic>> loadedProjects = [];
      for (var p in projectsData) {
        final id = p['id']?.toString() ?? '';
        final name = p['attributes']?['reference']?.toString() ?? 'Projet sans nom';
        final clientRel = p['relationships']?['company']?['data'];
        final clientId = clientRel?['id']?.toString() ?? '';
        
        if (id.isNotEmpty) {
          loadedProjects.add({
            'id': id,
            'name': name,
            'clientId': clientId,
          });
        }
      }

      // 2. Récupérer les ressources actives (state == 1)
      List<Map<String, dynamic>> loadedResources = [];
      try {
        final resourcesRaw = await service.searchResources('');
        for (var r in resourcesRaw) {
          final id = r['id']?.toString() ?? '';
          final rAttr = r['attributes'] as Map<String, dynamic>? ?? {};
          final name = "${rAttr['firstName'] ?? ''} ${rAttr['lastName'] ?? ''}".trim();
          if (id.isNotEmpty && name.isNotEmpty) {
            loadedResources.add({
              'id': id,
              'name': name,
            });
          }
        }
        loadedResources.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
      } catch (_) {}

      // 3. Récupérer les fournisseurs (sociétés de type fournisseur ou toutes sociétés)
      List<Map<String, dynamic>> loadedProviders = [];
      try {
        final companiesRaw = await service.searchCompanies('');
        for (var comp in companiesRaw) {
          final id = comp['id']?.toString() ?? '';
          final compAttr = comp['attributes'] as Map<String, dynamic>? ?? {};
          final name = compAttr['name']?.toString().toUpperCase() ?? '';
          if (id.isNotEmpty && name.isNotEmpty) {
            loadedProviders.add({
              'id': id,
              'name': name,
            });
          }
        }
        loadedProviders.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
      } catch (_) {}

      setState(() {
        _allClients = clientsMap.values.toList();
        _allProjects = loadedProjects;
        _allResources = loadedResources;
        _allProviders = loadedProviders;
        _isLoadingBoondData = false;
      });
    } catch (e) {
      setState(() {
        _boondLoadError = e.toString();
        _isLoadingBoondData = false;
      });
    }
  }

  // Se déclenche à la sélection d'un client
  Future<void> _onClientSelected(String clientId) async {
    final clientObj = _allClients.firstWhere((c) => c['id'] == clientId, orElse: () => {});
    if (clientObj.isEmpty) return;

    setState(() {
      _clientName = clientObj['name'] ?? '';
      _clientCsoc = clientId;

      // Filtrer les projets pour ce client
      _filteredProjectsForClient = _allProjects.where((p) => p['clientId'] == clientId).toList();

      // Reset contact et projet si changement de client
      _contactName = "";
      _contactCcon = "";
      _projectId = "";
      _clientContacts = [];
    });

    // Charger les contacts du client en tâche de fond
    if (_showContactFields) {
      await _loadContactsForClient(clientId);
    }
  }

  Future<void> _loadContactsForClient(String clientId) async {
    setState(() {
      _isLoadingContacts = true;
      _clientContacts = [];
    });

    final service = ref.read(boondServiceProvider);

    try {
      final intId = int.tryParse(clientId);
      if (intId != null) {
        final contactsRaw = await service.getCompanyContacts(intId);
        final List<Map<String, dynamic>> loadedContacts = [];
        for (var c in contactsRaw) {
          final id = c['id']?.toString() ?? '';
          final cAttr = c['attributes'] ?? {};
          final name = "${cAttr['firstName'] ?? ''} ${cAttr['lastName'] ?? ''}".trim();
          if (id.isNotEmpty) {
            loadedContacts.add({
              'id': id,
              'name': name,
            });
          }
        }

        setState(() {
          _clientContacts = loadedContacts;
          _isLoadingContacts = false;
        });
      }
    } catch (_) {
      setState(() {
        _isLoadingContacts = false;
      });
    }
  }

  void _openCreationForm() {
    setState(() {
      _isFormOpen = true;
      _editingRuleId = null;
      
      _clientName = "";
      _clientCsoc = "";
      _showContactFields = false;
      _contactName = "";
      _contactCcon = "";
      _showProjectField = false;
      _projectId = "";
      _showResourceField = false;
      _resourceId = "";
      _resourceName = "";
      _showProviderField = false;
      _providerId = "";
      _providerName = "";
      _keywords = [];
      _calculationMode = "standard";
      _manualDays = 1.0;
      _titleMode = "delivery_title";
      _filteredProjectsForClient = [];
      _clientContacts = [];
    });
  }

  void _openEditionForm(BdcRule rule) {
    setState(() {
      _isFormOpen = true;
      _editingRuleId = rule.id;

      _clientName = rule.clientName;
      _clientCsoc = rule.clientCsoc;
      
      _showContactFields = rule.contactName.isNotEmpty || rule.contactCcon.isNotEmpty;
      _contactName = rule.contactName;
      _contactCcon = rule.contactCcon;

      _showProjectField = rule.projectId.isNotEmpty;
      _projectId = rule.projectId;

      _showResourceField = rule.resourceId.isNotEmpty;
      _resourceId = rule.resourceId;
      _resourceName = rule.resourceName;

      _showProviderField = rule.providerId.isNotEmpty;
      _providerId = rule.providerId;
      _providerName = rule.providerName;

      _keywords = rule.keywords
          .map((k) => BdcRuleKeyword(
                text: k.text,
                caseSensitive: k.caseSensitive,
                isNegative: k.isNegative,
              ))
          .toList();
      _calculationMode = rule.calculationMode;
      _manualDays = rule.manualDays > 0 ? rule.manualDays : 1.0;
      _titleMode = rule.titleMode;

      // Restaurer le contexte projets et contacts
      _filteredProjectsForClient = _allProjects.where((p) => p['clientId'] == rule.clientCsoc).toList();
    });

    if (rule.clientCsoc.isNotEmpty && (rule.contactName.isNotEmpty || rule.contactCcon.isNotEmpty)) {
      _loadContactsForClient(rule.clientCsoc);
    }
  }

  void _saveRule() {
    if (_clientName.trim().isEmpty || _clientCsoc.trim().isEmpty) {
      ShadToaster.of(context).show(
        const ShadToast.destructive(
          title: Text("Erreur"),
          description: Text("Veuillez sélectionner un client valide."),
        ),
      );
      return;
    }

    final savedRule = BdcRule(
      id: _editingRuleId ?? "R-${_rulesList.length + 1}",
      clientName: _clientName.trim(),
      clientCsoc: _clientCsoc.trim(),
      contactName: _showContactFields ? _contactName.trim() : "",
      contactCcon: _showContactFields ? _contactCcon.trim() : "",
      projectId: _showProjectField ? _projectId.trim() : "",
      resourceId: _showResourceField ? _resourceId.trim() : "",
      resourceName: _showResourceField ? _resourceName.trim() : "",
      providerId: _showProviderField ? _providerId.trim() : "",
      providerName: _showProviderField ? _providerName.trim() : "",
      keywords: _keywords.where((k) => k.text.trim().isNotEmpty).toList(),
      calculationMode: _calculationMode,
      manualDays: _calculationMode == 'manual' ? _manualDays : 0,
      titleMode: _titleMode,
    );

    setState(() {
      if (_editingRuleId != null) {
        final index = _rulesList.indexWhere((r) => r.id == _editingRuleId);
        if (index != -1) {
          _rulesList[index] = savedRule;
        }
      } else {
        _rulesList.add(savedRule);
      }
      _isFormOpen = false;
      _editingRuleId = null;
    });

    BdcRulesService().saveRules(_rulesList);

    ShadToaster.of(context).show(
      ShadToast(
        title: Text(_editingRuleId != null ? "Règle mise à jour !" : "Règle enregistrée !"),
        description: const Text("Vos configurations ont été appliquées avec succès."),
        backgroundColor: Colors.teal,
      ),
    );
  }

  void _deleteRule(String id) {
    setState(() {
      _rulesList.removeWhere((r) => r.id == id);
      if (_editingRuleId == id) {
        _isFormOpen = false;
        _editingRuleId = null;
      }
    });
    BdcRulesService().saveRules(_rulesList);
    ShadToaster.of(context).show(
      ShadToast.destructive(
        title: const Text("Règle supprimée"),
        description: Text("La règle $id a été retirée."),
      ),
    );
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
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Panel de gauche : Formulaire dynamique OU bouton de création
                Expanded(
                  flex: 11,
                  child: Container(
                    padding: const EdgeInsets.all(VivSpacing.space6),
                    child: _isLoadingBoondData
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(height: 16),
                                Text("Récupération des clients et projets actifs...", style: TextStyle(color: VivColors.gray500)),
                              ],
                            ),
                          )
                        : _isFormOpen
                            ? _buildFormWidget()
                            : _buildWelcomeWidget(),
                  ),
                ),
                const VerticalDivider(width: 1, color: VivColors.gray200),
                // Panel de droite : Liste de règles
                Expanded(
                  flex: 9,
                  child: Container(
                    color: Colors.grey.shade50,
                    padding: const EdgeInsets.all(VivSpacing.space6),
                    child: _buildRulesListWidget(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: VivSpacing.space6, vertical: VivSpacing.space4),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: VivColors.gray200)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                "Gestion des Règles Spécifiques BDC",
                style: VivTypography.h4.copyWith(fontFamily: VivTypography.sansFont, fontSize: 16),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.teal.withAlpha((0.1 * 255).round()),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  "Connecté Boond",
                  style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, fontSize: 10),
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(LucideIcons.x, color: VivColors.gray400, size: 20),
            onPressed: widget.onClose,
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.pencilRuler, color: VivColors.gray300, size: 48),
          const SizedBox(height: 16),
          Text(
            "Aucune règle en cours d'édition",
            style: VivTypography.body.copyWith(fontWeight: FontWeight.w600, color: VivColors.gray500),
          ),
          const SizedBox(height: 8),
          Text(
            "Configurez une règle spécifique par client pour automatiser les UO et les libellés.",
            style: VivTypography.small.copyWith(color: VivColors.gray400),
            textAlign: TextAlign.center,
          ),
          if (_boondLoadError.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              "Erreur Boond : $_boondLoadError",
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 24),
          ShadButton(
            backgroundColor: Colors.black,
            onPressed: _openCreationForm,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.plus, size: 16, color: Colors.white),
                SizedBox(width: 8),
                Text("Créer une règle spécifique", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormWidget() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _editingRuleId != null ? "Modifier la Règle $_editingRuleId" : "Nouvelle Règle Spécifique",
                style: VivTypography.h4.copyWith(fontSize: 16),
              ),
              TextButton(
                onPressed: () => setState(() => _isFormOpen = false),
                child: const Text("Annuler", style: TextStyle(color: Colors.redAccent)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // 1. Cible Client (Sélection Dynamique Boond)
          const Text("CLIENT", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: VivColors.gray500)),
          const SizedBox(height: 8),
          ShadSelect<String>(
            placeholder: const Text("Sélectionner un Client actif"),
            initialValue: _clientCsoc.isNotEmpty ? _clientCsoc : null,
            options: _allClients.map((client) {
              return ShadOption(
                value: client['id']!,
                child: Text("${client['name']} (CSOC${client['id']})"),
              );
            }).toList(),
            selectedOptionBuilder: (context, value) => Text(
              _allClients.firstWhere((c) => c['id'] == value, orElse: () => {'name': ''})['name']!,
            ),
            onChanged: (val) {
              if (val != null) {
                _onClientSelected(val);
              }
            },
          ),
          
          if (_clientCsoc.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              "Identifiant résolu : CSOC$_clientCsoc",
              style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, fontSize: 11),
            ),
          ],

          const SizedBox(height: 16),

          // Boutons pour déplier les options facultatives (Accessibles uniquement si client sélectionné)
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              if (!_showContactFields)
                _buildAddOptionButton(
                  label: "Ajouter un contact client",
                  onPressed: _clientCsoc.isEmpty
                      ? null
                      : () {
                          setState(() => _showContactFields = true);
                          _loadContactsForClient(_clientCsoc);
                        },
                ),
              if (!_showProjectField)
                _buildAddOptionButton(
                  label: "Cibler un projet",
                  onPressed: _clientCsoc.isEmpty
                      ? null
                      : () => setState(() => _showProjectField = true),
                ),
              if (!_showResourceField)
                _buildAddOptionButton(
                  label: "Cibler une ressource",
                  onPressed: _clientCsoc.isEmpty
                      ? null
                      : () => setState(() => _showResourceField = true),
                ),
              if (!_showProviderField)
                _buildAddOptionButton(
                  label: "Cibler un fournisseur",
                  onPressed: _clientCsoc.isEmpty
                      ? null
                      : () => setState(() => _showProviderField = true),
                ),
              if (_keywords.isEmpty)
                _buildAddOptionButton(
                  label: "Ajouter un mot-clé",
                  onPressed: _clientCsoc.isEmpty
                      ? null
                      : () => setState(() => _keywords.add(BdcRuleKeyword(text: ""))),
                ),
            ],
          ),

          // Champs Contact Client (Filtre dynamique par client)
          if (_showContactFields && _clientCsoc.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                const Text("CONTACT CLIENT DE CETTE SOCIÉTÉ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: VivColors.gray500)),
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() {
                    _showContactFields = false;
                    _contactName = "";
                    _contactCcon = "";
                  }),
                  child: const Icon(LucideIcons.circleMinus, size: 16, color: Colors.redAccent),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _isLoadingContacts
                ? const Row(
                    children: [
                      SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                      SizedBox(width: 8),
                      Text("Chargement des contacts...", style: TextStyle(fontSize: 12, color: VivColors.gray400)),
                    ],
                  )
                : _clientContacts.isEmpty
                    ? const Text("Aucun contact trouvé pour cette société.", style: TextStyle(fontSize: 12, color: Colors.redAccent))
                    : ShadSelect<String>(
                        placeholder: const Text("Sélectionner un Contact"),
                        initialValue: _contactCcon.isNotEmpty ? _contactCcon : null,
                        options: _clientContacts.map((contact) {
                          return ShadOption(
                            value: contact['id']!,
                            child: Text("${contact['name']} (CCON${contact['id']})"),
                          );
                        }).toList(),
                        selectedOptionBuilder: (context, value) => Text(
                          _clientContacts.firstWhere((c) => c['id'] == value, orElse: () => {'name': ''})['name']!,
                        ),
                        onChanged: (val) {
                          if (val != null) {
                            final cObj = _clientContacts.firstWhere((c) => c['id'] == val);
                            setState(() {
                              _contactName = cObj['name'];
                              _contactCcon = val;
                            });
                          }
                        },
                      ),
            if (_contactCcon.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                "Identifiant résolu : CCON$_contactCcon",
                style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, fontSize: 11),
              ),
            ],
          ],

          // Champ Projet (Filtre dynamique par client)
          if (_showProjectField && _clientCsoc.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                const Text("PROJET CIBLE DE CE CLIENT", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: VivColors.gray500)),
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() {
                    _showProjectField = false;
                    _projectId = "";
                  }),
                  child: const Icon(LucideIcons.circleMinus, size: 16, color: Colors.redAccent),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _filteredProjectsForClient.isEmpty
                ? const Text("Aucun projet actif trouvé pour ce client.", style: TextStyle(fontSize: 12, color: Colors.redAccent))
                : ShadSelect<String>(
                    placeholder: const Text("Sélectionnez un projet de la liste"),
                    initialValue: _projectId.isNotEmpty ? _projectId : null,
                    options: _filteredProjectsForClient.map((project) {
                      return ShadOption(
                        value: project['id']!,
                        child: Text("${project['name']} (PRJ${project['id']})"),
                      );
                    }).toList(),
                    selectedOptionBuilder: (context, value) => Text(
                      _filteredProjectsForClient.firstWhere((p) => p['id'] == value, orElse: () => {'name': ''})['name']!,
                    ),
                    onChanged: (val) => setState(() => _projectId = val ?? ''),
                  ),
            if (_projectId.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                "Identifiant résolu : PRJ$_projectId",
                style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, fontSize: 11),
              ),
            ],
          ],

          // Champ Ressource ciblée
          if (_showResourceField && _clientCsoc.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                const Text("RESSOURCE CIBLÉE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: VivColors.gray500)),
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() {
                    _showResourceField = false;
                    _resourceId = "";
                    _resourceName = "";
                  }),
                  child: const Icon(LucideIcons.circleMinus, size: 16, color: Colors.redAccent),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _allResources.isEmpty
                ? const Text("Aucune ressource disponible.", style: TextStyle(fontSize: 12, color: Colors.redAccent))
                : ShadSelect<String>(
                    placeholder: const Text("Sélectionnez une ressource"),
                    initialValue: _resourceId.isNotEmpty ? _resourceId : null,
                    options: _allResources.map((res) {
                      return ShadOption(
                        value: res['id']!,
                        child: Text("${res['name']} (COMP${res['id']})"),
                      );
                    }).toList(),
                    selectedOptionBuilder: (context, value) {
                      final found = _allResources.firstWhere((r) => r['id'] == value, orElse: () => {'name': ''});
                      return Text(found['name']!.isNotEmpty ? "${found['name']} (COMP$value)" : '');
                    },
                    onChanged: (val) {
                      if (val != null) {
                        final found = _allResources.firstWhere((r) => r['id'] == val, orElse: () => {'name': ''});
                        setState(() {
                          _resourceId = val;
                          _resourceName = found['name'] ?? '';
                        });
                      }
                    },
                  ),
            if (_resourceId.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                "Identifiant résolu : COMP$_resourceId",
                style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, fontSize: 11),
              ),
            ],
          ],

          // Champ Fournisseur ciblé
          if (_showProviderField && _clientCsoc.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                const Text("FOURNISSEUR CIBLÉ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: VivColors.gray500)),
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() {
                    _showProviderField = false;
                    _providerId = "";
                    _providerName = "";
                  }),
                  child: const Icon(LucideIcons.circleMinus, size: 16, color: Colors.redAccent),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _allProviders.isEmpty
                ? const Text("Aucun fournisseur disponible.", style: TextStyle(fontSize: 12, color: Colors.redAccent))
                : ShadSelect<String>(
                    placeholder: const Text("Sélectionnez un fournisseur"),
                    initialValue: _providerId.isNotEmpty ? _providerId : null,
                    options: _allProviders.map((provider) {
                      return ShadOption(
                        value: provider['id']!,
                        child: Text("${provider['name']} (CSOC${provider['id']})"),
                      );
                    }).toList(),
                    selectedOptionBuilder: (context, value) {
                      final found = _allProviders.firstWhere((p) => p['id'] == value, orElse: () => {'name': ''});
                      return Text(found['name']!.isNotEmpty ? "${found['name']} (CSOC$value)" : '');
                    },
                    onChanged: (val) {
                      if (val != null) {
                        final found = _allProviders.firstWhere((p) => p['id'] == val, orElse: () => {'name': ''});
                        setState(() {
                          _providerId = val;
                          _providerName = found['name'] ?? '';
                        });
                      }
                    },
                  ),
            if (_providerId.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                "Identifiant résolu : CSOC$_providerId",
                style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, fontSize: 11),
              ),
            ],
          ],

          // Liste des mots-clés de prestation (Seulement si client sélectionné)
          if (_keywords.isNotEmpty && _clientCsoc.isNotEmpty) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                const Text("MOTS-CLÉS D'INTITULÉ DE PRESTATION", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: VivColors.gray500)),
                const Spacer(),
                _buildAddOptionButton(
                  label: "Ajouter un mot-clé",
                  onPressed: () => setState(() => _keywords.add(BdcRuleKeyword(text: ""))),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _keywords.length,
              separatorBuilder: (c, i) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final kw = _keywords[index];
                return Row(
                  children: [
                    SizedBox(
                      width: 140,
                      child: ShadSelect<bool>(
                        initialValue: kw.isNegative,
                        options: const [
                          ShadOption(value: false, child: Text("Contient")),
                          ShadOption(value: true, child: Text("Ne contient pas")),
                        ],
                        selectedOptionBuilder: (context, value) => Text(
                          value == true ? "Ne contient pas" : "Contient",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: value == true ? Colors.redAccent.shade700 : VivColors.ink700,
                          ),
                        ),
                        onChanged: (val) => setState(() => kw.isNegative = val ?? false),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ShadInput(
                        placeholder: const Text("Mot-clé"),
                        initialValue: kw.text,
                        onChanged: (val) => setState(() => kw.text = val),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      children: [
                        Checkbox(
                          value: kw.caseSensitive,
                          activeColor: Colors.black,
                          onChanged: (val) => setState(() => kw.caseSensitive = val ?? false),
                        ),
                        const Text("Casse", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                      ],
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(LucideIcons.trash2, color: Colors.redAccent, size: 16),
                      onPressed: () => setState(() => _keywords.removeAt(index)),
                    ),
                  ],
                );
              },
            ),
          ],

          const Divider(height: 40),

          // 2. Mode de calcul
          const Text("DÉCOMPTE DES JOURS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: VivColors.gray500)),
          const SizedBox(height: 8),
          ShadSelect<String>(
            placeholder: const Text("Sélectionnez le mode de calcul"),
            initialValue: _calculationMode,
            options: [
              ShadOption(value: 'standard', child: const Text("Standard")),
              ShadOption(value: 'sold', child: const Text("Jours Vendus")),
              ShadOption(value: 'manual', child: const Text("Fixe Manuel")),
            ],
            selectedOptionBuilder: (context, value) => Text(
              value == 'standard'
                  ? "Standard"
                  : value == 'sold'
                      ? "Jours Vendus"
                      : "Fixe Manuel",
            ),
            onChanged: (val) => setState(() => _calculationMode = val ?? 'standard'),
          ),

          if (_calculationMode == 'manual') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                SizedBox(
                  width: 100,
                  child: ShadInput(
                    initialValue: _manualDays.toString(),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (val) {
                      final d = double.tryParse(val);
                      if (d != null && d >= 0) {
                        setState(() => _manualDays = d);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                const Text("jours maximum", style: TextStyle(fontSize: 13, color: VivColors.gray500)),
              ],
            ),
          ],

          const SizedBox(height: 20),

          // 3. Règle d'intitulé
          const Text("INTITULÉ DE LA PRESTATION SUR LE BDC", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: VivColors.gray500)),
          const SizedBox(height: 8),
          ShadSelect<String>(
            placeholder: const Text("Sélectionnez la règle d'intitulé"),
            initialValue: _titleMode,
            options: [
              ShadOption(value: 'delivery_title', child: const Text("Conserver l'intitulé Boond")),
              ShadOption(value: 'resource_title', child: const Text("Remplacer par le titre professionnel")),
            ],
            selectedOptionBuilder: (context, value) => Text(
              value == 'delivery_title'
                  ? "Conserver l'intitulé Boond"
                  : "Remplacer par le titre professionnel",
            ),
            onChanged: (val) => setState(() => _titleMode = val ?? 'delivery_title'),
          ),

          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            height: 40,
            child: ShadButton(
              backgroundColor: Colors.black,
              onPressed: _saveRule,
              child: Text(
                _editingRuleId != null ? "Mettre à jour la règle" : "Enregistrer la règle spécifique",
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddOptionButton({required String label, required VoidCallback? onPressed}) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: onPressed != null ? Colors.black : VivColors.gray300,
        side: BorderSide(color: onPressed != null ? VivColors.gray200 : VivColors.gray100),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(VivSpacing.radiusMd),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.plus, size: 14, color: onPressed != null ? Colors.black : VivColors.gray300),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildRulesListWidget() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "RÈGLES CONFIGURÉES (${_rulesList.length})",
              style: VivTypography.small.copyWith(fontWeight: FontWeight.bold, color: VivColors.gray500),
            ),
            if (!_isFormOpen)
              IconButton(
                icon: const Icon(LucideIcons.circlePlus, color: Colors.black, size: 20),
                onPressed: _openCreationForm,
                tooltip: "Ajouter une règle",
              ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _rulesList.isEmpty
              ? const Center(child: Text("Aucune règle configurée.", style: TextStyle(color: VivColors.gray400)))
              : ListView.separated(
                  itemCount: _rulesList.length,
                  separatorBuilder: (c, i) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final rule = _rulesList[index];
                    final isEditingThis = _editingRuleId == rule.id;

                    return Container(
                      padding: const EdgeInsets.all(VivSpacing.space4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(
                          color: isEditingThis ? Colors.black : VivColors.gray200,
                          width: isEditingThis ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(VivSpacing.radiusMd),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                rule.clientName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              if (rule.clientCsoc.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Text(
                                  "(CSOC${rule.clientCsoc})",
                                  style: const TextStyle(color: VivColors.gray400, fontSize: 12),
                                ),
                              ],
                              const Spacer(),
                              GestureDetector(
                                onTap: () => _openEditionForm(rule),
                                child: Icon(
                                  LucideIcons.pencil,
                                  size: 14,
                                  color: isEditingThis ? Colors.black : VivColors.gray400,
                                ),
                              ),
                              const SizedBox(width: 12),
                              GestureDetector(
                                onTap: () => _deleteRule(rule.id),
                                child: const Icon(LucideIcons.trash2, size: 14, color: Colors.redAccent),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          
                          // Détails des cibles / filtres
                          if (rule.contactName.isNotEmpty || rule.contactCcon.isNotEmpty)
                            _buildListDetailLine(
                              label: "Contact",
                              value: "${rule.contactName} ${rule.contactCcon.isNotEmpty ? '(CCON${rule.contactCcon})' : ''}",
                            ),
                          if (rule.projectId.isNotEmpty)
                            _buildListDetailLine(label: "Projet ciblé", value: "PRJ${rule.projectId}"),
                          if (rule.resourceId.isNotEmpty)
                            _buildListDetailLine(
                              label: "Ressource",
                              value: "${rule.resourceName.isNotEmpty ? rule.resourceName : 'Ressource'} (COMP${rule.resourceId})",
                            ),
                          if (rule.providerId.isNotEmpty)
                            _buildListDetailLine(
                              label: "Fournisseur",
                              value: "${rule.providerName.isNotEmpty ? rule.providerName : 'Fournisseur'} (CSOC${rule.providerId})",
                            ),
                          if (rule.keywords.isNotEmpty) ...[
                            for (var k in rule.keywords)
                              _buildListDetailLine(
                                label: k.isNegative ? "Intitulé NE contient PAS" : "Intitulé contient",
                                value: "'${k.text}' ${k.caseSensitive ? '[Aa]' : ''}",
                              ),
                          ],

                          const SizedBox(height: 8),
                          const Divider(height: 1, color: VivColors.gray100),
                          const SizedBox(height: 8),

                          // Calcul et Libellé
                          Row(
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    const Icon(LucideIcons.calculator, size: 12, color: VivColors.gray500),
                                    const SizedBox(width: 6),
                                    Text(
                                      rule.calculationMode == 'standard'
                                          ? "Standard"
                                          : rule.calculationMode == 'sold'
                                              ? "Jours vendus"
                                              : "Fixe (${rule.manualDays}j)",
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: VivColors.gray500),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Row(
                                  children: [
                                    const Icon(LucideIcons.pencil, size: 12, color: VivColors.gray500),
                                    const SizedBox(width: 6),
                                    Text(
                                      rule.titleMode == 'delivery_title'
                                          ? "Libellé Boond"
                                          : "Titre ressource",
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: VivColors.gray500),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildListDetailLine({required String label, required String value}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "$label : ",
            style: const TextStyle(color: VivColors.gray400, fontSize: 12, fontWeight: FontWeight.w500),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: VivColors.gray500, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
