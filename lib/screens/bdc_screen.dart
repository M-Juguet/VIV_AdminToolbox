import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:printing/printing.dart';
import '../design_system/viv_colors.dart';
import '../design_system/viv_spacing.dart';
import '../design_system/viv_typography.dart';
import '../providers/settings_provider.dart';
import '../providers/dashboard_provider.dart';
import '../services/bdc_pdf_service.dart';
import 'tools/bdc_rules_diagnostic_screen.dart';

import '../services/bdc_sent_logs_service.dart';
import '../services/boond_cache_service.dart';

class BdcPrestaStep1 {
  final String id;
  final String consultantName;
  final String providerName;
  final String providerId;
  final String projectName;
  final String clientName;
  final String title;
  final String? alertMessage;
  final String boondLink;
  bool isSelected;
  bool isAlreadySent;
  String? sentDate;

  BdcPrestaStep1({
    required this.id,
    required this.consultantName,
    required this.providerName,
    required this.providerId,
    required this.projectName,
    required this.clientName,
    required this.title,
    this.alertMessage,
    required this.boondLink,
    this.isSelected = true,
    this.isAlreadySent = false,
    this.sentDate,
  });
}

class BdcPrestaStep2 {
  final String id;
  final String consultantName;
  final String clientName;
  final String projectName;
  final String prestationTitle;
  final String calculationMode; // Standard, Jours vendus, Fixe
  final int uoCount;
  final double tjm;
  final double totalHt;
  final String? appliedRule;

  BdcPrestaStep2({
    required this.id,
    required this.consultantName,
    required this.clientName,
    required this.projectName,
    required this.prestationTitle,
    required this.calculationMode,
    required this.uoCount,
    required this.tjm,
    required this.totalHt,
    this.appliedRule,
  });
}

class BdcMailStatus {
  final String id;
  final String consultantName;
  final String providerName;
  final String email;
  String status; // 'pending', 'generating', 'sending', 'success', 'failed'
  String? errorMessage;

  BdcMailStatus({
    required this.id,
    required this.consultantName,
    required this.providerName,
    required this.email,
    this.status = 'pending',
    this.errorMessage,
  });
}

class BdcScreen extends ConsumerStatefulWidget {
  const BdcScreen({super.key});

  @override
  ConsumerState<BdcScreen> createState() => _BdcScreenState();
}

class _BdcScreenState extends ConsumerState<BdcScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Filtres Période
  String _selectedMonth = "08"; // Août par défaut
  String _selectedYear = "2026";

  // État de déverrouillage des étapes
  int _maxUnlockedStep = 0; // 0: Détection initiale, 1: Étape 1 déverrouillée, 2: Étape 2 déverrouillée
  bool _isLoadingDetection = false;
  bool _isSendingMails = false;

  // Variables de filtrage et recherche (Phase 1)
  String _searchQuery = "";
  String? _filterClient;
  String? _filterProject;

  // Mémorisation de détection par période
  final Map<String, bool> _periodDetectionStatus = {};

  String get _currentPeriodKey => "${_selectedMonth}_$_selectedYear";
  bool get _isCurrentPeriodDetected => _periodDetectionStatus[_currentPeriodKey] ?? false;

  // Données de session mockées
  late List<BdcPrestaStep1> _step1Candidates;
  List<BdcPrestaStep2> _step2Calculated = [];
  List<BdcMailStatus> _smtpStatusList = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabSelection);
    _resetStep1Data();
  }

  void _handleTabSelection() {
    if (_tabController.index > _maxUnlockedStep) {
      // Annuler la navigation et forcer le retour à l'étape maximale autorisée
      setState(() {
        _tabController.index = _tabController.previousIndex;
      });
      ShadToaster.of(context).show(
        const ShadToast.destructive(
          title: Text("Accès restreint"),
          description: Text("Veuillez d'abord compléter les étapes précédentes du processus."),
        ),
      );
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    super.dispose();
  }

  void _resetStep1Data() {
    _step1Candidates = [
      BdcPrestaStep1(
        id: "26",
        consultantName: "Natalie Portman",
        providerName: "John DOE & Cie",
        providerId: "CSOC15",
        projectName: "Mission Toto",
        clientName: "LOUIS VUITTON",
        title: "Mission de Nathalie (Toto)",
        boondLink: "https://ui.boondmanager.com/companies/15/information",
      ),
      BdcPrestaStep1(
        id: "27",
        consultantName: "John DOE",
        providerName: "John DOE & Cie",
        providerId: "CSOC15",
        projectName: "Projet de Tata",
        clientName: "Entreprise de peinture",
        title: "Ma super presta",
        boondLink: "https://ui.boondmanager.com/companies/15/information",
      ),
      BdcPrestaStep1(
        id: "24",
        consultantName: "Audrey TAUTOU",
        providerName: "Audrey Production",
        providerId: "CSOC22",
        projectName: "Projet Test BDC 02",
        clientName: "STELLANTIS",
        title: "DOP on model",
        boondLink: "https://ui.boondmanager.com/companies/22/information",
      ),
      BdcPrestaStep1(
        id: "23",
        consultantName: "Jean DUJARDIN",
        providerName: "Dujardin SAS",
        providerId: "CSOC9",
        projectName: "Projet Test BDC 02",
        clientName: "Entreprise de peinture",
        title: "Presta BDC A",
        alertMessage: "E-mail de contact commercial absent sur la fiche fournisseur.",
        boondLink: "https://ui.boondmanager.com/companies/9/information",
        isSelected: false, // Décoché par défaut à cause de l'alerte
      ),
    ];
  }

  // --- ACTIONS DU FLUX ---

  void _runDetection() async {
    setState(() {
      _isLoadingDetection = true;
    });

    // Charger les logs d'envoi pour cette période
    final period = '$_selectedMonth/$_selectedYear';
    final logsService = BdcSentLogsService();
    
    // Réinitialiser les candidats de base
    _resetStep1Data();

    // Vérifier les doublons dans la base locale
    for (var candidate in _step1Candidates) {
      final log = await logsService.getSentLog(candidate.providerId, period);
      if (log != null) {
        candidate.isAlreadySent = true;
        
        final sentAtStr = log['sentAt'] as String?;
        if (sentAtStr != null) {
          final sentAt = DateTime.parse(sentAtStr);
          candidate.sentDate = "${sentAt.day.toString().padLeft(2, '0')}/${sentAt.month.toString().padLeft(2, '0')}/${sentAt.year}";
        }
        
        // Sécurité : décocher automatiquement par défaut les bons déjà envoyés
        candidate.isSelected = false;
      }
    }

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _isLoadingDetection = false;
          _periodDetectionStatus[_currentPeriodKey] = true;
          _maxUnlockedStep = 0; // Onglet 0 actif avec données déverrouillées
        });
      }
    });
  }

  void _calculateSelected(List<BdcPrestaStep1> filteredList) {
    final selectedCandidates = filteredList.where((c) => c.isSelected).toList();
    
    // Simuler l'application des règles client
    final List<BdcPrestaStep2> results = [];
    for (var c in selectedCandidates) {
      String mode = "Standard";
      int uo = 21; // 21 jours ouvrés théoriques en Août 2026
      double tjm = 250.0;
      String? rule;
      String cName = c.consultantName;

      if (c.clientName == "LOUIS VUITTON") {
        mode = "Fixe Manuel";
        uo = 10; // Règle Louis Vuitton : Montage vidéo 10j
        tjm = 200.0;
        rule = "LOUIS VUITTON (Limitation fixe à 10 UO)";
      } else if (c.clientName == "STELLANTIS") {
        mode = "Jours Vendus";
        uo = 5; // Simule le volume vendu Boond
        tjm = 350.0;
        rule = "STELLANTIS (Jours vendus + Titre professionnel)";
      }

      results.add(BdcPrestaStep2(
        id: c.id,
        consultantName: cName,
        clientName: c.clientName,
        projectName: c.projectName,
        prestationTitle: c.title,
        calculationMode: mode,
        uoCount: uo,
        tjm: tjm,
        totalHt: uo * tjm,
        appliedRule: rule,
      ));
    }

    setState(() {
      _step2Calculated = results;
      _maxUnlockedStep = 1; // Déverrouille l'onglet 1 (Calcul & Audit)
    });
    
    _tabController.animateTo(1);
  }

  void _prepareSmtp() {
    final List<BdcMailStatus> smtpList = [];
    for (var c in _step2Calculated) {
      final orig = _step1Candidates.firstWhere((x) => x.id == c.id);
      smtpList.add(BdcMailStatus(
        id: c.id,
        consultantName: c.consultantName,
        providerName: orig.providerName,
        email: "contact@${orig.providerName.toLowerCase().replaceAll(' ', '')}.com",
        status: 'pending',
      ));
    }

    setState(() {
      _smtpStatusList = smtpList;
      _maxUnlockedStep = 2; // Déverrouille l'onglet 2 (SMTP)
    });

    _tabController.animateTo(2);
  }

  void _startSendingMails() {
    setState(() {
      _isSendingMails = true;
    });

    _sendMailSequential(0);
  }

  void _sendMailSequential(int index) {
    if (index >= _smtpStatusList.length) {
      setState(() {
        _isSendingMails = false;
      });
      ShadToaster.of(context).show(
        const ShadToast(
          title: Text("Distribution terminée"),
          description: Text("Les bons de commande conformes ont été expédiés."),
          backgroundColor: Colors.teal,
        ),
      );
      return;
    }

    final item = _smtpStatusList[index];
    final step2Item = _step2Calculated.firstWhere((x) => x.id == item.id);
    final step1Item = _step1Candidates.firstWhere((x) => x.id == item.id);

    // Étape 1 : Génération du PDF
    setState(() {
      item.status = 'generating';
    });

    Future.delayed(const Duration(milliseconds: 600), () async {
      if (!mounted) return;
      
      Uint8List? pdfBytes;
      try {
        pdfBytes = await BdcPdfService.generateBdcPdf(step2Item, _selectedMonth, _selectedYear);
      } catch (e) {
        setState(() {
          item.status = 'failed';
          item.errorMessage = "Échec de génération PDF : $e";
        });
        _sendMailSequential(index + 1);
        return;
      }

      // Étape 2 : Envoi SMTP
      setState(() {
        item.status = 'sending';
      });

      Future.delayed(const Duration(milliseconds: 800), () async {
        if (!mounted) return;
        
        final logsService = BdcSentLogsService();
        final period = '$_selectedMonth/$_selectedYear';

        // Simulation d'une erreur sur Audrey Production pour illustrer le "Renvoyer uniquement les échecs"
        if (item.providerName.contains("Audrey")) {
          setState(() {
            item.status = 'failed';
            item.errorMessage = "Hôte SMTP inaccessible (Timeout réseau)";
          });
        } else {
          try {
            // Sauvegarder dans Sembast + disque physique
            await logsService.logSentBdc(
              providerId: step1Item.providerId,
              consultantName: step2Item.consultantName,
              clientName: step2Item.clientName,
              projectName: step2Item.projectName,
              prestationTitle: step2Item.prestationTitle,
              period: period,
              sentToEmail: item.email,
              bdcNumber: "VIV-PO-${step1Item.providerId}-${_selectedMonth.toString().padLeft(2, '0')}${_selectedYear.toString().substring(2)}",
              uoCount: step2Item.uoCount.toDouble(),
              totalHt: step2Item.totalHt,
              pdfBytes: pdfBytes!,
            );

            // Mettre à jour immédiatement en mémoire pour que la phase 1 soit à jour
            step1Item.isAlreadySent = true;
            final now = DateTime.now();
            step1Item.sentDate = "${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}";
            step1Item.isSelected = false;

            setState(() {
              item.status = 'success';
            });
          } catch (dbError) {
            setState(() {
              item.status = 'failed';
              item.errorMessage = "Échec d'archivage local : $dbError";
            });
          }
        }

        _sendMailSequential(index + 1);
      });
    });
  }

  void _retryFailedMails() async {
    setState(() {
      _isSendingMails = true;
    });

    final logsService = BdcSentLogsService();
    final period = '$_selectedMonth/$_selectedYear';

    for (var item in _smtpStatusList) {
      if (item.status == 'failed') {
        setState(() {
          item.status = 'generating';
        });
        
        await Future.delayed(const Duration(milliseconds: 600));
        
        final step2Item = _step2Calculated.firstWhere((x) => x.id == item.id);
        final step1Item = _step1Candidates.firstWhere((x) => x.id == item.id);
        
        Uint8List? pdfBytes;
        try {
          pdfBytes = await BdcPdfService.generateBdcPdf(step2Item, _selectedMonth, _selectedYear);
          
          setState(() {
            item.status = 'sending';
          });
          
          await Future.delayed(const Duration(milliseconds: 800));

          await logsService.logSentBdc(
            providerId: step1Item.providerId,
            consultantName: step2Item.consultantName,
            clientName: step2Item.clientName,
            projectName: step2Item.projectName,
            prestationTitle: step2Item.prestationTitle,
            period: period,
            sentToEmail: item.email,
            bdcNumber: "VIV-PO-${step1Item.providerId}-${_selectedMonth.toString().padLeft(2, '0')}${_selectedYear.toString().substring(2)}",
            uoCount: step2Item.uoCount.toDouble(),
            totalHt: step2Item.totalHt,
            pdfBytes: pdfBytes,
          );

          // Mettre à jour immédiatement en mémoire pour que la phase 1 soit à jour
          step1Item.isAlreadySent = true;
          final now = DateTime.now();
          step1Item.sentDate = "${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}";
          step1Item.isSelected = false;

          setState(() {
            item.status = 'success';
            item.errorMessage = null;
          });
        } catch (e) {
          setState(() {
            item.status = 'failed';
            item.errorMessage = "Échec persistant : $e";
          });
        }
      }
    }

    setState(() {
      _isSendingMails = false;
    });

    if (!mounted) return;

    final allSuccess = _smtpStatusList.every((m) => m.status == 'success');
    if (allSuccess) {
      ShadToaster.of(context).show(
        const ShadToast(
          title: Text("Tout a été envoyé !"),
          description: Text("Les échecs ont été résolus et distribués."),
          backgroundColor: Colors.teal,
        ),
      );
    }
  }

  void _showRulesModal() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VivSpacing.radiusLg)),
        child: SizedBox(
          width: 1000,
          height: 700,
          child: BdcRulesDiagnosticScreen(
            onClose: () => Navigator.of(context).pop(),
          ),
        ),
      ),
    );
  }

  // --- RENDU GRAPHIQUE ---

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final stats = ref.watch(dashboardProvider);

    if (settings.boondUser.isEmpty) {
      return _buildEmptySettingsWidget();
    }

    return Scaffold(
      backgroundColor: VivColors.offWhite,
      body: Column(
        children: [
          // 1. TOPBAR : Barre d'onglets Stepper
          _buildTopbarStepper(),

          // 2. SOUS-EN-TÊTE : Période et Agence (descendu dans la page)
          _buildPeriodAndAgencyHeader(stats),

          // 3. CONTENU : TabBarView glissant
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(VivSpacing.space6, 0, VivSpacing.space6, VivSpacing.space6),
              child: TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(), // Navigation forcée par les boutons ou onglets autorisés
                children: [
                  _buildStep1Widget(),
                  _buildStep2Widget(),
                  _buildStep3Widget(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySettingsWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(VivSpacing.space8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(LucideIcons.shieldAlert, color: Colors.orangeAccent, size: 48),
            const SizedBox(height: 16),
            Text(
              "Identifiants requis",
              style: VivTypography.h4.copyWith(color: VivColors.gray500),
            ),
            const SizedBox(height: 8),
            const Text(
              "Veuillez configurer votre accès BoondManager dans les paramètres de l'application.",
              style: VivTypography.small,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopbarStepper() {
    return Container(
      decoration: const BoxDecoration(
        color: VivColors.paper,
        border: Border(bottom: BorderSide(color: VivColors.gray200)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          const SizedBox(width: VivSpacing.space6),
          _buildTabButton(0, "1. Détection & Conformité"),
          const SizedBox(width: 8),
          _buildTabButton(1, "2. Calculs & Audit PDF"),
          const SizedBox(width: 8),
          _buildTabButton(2, "3. Envoi & Suivi SMTP"),
        ],
      ),
    );
  }

  Widget _buildTabButton(int index, String label) {
    final bool isSelected = _tabController.index == index;
    final bool isUnlocked = index <= _maxUnlockedStep;

    return GestureDetector(
      onTap: () {
        if (isUnlocked) {
          _tabController.animateTo(index);
          setState(() {});
        } else {
          ShadToaster.of(context).show(
            const ShadToast.destructive(
              title: Text("Accès restreint"),
              description: Text("Veuillez d'abord compléter les étapes précédentes."),
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? Colors.black : Colors.transparent,
              width: 2.0,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 13,
            color: isSelected 
                ? Colors.black 
                : (isUnlocked ? VivColors.gray500 : VivColors.gray300),
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodAndAgencyHeader(dynamic stats) {
    final agencyName = stats.selectedAgencyName ?? "Toutes";

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: VivSpacing.space6, vertical: VivSpacing.space4),
      child: Row(
        children: [
          Row(
            children: [
              const Text("PÉRIODE : ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: VivColors.gray400)),
              const SizedBox(width: 8),
              SizedBox(
                width: 120,
                child: ShadSelect<String>(
                  initialValue: _selectedMonth,
                  options: const [
                    ShadOption(value: '08', child: Text("Août")),
                    ShadOption(value: '09', child: Text("Septembre")),
                  ],
                  selectedOptionBuilder: (context, value) => Text(value == '08' ? 'Août' : 'Septembre'),
                  onChanged: (val) {
                    setState(() {
                      _selectedMonth = val ?? '08';
                      if (!_isCurrentPeriodDetected) {
                        _maxUnlockedStep = 0;
                        _tabController.index = 0;
                      }
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 90,
                child: ShadSelect<String>(
                  initialValue: _selectedYear,
                  options: const [ShadOption(value: '2026', child: Text("2026"))],
                  selectedOptionBuilder: (context, value) => Text(value),
                  onChanged: (val) {
                    setState(() {
                      _selectedYear = val ?? '2026';
                      if (!_isCurrentPeriodDetected) {
                        _maxUnlockedStep = 0;
                        _tabController.index = 0;
                      }
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(width: 24),
          Row(
            children: [
              const Text("AGENCE : ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: VivColors.gray400)),
              const SizedBox(width: 8),
              ShadBadge(
                backgroundColor: VivColors.gray100,
                foregroundColor: Colors.black,
                child: Text(agencyName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
              ),
            ],
          ),
          const Spacer(),
          if (_tabController.index == 0)
            Row(
              children: [
                if (_isCurrentPeriodDetected) ...[
                  ShadButton.outline(
                    onPressed: _isLoadingDetection 
                        ? null 
                        : () async {
                            // Invalider le cache API BoondManager local
                            await BoondCacheService().clear();
                            _runDetection();
                          },
                    child: _isLoadingDetection
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                        : const Row(
                            children: [
                              Icon(LucideIcons.rotateCw, size: 14, color: Colors.black),
                              SizedBox(width: 8),
                              Text("Actualiser", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                            ],
                          ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (!_isCurrentPeriodDetected)
                  ShadButton(
                    backgroundColor: Colors.black,
                    onPressed: _runDetection,
                    child: _isLoadingDetection
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text("Détecter les prestations", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildDetectionWelcomeWidget(dynamic stats) {
    final agencyName = stats.selectedAgencyName ?? "votre agence";

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(LucideIcons.search, color: VivColors.gray200, size: 64),
          const SizedBox(height: 20),
          Text(
            "Aucune détection en cours",
            style: VivTypography.body.copyWith(fontWeight: FontWeight.w600, color: VivColors.gray500),
          ),
          const SizedBox(height: 8),
          Text(
            "Recherchez et filtrez les prestations d'achats sous-traitées actives sur $agencyName.",
            style: VivTypography.small.copyWith(color: VivColors.gray400),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // --- ÉTAPE 1 : LISTE DE DÉTECTION & CONFORMITÉ ---

  Widget _buildStep1Widget() {
    final stats = ref.read(dashboardProvider);
    if (!_isCurrentPeriodDetected) {
      return _buildDetectionWelcomeWidget(stats);
    }

    // Extraire les clients et les projets uniques pour alimenter les listes déroulantes de filtrage
    final clients = _step1Candidates.map((c) => c.clientName).toSet().toList();
    final projects = _step1Candidates.map((c) => c.projectName).toSet().toList();

    // Filtrer la liste en fonction des critères de recherche et filtres
    final filteredList = _step1Candidates.where((c) {
      final matchesSearch = c.consultantName.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesClient = _filterClient == null || c.clientName == _filterClient;
      final matchesProject = _filterProject == null || c.projectName == _filterProject;
      return matchesSearch && matchesClient && matchesProject;
    }).toList();

    final selectedCount = filteredList.where((c) => c.isSelected).length;

    return Column(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: VivColors.paper,
              borderRadius: BorderRadius.circular(VivSpacing.radiusLg),
              border: Border.all(color: VivColors.gray200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(VivSpacing.space4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            "PRESTATIONS DETECTÉES SUR LA PÉRIODE",
                            style: VivTypography.small.copyWith(fontWeight: FontWeight.bold, color: VivColors.gray500),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                for (var c in filteredList) {
                                  c.isSelected = true;
                                }
                              });
                            },
                            child: const Text("Tout cocher", style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(
                            height: 12,
                            child: VerticalDivider(width: 16, color: VivColors.gray300),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                for (var c in filteredList) {
                                  c.isSelected = false;
                                }
                              });
                            },
                            child: const Text("Tout décocher", style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(
                            height: 12,
                            child: VerticalDivider(width: 16, color: VivColors.gray300),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                for (var c in filteredList) {
                                  if (c.alertMessage != null) {
                                    c.isSelected = false;
                                  }
                                }
                              });
                            },
                            child: const Text("Décocher les non conformes", style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: ShadInput(
                              placeholder: const Text("Rechercher une ressource..."),
                              leading: const Padding(
                                padding: EdgeInsets.only(right: 8.0),
                                child: Icon(LucideIcons.search, size: 16, color: VivColors.gray400),
                              ),
                              initialValue: _searchQuery,
                              onChanged: (val) => setState(() => _searchQuery = val),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ShadSelect<String>(
                              placeholder: const Text("Tous les clients"),
                              initialValue: _filterClient,
                              options: [
                                ShadOption(value: '', child: const Text("Tous les clients")),
                                ...clients.map((c) => ShadOption(value: c, child: Text(c))),
                              ],
                              selectedOptionBuilder: (context, value) => Text(value.isEmpty ? "Tous les clients" : value),
                              onChanged: (val) => setState(() => _filterClient = (val == null || val.isEmpty) ? null : val),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ShadSelect<String>(
                              placeholder: const Text("Tous les projets"),
                              initialValue: _filterProject,
                              options: [
                                ShadOption(value: '', child: const Text("Tous les projets")),
                                ...projects.map((p) => ShadOption(value: p, child: Text(p))),
                              ],
                              selectedOptionBuilder: (context, value) => Text(value.isEmpty ? "Tous les projets" : value),
                              onChanged: (val) => setState(() => _filterProject = (val == null || val.isEmpty) ? null : val),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: VivColors.gray200),
                Expanded(
                  child: filteredList.isEmpty
                      ? const Center(
                          child: Text(
                            "Aucune ressource ne correspond aux filtres de recherche.",
                            style: TextStyle(color: VivColors.gray400, fontSize: 13),
                          ),
                        )
                      : ListView.separated(
                          itemCount: filteredList.length,
                          separatorBuilder: (c, i) => const Divider(height: 1, color: VivColors.gray200),
                          itemBuilder: (context, index) {
                            final item = filteredList[index];
                            final hasAlert = item.alertMessage != null;

                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              color: item.isSelected ? Colors.white : Colors.grey.shade50.withAlpha((0.5 * 255).round()),
                              child: Row(
                                children: [
                                  Checkbox(
                                    value: item.isSelected,
                                    activeColor: Colors.black,
                                    onChanged: (val) {
                                      setState(() {
                                        item.isSelected = val ?? false;
                                      });
                                    },
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    flex: 3,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(item.consultantName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                        const SizedBox(height: 2),
                                        Text(item.title, style: const TextStyle(fontSize: 12, color: VivColors.gray400)),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(item.clientName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                        const SizedBox(height: 2),
                                        Text(item.projectName, style: const TextStyle(fontSize: 11, color: VivColors.gray400)),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(item.providerName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                        const SizedBox(height: 2),
                                        Text(item.providerId, style: const TextStyle(fontSize: 11, color: VivColors.gray400)),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    flex: 4,
                                    child: hasAlert
                                        ? Row(
                                            children: [
                                              const Icon(LucideIcons.circleAlert, color: Colors.redAccent, size: 16),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  item.alertMessage!,
                                                  style: const TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.w500),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              OutlinedButton(
                                                style: OutlinedButton.styleFrom(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  side: const BorderSide(color: Colors.redAccent),
                                                  minimumSize: Size.zero,
                                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                ),
                                                onPressed: () {
                                                  ShadToaster.of(context).show(
                                                    ShadToast(
                                                      title: const Text("Redirection BoondManager"),
                                                      description: Text("Ouverture de l'URL : ${item.boondLink}"),
                                                    ),
                                                  );
                                                },
                                                child: const Text("Corriger", style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                                              ),
                                            ],
                                          )
                                        : item.isAlreadySent
                                            ? Row(
                                                children: [
                                                  const Icon(LucideIcons.mailCheck, color: Colors.blueAccent, size: 16),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      "Déjà envoyé (${item.sentDate})",
                                                      style: const TextStyle(
                                                        color: Colors.blueAccent,
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  OutlinedButton(
                                                    style: OutlinedButton.styleFrom(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                      side: const BorderSide(color: Colors.blueAccent),
                                                      minimumSize: Size.zero,
                                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                    ),
                                                    onPressed: () {
                                                      _viewHistoricalPdf(item.providerId);
                                                    },
                                                    child: const Row(
                                                      children: [
                                                        Icon(LucideIcons.eye, size: 10, color: Colors.blueAccent),
                                                        SizedBox(width: 4),
                                                        Text("Historique", style: TextStyle(color: Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              )
                                            : const Row(
                                                children: [
                                                  Icon(LucideIcons.check, color: Colors.teal, size: 16),
                                                  SizedBox(width: 8),
                                                  Text("Fiche administrative conforme", style: TextStyle(color: Colors.teal, fontSize: 11)),
                                                ],
                                              ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(LucideIcons.signature, size: 16, color: VivColors.gray500),
                const SizedBox(width: 8),
                Text(
                  "$selectedCount bons de commande à générer",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: VivColors.gray500),
                ),
              ],
            ),
            ShadButton(
              backgroundColor: Colors.black,
              onPressed: filteredList.any((c) => c.isSelected) ? () => _calculateSelected(filteredList) : null,
              child: const Row(
                children: [
                  Text("Étape suivante : Calculer les UO & Tarifs", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  SizedBox(width: 8),
                  Icon(LucideIcons.arrowRight, size: 16, color: Colors.white),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // --- ÉTAPE 2 : CALCULS & AUDIT PDF ---

  Widget _buildStep2Widget() {
    final totalAmount = _step2Calculated.fold<double>(0, (sum, item) => sum + item.totalHt);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(LucideIcons.calculator, size: 18, color: VivColors.gray500),
                const SizedBox(width: 8),
                Text(
                  "REVUE DU CALCUL ET DES DOCUMENTS PDF",
                  style: VivTypography.small.copyWith(fontWeight: FontWeight.bold, color: VivColors.gray500),
                ),
              ],
            ),
            ShadButton.outline(
              onPressed: _showRulesModal,
              child: const Row(
                children: [
                  Icon(LucideIcons.settings, size: 14, color: Colors.black),
                  SizedBox(width: 8),
                  Text("Règles Spécifiques", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: VivColors.paper,
              borderRadius: BorderRadius.circular(VivSpacing.radiusLg),
              border: Border.all(color: VivColors.gray200),
            ),
            child: ListView.separated(
              itemCount: _step2Calculated.length,
              separatorBuilder: (c, i) => const Divider(height: 1, color: VivColors.gray200),
              itemBuilder: (context, index) {
                final item = _step2Calculated[index];

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.consultantName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(height: 2),
                            Text(item.projectName, style: const TextStyle(fontSize: 12, color: VivColors.gray400)),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.clientName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            const SizedBox(height: 4),
                            if (item.appliedRule != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blueAccent.withAlpha((0.1 * 255).round()),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  item.appliedRule!,
                                  style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 10),
                                ),
                              )
                            else
                              const Text("Calcul standard", style: TextStyle(color: VivColors.gray400, fontSize: 11)),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("${item.tjm.toStringAsFixed(0)} € HT", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 2),
                            Text("${item.uoCount} UO (${item.calculationMode})", style: const TextStyle(fontSize: 11, color: VivColors.gray400)),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          "${item.totalHt.toStringAsFixed(0)} € HT",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                      // Zone Action PDF
                      Row(
                        children: [
                          OutlinedButton.icon(
                            icon: const Icon(LucideIcons.eye, size: 14, color: Colors.black),
                            label: const Text("Visualiser", style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold)),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              side: const BorderSide(color: VivColors.gray200),
                            ),
                            onPressed: () => _viewPdf(item),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(LucideIcons.download, size: 16, color: VivColors.gray500),
                            onPressed: () => _downloadPdf(item),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            OutlinedButton.icon(
              icon: const Icon(LucideIcons.arrowLeft, size: 16),
              label: const Text("Retour détection", style: TextStyle(fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.black,
                side: const BorderSide(color: VivColors.gray200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onPressed: () => setState(() => _tabController.animateTo(0)),
            ),
            Row(
              children: [
                Text("TOTAL SIMULÉ : ", style: VivTypography.small.copyWith(fontWeight: FontWeight.bold, color: VivColors.gray400)),
                Text("${totalAmount.toStringAsFixed(0)} € HT", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.teal)),
                const SizedBox(width: 24),
                ShadButton(
                  backgroundColor: Colors.teal,
                  onPressed: _prepareSmtp,
                  child: const Row(
                    children: [
                      Text("Étape suivante : Préparer l'envoi", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      SizedBox(width: 8),
                      Icon(LucideIcons.arrowRight, size: 16, color: Colors.white),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  // --- ÉTAPE 3 : ENVOI & SUIVI SMTP ---

  Widget _buildStep3Widget() {
    final failedMailsCount = _smtpStatusList.where((m) => m.status == 'failed').length;
    final successMailsCount = _smtpStatusList.where((m) => m.status == 'success').length;

    return Column(
      children: [
        Row(
          children: [
            const Icon(LucideIcons.send, size: 18, color: VivColors.gray500),
            const SizedBox(width: 8),
            Text(
              "DISTRIBUTION ET STATUT DES ENVOIS",
              style: VivTypography.small.copyWith(fontWeight: FontWeight.bold, color: VivColors.gray500),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: VivColors.paper,
              borderRadius: BorderRadius.circular(VivSpacing.radiusLg),
              border: Border.all(color: VivColors.gray200),
            ),
            child: ListView.separated(
              itemCount: _smtpStatusList.length,
              separatorBuilder: (c, i) => const Divider(height: 1, color: VivColors.gray200),
              itemBuilder: (context, index) {
                final mail = _smtpStatusList[index];

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(mail.consultantName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(height: 2),
                            Text(mail.providerName, style: const TextStyle(fontSize: 12, color: VivColors.gray400)),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(mail.email, style: const TextStyle(fontSize: 13, color: VivColors.gray500)),
                      ),
                      Expanded(
                        flex: 4,
                        child: _buildSmtpBadge(mail),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (!_isSendingMails)
              OutlinedButton.icon(
                icon: const Icon(LucideIcons.arrowLeft, size: 16),
                label: const Text("Retour calculs", style: TextStyle(fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.black,
                  side: const BorderSide(color: VivColors.gray200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onPressed: () => setState(() => _tabController.animateTo(1)),
              )
            else
              const SizedBox.shrink(),
            Row(
              children: [
                if (failedMailsCount > 0 && !_isSendingMails) ...[
                  ShadButton(
                    backgroundColor: Colors.red.shade600,
                    onPressed: _retryFailedMails,
                    child: Row(
                      children: [
                        const Icon(LucideIcons.refreshCw, size: 14, color: Colors.white),
                        const SizedBox(width: 8),
                        Text("Renvoyer uniquement les échecs ($failedMailsCount)", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                 if (successMailsCount == _smtpStatusList.length && !_isSendingMails)
                  ShadButton(
                    backgroundColor: Colors.black,
                    onPressed: () async {
                      // Réinitialiser la liste
                      _resetStep1Data();
                      
                      // Charger de manière asynchrone les logs d'envoi de la base
                      final period = '$_selectedMonth/$_selectedYear';
                      final logsService = BdcSentLogsService();
                      
                      for (var candidate in _step1Candidates) {
                        final log = await logsService.getSentLog(candidate.providerId, period);
                        if (log != null) {
                          candidate.isAlreadySent = true;
                          final sentAtStr = log['sentAt'] as String?;
                          if (sentAtStr != null) {
                            final sentAt = DateTime.parse(sentAtStr);
                            candidate.sentDate = "${sentAt.day.toString().padLeft(2, '0')}/${sentAt.month.toString().padLeft(2, '0')}/${sentAt.year}";
                          }
                          candidate.isSelected = false;
                        }
                      }
                      
                      if (mounted) {
                        setState(() {
                          _maxUnlockedStep = 0;
                          _tabController.animateTo(0);
                        });
                      }
                    },
                    child: const Text("Terminer la session", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  )
                else if (!_isSendingMails)
                  ShadButton(
                    backgroundColor: Colors.teal,
                    onPressed: _startSendingMails,
                    child: const Row(
                      children: [
                        Icon(LucideIcons.send, size: 16, color: Colors.white),
                        SizedBox(width: 8),
                        Text("Lancer l'envoi SMTP global", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSmtpBadge(BdcMailStatus mail) {
    switch (mail.status) {
      case 'pending':
        return const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.circle, color: VivColors.gray300, size: 14),
            SizedBox(width: 8),
            Text("En attente de traitement", style: TextStyle(color: VivColors.gray400, fontSize: 12)),
          ],
        );
      case 'generating':
        return const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orangeAccent)),
            SizedBox(width: 8),
            Text("Génération du document PDF...", style: TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        );
      case 'sending':
        return const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blueAccent)),
            SizedBox(width: 8),
            Text("Négociation SMTP & Expédition...", style: TextStyle(color: Colors.blueAccent, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        );
      case 'success':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.teal.withAlpha((0.1 * 255).round()),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Row(
                children: [
                  Icon(LucideIcons.check, color: Colors.teal, size: 12),
                  SizedBox(width: 6),
                  Text("Envoyé & Archivés avec succès", style: TextStyle(color: Colors.teal, fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        );
      case 'failed':
        return Tooltip(
          message: mail.errorMessage ?? "Erreur inconnue",
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.redAccent.withAlpha((0.1 * 255).round()),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.x, color: Colors.redAccent, size: 12),
                SizedBox(width: 6),
                Text("Échec de l'envoi (Survoler pour voir l'erreur)", style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  void _viewPdf(BdcPrestaStep2 item) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.7,
          height: MediaQuery.of(context).size.height * 0.8,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Aperçu du Bon de commande : ${item.consultantName}",
                    style: VivTypography.h4.copyWith(fontSize: 16),
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.x, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: PdfPreview(
                  build: (format) => BdcPdfService.generateBdcPdf(item, _selectedMonth, _selectedYear),
                  allowPrinting: false,
                  allowSharing: false,
                  canChangePageFormat: false,
                  canChangeOrientation: false,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _downloadPdf(BdcPrestaStep2 item) async {
    try {
      final bytes = await BdcPdfService.generateBdcPdf(item, _selectedMonth, _selectedYear);
      final filename = 'BDC_${item.consultantName.replaceAll(' ', '_')}.pdf';
      await Printing.sharePdf(bytes: bytes, filename: filename);
      
      if (mounted) {
        ShadToaster.of(context).show(
          ShadToast(
            title: const Text("Téléchargement"),
            description: Text("Fichier $filename téléchargé avec succès."),
            backgroundColor: Colors.teal,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ShadToaster.of(context).show(
          ShadToast.destructive(
            title: const Text("Erreur de téléchargement"),
            description: Text(e.toString()),
          ),
        );
      }
    }
  }

  void _viewHistoricalPdf(String providerId) async {
    final period = '$_selectedMonth/$_selectedYear';
    final logsService = BdcSentLogsService();
    final log = await logsService.getSentLog(providerId, period);
    
    if (log != null) {
      final pdfPath = log['pdfPath'] as String?;
      if (pdfPath != null) {
        final file = File(pdfPath);
        if (file.existsSync()) {
          final bytes = await file.readAsBytes();
          
          if (!mounted) return;
          
          showDialog(
            context: context,
            builder: (context) => Dialog(
              child: Container(
                width: 900,
                height: 700,
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Archive PDF : ${log['consultantName']} (${log['bdcNumber']})",
                          style: VivTypography.h4.copyWith(fontSize: 16),
                        ),
                        IconButton(
                          icon: const Icon(LucideIcons.x, size: 20),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const Divider(),
                    Expanded(
                      child: PdfPreview(
                        build: (format) => bytes,
                        allowPrinting: false,
                        allowSharing: false,
                        canChangePageFormat: false,
                        canChangeOrientation: false,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        } else {
          if (!mounted) return;
          ShadToaster.of(context).show(
            const ShadToast.destructive(
              title: Text("Fichier manquant"),
              description: Text("Le fichier PDF physique n'a pas été trouvé sur le disque."),
            ),
          );
        }
      }
    }
  }
}
