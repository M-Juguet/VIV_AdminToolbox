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
import '../services/boond_service.dart';
import '../services/calendar_service.dart';
import '../services/email_service.dart';
import '../services/bdc_rules_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

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
  final double tjmAchat;
  final double quantitySold;
  final String? consultantTitle;
  final String clientCsoc;
  final String projectId;
  final String providerEmail;
  final String? providerContactId;
  final String? purchaseId;
  
  // Nouveaux champs d'adresses et dates réelles
  final String providerAddress;
  final String providerPostcode;
  final String providerTown;
  final String providerCountry;
  final String startDate;
  final String endDate;
  final String prestationRef;
  final String projectRef;

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
    required this.tjmAchat,
    required this.quantitySold,
    this.consultantTitle,
    required this.clientCsoc,
    required this.projectId,
    required this.providerEmail,
    this.providerContactId,
    this.purchaseId,
    required this.providerAddress,
    required this.providerPostcode,
    required this.providerTown,
    required this.providerCountry,
    required this.startDate,
    required this.endDate,
    required this.prestationRef,
    required this.projectRef,
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
  
  // Nouveaux champs pour les vraies données Boond
  final String providerId;
  final String providerName;
  final String providerAddress;
  final String providerPostcode;
  final String providerTown;
  final String providerCountry;
  final String? purchaseId;
  final String startDate;
  final String endDate;
  final String prestationRef;

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
    required this.providerId,
    required this.providerName,
    required this.providerAddress,
    required this.providerPostcode,
    required this.providerTown,
    required this.providerCountry,
    this.purchaseId,
    required this.startDate,
    required this.endDate,
    required this.prestationRef,
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
  final Set<String> _loadingItems = {};

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
  List<String> _holidays = [];

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
    _step1Candidates = [];
  }

  // --- ACTIONS DU FLUX ---

  void _runDetection() async {
    setState(() {
      _isLoadingDetection = true;
    });

    final period = '$_selectedMonth/$_selectedYear';
    final logsService = BdcSentLogsService();
    final service = ref.read(boondServiceProvider);
    final settings = ref.read(settingsProvider);

    final List<BdcPrestaStep1> detectedCandidates = [];

    try {
      // 0. Charger les jours fériés pour l'année sélectionnée
      final yearInt = int.tryParse(_selectedYear) ?? DateTime.now().year;
      _holidays = await service.getHolidays(yearInt);

      // 1. Récupérer les projets actifs
      final response = await service.getProjectsWithInclusions(
        filters: {'states[]': 1}, // Projets actifs
        inclusions: ['company'],
      );
      final projects = response['data'] as List? ?? [];
      final included = response['included'] as List? ?? [];

      // Mapper les ID d'entreprises (clients) vers leurs noms pour la résolution rapide
      final Map<String, String> companyNames = {};
      for (var item in included) {
        if (item['type'] == 'company' || item['type'] == 'companies') {
          final id = item['id']?.toString() ?? '';
          final name = item['attributes']?['name']?.toString() ?? 'Société sans nom';
          companyNames[id] = name;
        }
      }

      // 2. Parcourir les projets et charger leurs prestations de sous-traitance
      for (var p in projects) {
        final projectIdStr = p['id']?.toString() ?? '';
        final projectId = int.tryParse(projectIdStr);
        if (projectId == null) continue;

        final projectName = p['attributes']?['reference']?.toString() ?? 'Projet sans nom';
        final projectRef = "PRJ$projectIdStr";
        final clientRel = p['relationships']?['company']?['data'];
        final clientId = clientRel?['id']?.toString();
        final clientName = companyNames[clientId] ?? 'Client inconnu';

        // Récupérer les prestations du projet
        final List<dynamic> deliveries = await service.getDeliveries(projectId);
        
        final monthInt = int.tryParse(_selectedMonth) ?? DateTime.now().month;
        final yearInt = int.tryParse(_selectedYear) ?? DateTime.now().year;
        final startOfPeriod = DateTime(yearInt, monthInt, 1);
        final endOfPeriod = monthInt == 12 ? DateTime(yearInt + 1, 1, 0) : DateTime(yearInt, monthInt + 1, 0);

        for (var delivery in deliveries) {
          final delId = delivery['id']?.toString() ?? '';
          final delAttr = delivery['attributes'] ?? {};
          final delTitle = delAttr['title']?.toString() ?? 'Prestation sans titre';
          
          final startDateStr = delAttr['startDate']?.toString();
          final endDateStr = delAttr['endDate']?.toString();
          
          if (startDateStr != null && endDateStr != null) {
            final startDate = DateTime.tryParse(startDateStr);
            final endDate = DateTime.tryParse(endDateStr);
            if (startDate != null && endDate != null) {
              if (endDate.isBefore(startOfPeriod) || startDate.isAfter(endOfPeriod)) {
                // La prestation ne se superpose pas avec le mois sélectionné, on l'ignore
                continue;
              }
            }
          }
          
          final dependsOn = delivery['relationships']?['dependsOn']?['data'];
          final purchaseRel = delivery['relationships']?['purchase']?['data'];

          // Résoudre la ressource et vérifier si elle est externe (typeOf == 1)
          bool isExternalResource = false;
          String resourceName = "Inconnu";
          String? consultantTitle;
          
          if (dependsOn != null) {
            final resId = int.tryParse(dependsOn['id']?.toString() ?? '');
            if (resId != null) {
              try {
                final res = await service.getResource(resId);
                final rAttr = res['attributes'] ?? {};
                resourceName = "${rAttr['firstName'] ?? ''} ${rAttr['lastName'] ?? ''}".trim();
                consultantTitle = rAttr['title']?.toString() ?? rAttr['function']?.toString();
                // typeOf = 1 pour ressource externe (sous-traitant)
                if (rAttr['typeOf'] == 1) {
                  isExternalResource = true;
                }
              } catch (_) {}
            }
          }

          // Si ce n'est pas un consultant externe ET qu'il n'y a pas d'achat lié, on l'ignore (salarié normal)
          if (!isExternalResource && purchaseRel == null) {
            continue;
          }

          // Résoudre l'achat et les infos fournisseur (Company + Contact)
          String providerName = "Aucun";
          String providerId = "Aucun";
          String? alertMessage;
          String contactEmail = "";
          String? providerContactId;
          String? purchaseIdStr;

          if (purchaseRel == null) {
            alertMessage = "Aucun achat associé à la prestation.";
          } else {
            final purchaseId = int.tryParse(purchaseRel['id']?.toString() ?? '');
            purchaseIdStr = purchaseId?.toString();
            if (purchaseId != null) {
              try {
                // Récupère l'achat avec inclusions de la société fournisseur et du contact fournisseur
                final pResponse = await service.getPurchaseWithInclusions(purchaseId);
                final pIncluded = pResponse['included'] as List? ?? [];
                
                // 1. Trouver l'entité Société (Company) dans included
                final compObj = pIncluded.firstWhere(
                  (item) => item['type'] == 'companies' || item['type'] == 'company',
                  orElse: () => null,
                );
                if (compObj != null) {
                  providerName = compObj['attributes']?['name']?.toString() ?? 'Société sans nom';
                  providerId = compObj['id']?.toString() ?? '';
                }

                // 2. Trouver l'entité Contact (providerContact) dans included
                final contactObj = pIncluded.firstWhere(
                  (item) => item['type'] == 'contacts' || item['type'] == 'contact',
                  orElse: () => null,
                );
                if (contactObj != null) {
                  providerContactId = contactObj['id']?.toString();
                  final cAttr = contactObj['attributes'] ?? {};
                  contactEmail = (cAttr['email'] ??
                          cAttr['email1'] ??
                          cAttr['emailOne'] ??
                          cAttr['emailPro'] ??
                          '')
                      .toString();
                } else if (providerId != "Aucun" && providerId.isNotEmpty) {
                  // Fallback : charger les contacts de la société fournisseur si non lié sur l'achat
                  final companyIdInt = int.tryParse(providerId);
                  if (companyIdInt != null) {
                    try {
                      final contactsList = await service.getCompanyContacts(companyIdInt);
                      if (contactsList.isEmpty) {
                        alertMessage = "Aucun contact administratif renseigné pour le fournisseur";
                      } else if (contactsList.length == 1) {
                        // Dans le cas où un seul contact est disponible : le récupérer et vérifier l'email
                        final singleContact = contactsList.first;
                        providerContactId = singleContact['id']?.toString();
                        final cAttr = singleContact['attributes'] ?? {};
                        contactEmail = (cAttr['email'] ??
                                cAttr['email1'] ??
                                cAttr['emailOne'] ??
                                cAttr['emailPro'] ??
                                '')
                            .toString();
                      } else {
                        // Dans le cas où plusieurs contacts sont disponibles : filtrage par état "Fournisseur"
                        final dict = await service.getDictionary();
                        final contactStates = dict['data']?['setting']?['state']?['contact'] as List? ?? [];
                        int? supplierStateId;
                        for (var state in contactStates) {
                          final label = state['label']?.toString().toLowerCase() ?? '';
                          if (label.contains('fournisseur')) {
                            supplierStateId = int.tryParse(state['id']?.toString() ?? '');
                            break;
                          }
                        }

                        final supplierContacts = contactsList.where((c) {
                          final stateVal = int.tryParse(c['attributes']?['state']?.toString() ?? '');
                          return stateVal != null && stateVal == supplierStateId;
                        }).toList();

                        if (supplierContacts.isEmpty) {
                          alertMessage = "Aucun contact avec l'état 'Fournisseur' parmi les contacts trouvés";
                        } else if (supplierContacts.length > 1) {
                          alertMessage = "Plusieurs contacts avec l'état 'Fournisseur' détectés.";
                        } else {
                          // Un seul contact a l'état "Fournisseur"
                          final selectedContact = supplierContacts.first;
                          providerContactId = selectedContact['id']?.toString();
                          final cAttr = selectedContact['attributes'] ?? {};
                          contactEmail = (cAttr['email'] ??
                                  cAttr['email1'] ??
                                  cAttr['emailOne'] ??
                                  cAttr['emailPro'] ??
                                  '')
                              .toString();
                        }
                      }
                    } catch (_) {}
                  }
                }
                
                // Définir le message d'alerte global si non défini ci-dessus
                if (alertMessage == null) {
                  if (providerId == "Aucun" || providerId.isEmpty) {
                    alertMessage = "Aucun fournisseur lié à l'achat de prestation.";
                  } else if (providerContactId == null || providerContactId.isEmpty) {
                    alertMessage = "Aucun contact administratif renseigné pour le fournisseur";
                  } else if (contactEmail.isEmpty || !contactEmail.contains('@')) {
                    alertMessage = "E-mail de contact non renseigné";
                  }
                }
              } catch (e) {
                alertMessage = "Impossible de récupérer les informations fournisseur : $e";
              }
            } else {
              alertMessage = "Aucun achat associé.";
            }
          }

          // Résoudre l'adresse complète du fournisseur si providerId est connu
          String providerAddress = "Non renseignée";
          String providerPostcode = "";
          String providerTown = "";
          String providerCountry = "";
          if (providerId != "Aucun" && providerId.isNotEmpty) {
            final compIdInt = int.tryParse(providerId);
            if (compIdInt != null) {
              try {
                final companyInfo = await service.getCompanyInformation(compIdInt);
                final cAttr = companyInfo['attributes'] ?? {};
                providerAddress = cAttr['address']?.toString() ?? 'Non renseignée';
                providerPostcode = cAttr['postcode']?.toString() ?? '';
                providerTown = cAttr['town']?.toString() ?? '';
                providerCountry = cAttr['country']?.toString() ?? '';
              } catch (_) {}
            }
          }

          // Résoudre la référence (ex: MIS31) avec fallback sur "MIS$delId"
          final String delRef = delAttr['reference']?.toString() ?? "MIS$delId";
          final String delTitleWithRef = "$delRef - $delTitle";

          // Borner les dates au mois sélectionné si elles dépassent
          DateTime finalStartDate = startOfPeriod;
          DateTime finalEndDate = endOfPeriod;

          if (startDateStr != null && endDateStr != null) {
            final startDate = DateTime.tryParse(startDateStr);
            final endDate = DateTime.tryParse(endDateStr);
            if (startDate != null && endDate != null) {
              if (startDate.isAfter(startOfPeriod)) {
                finalStartDate = startDate;
              }
              if (endDate.isBefore(endOfPeriod)) {
                finalEndDate = endDate;
              }
            }
          }

          final String displayStartDate = "${finalStartDate.day.toString().padLeft(2, '0')}/${finalStartDate.month.toString().padLeft(2, '0')}/${finalStartDate.year}";
          final String displayEndDate = "${finalEndDate.day.toString().padLeft(2, '0')}/${finalEndDate.month.toString().padLeft(2, '0')}/${finalEndDate.year}";

          // Extraire la quantité vendue et calculer le TJM d'achat
          final double quantitySold = double.tryParse(delAttr['numberOfDaysInvoicedOrQuantity']?.toString() ?? '0') ?? 0;
          final double costsSimulated = double.tryParse(delAttr['costsSimulatedExcludingTax']?.toString() ?? '0') ?? 0;
          double averageDailyCost = 0;
          if (quantitySold > 0) {
            averageDailyCost = costsSimulated / quantitySold;
          }

           final candidate = BdcPrestaStep1(
            id: delId,
            consultantName: resourceName,
            providerName: providerName,
            providerId: providerId,
            projectName: projectName,
            clientName: clientName,
            title: delTitleWithRef,
            alertMessage: alertMessage,
            boondLink: "${settings.boondUrl.endsWith('/') ? settings.boondUrl : '${settings.boondUrl}/'}projects/$projectId/deliveries",
            isSelected: alertMessage == null, // Coché par défaut s'il n'y a pas d'alerte critique
            tjmAchat: averageDailyCost,
            quantitySold: quantitySold,
            consultantTitle: consultantTitle,
            clientCsoc: clientId ?? "",
            projectId: projectIdStr,
            providerEmail: contactEmail,
            providerContactId: providerContactId,
            purchaseId: purchaseIdStr,
            providerAddress: providerAddress,
            providerPostcode: providerPostcode,
            providerTown: providerTown,
            providerCountry: providerCountry,
            startDate: displayStartDate,
            endDate: displayEndDate,
            prestationRef: delRef,
            projectRef: projectRef,
          );

          // Vérifier si un doublon d'envoi existe en BDD locale
          final log = await logsService.getSentLog(candidate.providerId, period);
          if (log != null) {
            candidate.isAlreadySent = true;
            final sentAtStr = log['sentAt'] as String?;
            if (sentAtStr != null) {
              final sentAt = DateTime.parse(sentAtStr);
              candidate.sentDate = "${sentAt.day.toString().padLeft(2, '0')}/${sentAt.month.toString().padLeft(2, '0')}/${sentAt.year}";
            }
            candidate.isSelected = false; // Décoché par défaut si déjà envoyé
          }

          detectedCandidates.add(candidate);
        }
      }
      
      // Trier par ordre alphabétique du nom de la ressource
      detectedCandidates.sort((a, b) => a.consultantName.toLowerCase().compareTo(b.consultantName.toLowerCase()));

      if (mounted) {
        setState(() {
          _step1Candidates = detectedCandidates;
          _isLoadingDetection = false;
          _periodDetectionStatus[_currentPeriodKey] = true;
          _maxUnlockedStep = 0;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingDetection = false;
        });
        ShadToaster.of(context).show(
          ShadToast.destructive(
            title: const Text("Erreur de détection"),
            description: Text("Impossible de charger les données : $e"),
          ),
        );
      }
    }
  }

  Future<void> _refreshSingleCandidate(BdcPrestaStep1 item) async {
    setState(() {
      _loadingItems.add(item.id);
    });

    try {
      final service = ref.read(boondServiceProvider);
      final logsService = BdcSentLogsService();
      
      final projectId = int.parse(item.projectId);
      final deliveryId = item.id;

      // Charger les détails de la prestation en direct (sans cache ou avec forceRefresh)
      final List<dynamic> deliveries = await service.getDeliveries(projectId, forceRefresh: true);
      
      // Trouver notre delivery spécifique
      final delivery = deliveries.firstWhere(
        (d) => d['id']?.toString() == deliveryId,
        orElse: () => null,
      );

      if (delivery == null) {
        throw "Prestation non trouvée sur BoondManager.";
      }

      final delAttr = delivery['attributes'] ?? {};
      final delTitle = delAttr['title']?.toString() ?? 'Prestation sans titre';
      final delRef = delAttr['reference']?.toString() ?? "MIS$deliveryId";
      final delTitleWithRef = "$delRef - $delTitle";
      final purchaseRel = delivery['relationships']?['purchase']?['data'];

      // Résoudre le nom de la ressource
      final resourceRel = delivery['relationships']?['resource']?['data'];
      final resourceId = resourceRel?['id']?.toString() ?? '';
      String resourceName = "Ressource inconnue";
      String? consultantTitle;

      if (resourceId.isNotEmpty) {
        final resourceInt = int.tryParse(resourceId);
        if (resourceInt != null) {
          final resData = await service.getResource(resourceInt, forceRefresh: true);
          final resAttr = resData['attributes'] ?? {};
          final firstName = resAttr['firstName']?.toString() ?? '';
          final lastName = resAttr['lastName']?.toString() ?? '';
          resourceName = "$firstName $lastName".trim();
          consultantTitle = resAttr['title']?.toString();
        }
      }

      // Résoudre les infos fournisseur (Société + Contact)
      String providerName = "Aucun";
      String providerId = "Aucun";
      String? alertMessage;
      String contactEmail = "";
      String? providerContactId;
      String? purchaseIdStr;
      
      String providerAddress = "";
      String providerPostcode = "";
      String providerTown = "";
      String providerCountry = "";

      if (purchaseRel == null) {
        alertMessage = "Aucun Achat associé à la prestation.";
      } else {
        final purchaseId = int.tryParse(purchaseRel['id']?.toString() ?? '');
        purchaseIdStr = purchaseId?.toString();
        if (purchaseId != null) {
          final pResponse = await service.getPurchaseWithInclusions(purchaseId, forceRefresh: true);
          final pIncluded = pResponse['included'] as List? ?? [];
          
          final compObj = pIncluded.firstWhere(
            (i) => i['type'] == 'companies' || i['type'] == 'company',
            orElse: () => null,
          );
          if (compObj != null) {
            providerName = compObj['attributes']?['name']?.toString() ?? 'Société sans nom';
            providerId = compObj['id']?.toString() ?? '';
            
            final compIdInt = int.tryParse(providerId);
            if (compIdInt != null) {
              try {
                final compInfo = await service.getCompanyInformation(compIdInt, forceRefresh: true);
                final infoAttr = compInfo['attributes'] ?? {};
                providerAddress = infoAttr['address']?.toString() ?? '';
                providerPostcode = infoAttr['postcode']?.toString() ?? '';
                providerTown = infoAttr['town']?.toString() ?? '';
                providerCountry = infoAttr['country']?.toString() ?? '';
              } catch (_) {}
            }
          }

          final contactObj = pIncluded.firstWhere(
            (i) => i['type'] == 'contacts' || i['type'] == 'contact',
            orElse: () => null,
          );
          if (contactObj != null) {
            providerContactId = contactObj['id']?.toString();
            final cAttr = contactObj['attributes'] ?? {};
            contactEmail = (cAttr['email'] ??
                    cAttr['email1'] ??
                    cAttr['emailOne'] ??
                    cAttr['emailPro'] ??
                    '')
                .toString();
          } else if (providerId != "Aucun" && providerId.isNotEmpty) {
            final companyIdInt = int.tryParse(providerId);
            if (companyIdInt != null) {
              final contactsList = await service.getCompanyContacts(companyIdInt);
              if (contactsList.isEmpty) {
                alertMessage = "Aucun contact administratif renseigné pour le fournisseur";
              } else if (contactsList.length == 1) {
                final singleContact = contactsList.first;
                providerContactId = singleContact['id']?.toString();
                final cAttr = singleContact['attributes'] ?? {};
                contactEmail = (cAttr['email'] ??
                        cAttr['email1'] ??
                        cAttr['emailOne'] ??
                        cAttr['emailPro'] ??
                        '')
                    .toString();
              } else {
                final dict = await service.getDictionary(forceRefresh: true);
                final contactStates = dict['data']?['setting']?['state']?['contact'] as List? ?? [];
                int? supplierStateId;
                for (var state in contactStates) {
                  final label = state['label']?.toString().toLowerCase() ?? '';
                  if (label.contains('fournisseur')) {
                    supplierStateId = int.tryParse(state['id']?.toString() ?? '');
                    break;
                  }
                }

                final supplierContacts = contactsList.where((c) {
                  final stateVal = int.tryParse(c['attributes']?['state']?.toString() ?? '');
                  return stateVal != null && stateVal == supplierStateId;
                }).toList();

                if (supplierContacts.isEmpty) {
                  alertMessage = "Aucun contact avec l'état 'Fournisseur' parmi les contacts trouvés";
                } else if (supplierContacts.length > 1) {
                  alertMessage = "Plusieurs contacts avec l'état 'Fournisseur' détectés.";
                } else {
                  final selectedContact = supplierContacts.first;
                  providerContactId = selectedContact['id']?.toString();
                  final cAttr = selectedContact['attributes'] ?? {};
                  contactEmail = (cAttr['email'] ??
                          cAttr['email1'] ??
                          cAttr['emailOne'] ??
                          cAttr['emailPro'] ??
                          '')
                      .toString();
                }
              }
            }
          }

          if (alertMessage == null) {
            if (providerId == "Aucun" || providerId.isEmpty) {
              alertMessage = "Aucun fournisseur lié à l'achat de prestation.";
            } else if (providerContactId == null || providerContactId.isEmpty) {
              alertMessage = "Aucun contact administratif renseigné pour le fournisseur";
            } else if (contactEmail.isEmpty || !contactEmail.contains('@')) {
              alertMessage = "E-mail de contact non renseigné";
            }
          }
        } else {
          alertMessage = "Aucun achat associé.";
        }
      }

      // Extraire la quantité vendue et le TJM d'achat
      final double quantitySold = double.tryParse(delAttr['numberOfDaysInvoicedOrQuantity']?.toString() ?? '0') ?? 0;
      final double costsSimulated = double.tryParse(delAttr['costsSimulatedExcludingTax']?.toString() ?? '0') ?? 0;
      double averageDailyCost = 0;
      if (quantitySold > 0) {
        averageDailyCost = costsSimulated / quantitySold;
      }

      // Extraire les dates réelles
      final displayStartDate = delAttr['startDate']?.toString() ?? '';
      final displayEndDate = delAttr['endDate']?.toString() ?? '';

      // Créer le candidat rafraîchi
      final refreshed = BdcPrestaStep1(
        id: deliveryId,
        consultantName: resourceName,
        providerName: providerName,
        providerId: providerId,
        projectName: item.projectName,
        clientName: item.clientName,
        title: delTitleWithRef,
        alertMessage: alertMessage,
        boondLink: item.boondLink,
        isSelected: alertMessage == null && !item.isAlreadySent, // reste décoché si non conforme ou déjà envoyé
        isAlreadySent: item.isAlreadySent,
        sentDate: item.sentDate,
        tjmAchat: averageDailyCost,
        quantitySold: quantitySold,
        consultantTitle: consultantTitle,
        clientCsoc: item.clientCsoc,
        projectId: item.projectId,
        providerEmail: contactEmail,
        providerContactId: providerContactId,
        purchaseId: purchaseIdStr,
        providerAddress: providerAddress,
        providerPostcode: providerPostcode,
        providerTown: providerTown,
        providerCountry: providerCountry,
        startDate: displayStartDate,
        endDate: displayEndDate,
        prestationRef: delRef,
        projectRef: item.projectRef,
      );

      // Vérifier le log d'envoi en local pour synchroniser isAlreadySent
      final period = '$_selectedMonth/$_selectedYear';
      final log = await logsService.getSentLog(refreshed.providerId, period);
      if (log != null) {
        refreshed.isAlreadySent = true;
        final sentAtStr = log['sentAt'] as String?;
        if (sentAtStr != null) {
          final sentAt = DateTime.parse(sentAtStr);
          refreshed.sentDate = "${sentAt.day.toString().padLeft(2, '0')}/${sentAt.month.toString().padLeft(2, '0')}/${sentAt.year}";
        }
        refreshed.isSelected = false;
      }

      // Mettre à jour l'élément dans la liste des candidats
      setState(() {
        final index = _step1Candidates.indexWhere((x) => x.id == item.id);
        if (index != -1) {
          _step1Candidates[index] = refreshed;
        }
        _loadingItems.remove(item.id);
      });
      
      if (mounted) {
        ShadToaster.of(context).show(
          ShadToast(
            title: const Text("Actualisation réussie"),
            description: Text("Les données de ${item.consultantName} ont été mises à jour."),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _loadingItems.remove(item.id);
      });
      if (mounted) {
        ShadToaster.of(context).show(
          ShadToast.destructive(
            title: const Text("Échec de l'actualisation"),
            description: Text("Impossible de rafraîchir cette ligne : $e"),
          ),
        );
      }
    }
  }

  Widget _buildRowRefreshButton(BdcPrestaStep1 item) {
    final isLoading = _loadingItems.contains(item.id);
    
    return isLoading
        ? const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.0),
            child: SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: VivColors.gray400),
            ),
          )
        : IconButton(
            icon: const Icon(LucideIcons.rotateCw, size: 14, color: VivColors.gray400),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            style: IconButton.styleFrom(
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () => _refreshSingleCandidate(item),
            tooltip: "Actualiser cette prestation",
          );
  }

  void _calculateSelected(List<BdcPrestaStep1> filteredList) async {
    setState(() {
      _isLoadingDetection = true;
    });

    final selectedCandidates = filteredList.where((c) => c.isSelected).toList();
    
    // Charger les règles de facturation utilisateur depuis bdc_rules.json
    final rules = await BdcRulesService().loadRules();
    
    final List<BdcPrestaStep2> results = [];
    final monthInt = int.tryParse(_selectedMonth) ?? DateTime.now().month;
    final yearInt = int.tryParse(_selectedYear) ?? DateTime.now().year;

    // Calculer les jours ouvrés théoriques standard du mois
    final startOfMonth = DateTime(yearInt, monthInt, 1);
    final endOfMonth = monthInt == 12 ? DateTime(yearInt + 1, 1, 0) : DateTime(yearInt, monthInt + 1, 0);
    final int standardWorkingDays = CalendarService.calculateWorkingDays(
      start: startOfMonth,
      end: endOfMonth,
      holidays: _holidays,
    );

    for (var c in selectedCandidates) {
      BdcRule? matchedRule;
      
      // Rechercher la première règle correspondante
      for (var rule in rules) {
        // 1. Filtre Client (si configuré)
        if (rule.clientCsoc.isNotEmpty && rule.clientCsoc != c.clientCsoc) {
          continue;
        }
        
        // 2. Filtre Projet (si configuré)
        if (rule.projectId.isNotEmpty && rule.projectId != c.projectId) {
          continue;
        }
        
        // 3. Filtre Mots-clés (si configuré)
        if (rule.keywords.isNotEmpty) {
          bool keywordMatched = false;
          for (var kw in rule.keywords) {
            final textToSearch = kw.caseSensitive ? c.title : c.title.toLowerCase();
            final query = kw.caseSensitive ? kw.text : kw.text.toLowerCase();
            if (textToSearch.contains(query)) {
              keywordMatched = true;
              break;
            }
          }
          if (!keywordMatched) continue;
        }

        // Si on arrive ici, la règle correspond !
        matchedRule = rule;
        break;
      }

      // 2. Appliquer les calculs basés sur la règle matchée ou le comportement Standard
      String modeName = "Standard";
      int uoCount = standardWorkingDays;
      String? ruleName;
      String prestationTitle = c.title;

      if (matchedRule != null) {
        ruleName = matchedRule.clientName.isNotEmpty 
            ? "${matchedRule.clientName} (Règle appliquée)"
            : "Règle appliquée";
        
        // Mode de calcul
        if (matchedRule.calculationMode == 'manual') {
          modeName = "Fixe Manuel";
          uoCount = matchedRule.manualDays.round();
        } else if (matchedRule.calculationMode == 'sold') {
          modeName = "Jours Vendus";
          uoCount = c.quantitySold.round();
        } else {
          modeName = "Standard";
          uoCount = standardWorkingDays;
        }

        // Mode d'affichage du titre
        if (matchedRule.titleMode == 'resource_title') {
          final prefixMatch = RegExp(r'^(MIS\d+\s*-\s*)').firstMatch(c.title);
          final prefix = prefixMatch != null ? prefixMatch.group(0)! : '';
          prestationTitle = prefix + (c.consultantTitle ?? c.title.replaceAll(prefix, ''));
        }
      }

      results.add(BdcPrestaStep2(
        id: c.id,
        consultantName: c.consultantName,
        clientName: c.clientName,
        projectName: c.projectName,
        prestationTitle: prestationTitle,
        calculationMode: modeName,
        uoCount: uoCount,
        tjm: c.tjmAchat,
        totalHt: uoCount * c.tjmAchat,
        appliedRule: ruleName,
        providerId: c.providerId,
        providerName: c.providerName,
        providerAddress: c.providerAddress,
        providerPostcode: c.providerPostcode,
        providerTown: c.providerTown,
        providerCountry: c.providerCountry,
        purchaseId: c.purchaseId,
        startDate: c.startDate,
        endDate: c.endDate,
        prestationRef: c.prestationRef,
      ));
    }

    setState(() {
      _step2Calculated = results;
      _isLoadingDetection = false;
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
        email: orig.providerEmail.isNotEmpty ? orig.providerEmail : "fournisseurs@viv-prod.com",
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

      // Étape 2 : Envoi SMTP réel
      setState(() {
        item.status = 'sending';
      });

      Future.delayed(const Duration(milliseconds: 300), () async {
        if (!mounted) return;
        
        try {
          final tempDir = await getTemporaryDirectory();
          final tempFile = File(p.join(tempDir.path, "temp_${step1Item.providerId}.pdf"));
          await tempFile.writeAsBytes(pdfBytes!);

          final settings = ref.read(settingsProvider);
          final emailService = ref.read(emailServiceProvider);
          final period = '$_selectedMonth/$_selectedYear';
          final logsService = BdcSentLogsService();

          // 1. Envoyer le mail avec pièce jointe
          await emailService.sendEmail(
            settings: settings,
            to: item.email,
            subject: "Bon de Commande Opsis - Période $period - ${step2Item.consultantName}",
            body: "Bonjour,\n\nVeuillez trouver ci-joint le bon de commande pour la prestation de ${step2Item.consultantName} sur la période de $period.\n\nCordialement,\nL'administrateur Opsis.",
            attachments: [tempFile],
            bcc: [settings.smtpUser], // Copie conforme à l'expéditeur
          );

          // Supprimer le fichier temporaire
          try {
            await tempFile.delete();
          } catch (_) {}

          // 2. Sauvegarder dans Sembast + disque physique local
          final int existingCount = await logsService.getSentCountForProvider(step1Item.providerId, _selectedYear);
          final String seqStr = (existingCount + 1).toString().padLeft(2, '0');
          final String yearSuffix = _selectedYear.substring(_selectedYear.length - 2);
          final String bdcNumber = "VIV-PO-CSOC${step1Item.providerId}-$yearSuffix$seqStr";

          await logsService.logSentBdc(
            providerId: step1Item.providerId,
            consultantName: step2Item.consultantName,
            clientName: step2Item.clientName,
            projectName: step2Item.projectName,
            prestationTitle: step2Item.prestationTitle,
            period: period,
            sentToEmail: item.email,
            bdcNumber: bdcNumber,
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
          });
        } catch (e) {
          setState(() {
            item.status = 'failed';
            item.errorMessage = e.toString();
          });
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
    final settings = ref.read(settingsProvider);
    final emailService = ref.read(emailServiceProvider);

    for (var item in _smtpStatusList) {
      if (item.status == 'failed') {
        setState(() {
          item.status = 'generating';
        });
        
        await Future.delayed(const Duration(milliseconds: 300));
        
        final step2Item = _step2Calculated.firstWhere((x) => x.id == item.id);
        final step1Item = _step1Candidates.firstWhere((x) => x.id == item.id);
        
        Uint8List? pdfBytes;
        try {
          pdfBytes = await BdcPdfService.generateBdcPdf(step2Item, _selectedMonth, _selectedYear);
          
          setState(() {
            item.status = 'sending';
          });
          
          final tempDir = await getTemporaryDirectory();
          final tempFile = File(p.join(tempDir.path, "temp_retry_${step1Item.providerId}.pdf"));
          await tempFile.writeAsBytes(pdfBytes);

          // 1. Envoyer le mail réel
          await emailService.sendEmail(
            settings: settings,
            to: item.email,
            subject: "Bon de Commande Opsis - Période $period - ${step2Item.consultantName}",
            body: "Bonjour,\n\nVeuillez trouver ci-joint le bon de commande pour la prestation de ${step2Item.consultantName} sur la période de $period.\n\nCordialement,\nL'administrateur Opsis.",
            attachments: [tempFile],
            bcc: [settings.smtpUser], // Copie conforme à l'expéditeur
          );

          // Supprimer le fichier temporaire
          try {
            await tempFile.delete();
          } catch (_) {}

          // 2. Sauvegarder dans Sembast + disque physique local
          final int existingCount = await logsService.getSentCountForProvider(step1Item.providerId, _selectedYear);
          final String seqStr = (existingCount + 1).toString().padLeft(2, '0');
          final String yearSuffix = _selectedYear.substring(_selectedYear.length - 2);
          final String bdcNumber = "VIV-PO-CSOC${step1Item.providerId}-$yearSuffix$seqStr";

          await logsService.logSentBdc(
            providerId: step1Item.providerId,
            consultantName: step2Item.consultantName,
            clientName: step2Item.clientName,
            projectName: step2Item.projectName,
            prestationTitle: step2Item.prestationTitle,
            period: period,
            sentToEmail: item.email,
            bdcNumber: bdcNumber,
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
            item.errorMessage = e.toString();
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

  void _showRulesModal() async {
    await showDialog(
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
    
    // Recalculer automatiquement l'étape 2 à partir des candidats de l'étape 1 à la fermeture du modal
    _calculateSelected(_step1Candidates);
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
                                  if (c.alertMessage == null) {
                                    c.isSelected = true;
                                  }
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
                                  if (hasAlert)
                                    const SizedBox(width: 44)
                                  else ...[
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
                                  ],
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
                                        Text("${item.projectRef} - ${item.projectName}", style: const TextStyle(fontSize: 11, color: VivColors.gray400)),
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
                                        Text(
                                          (item.providerId == "Aucun" || item.providerId.isEmpty)
                                              ? "-"
                                              : "CSOC${item.providerId}",
                                          style: const TextStyle(fontSize: 11, color: VivColors.gray400),
                                        ),
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
                                                onPressed: () async {
                                                  final settings = ref.read(settingsProvider);
                                                  var boondUiUrl = settings.boondUrl;
                                                  if (boondUiUrl.contains('api.boondmanager.com')) {
                                                    boondUiUrl = boondUiUrl.replaceAll('api.boondmanager.com', 'ui.boondmanager.com');
                                                  }
                                                  if (boondUiUrl.endsWith('/api')) {
                                                    boondUiUrl = boondUiUrl.substring(0, boondUiUrl.length - 4);
                                                  }
                                                  if (boondUiUrl.endsWith('/api/')) {
                                                    boondUiUrl = boondUiUrl.substring(0, boondUiUrl.length - 5);
                                                  }
                                                  if (!boondUiUrl.endsWith('/')) {
                                                    boondUiUrl = '$boondUiUrl/';
                                                  }
                                                  String targetUrl = "${boondUiUrl}projects/${item.projectId}/deliveries";
                                                  if (item.alertMessage != null) {
                                                    if (item.alertMessage!.contains("Aucun achat associé à la prestation")) {
                                                      targetUrl = "${boondUiUrl}deliveries/${item.id}";
                                                    } else if (item.alertMessage!.contains("Aucun fournisseur lié à l'achat de prestation") &&
                                                        item.purchaseId != null &&
                                                        item.purchaseId!.isNotEmpty) {
                                                      targetUrl = "${boondUiUrl}purchases/${item.purchaseId}/information";
                                                    } else if ((item.alertMessage!.contains("Aucun contact administratif renseigné") ||
                                                                item.alertMessage!.contains("Aucun contact avec l'état 'Fournisseur'") ||
                                                                item.alertMessage!.contains("Plusieurs contacts avec l'état 'Fournisseur'")) &&
                                                        item.providerId != "Aucun" &&
                                                        item.providerId.isNotEmpty) {
                                                      targetUrl = "${boondUiUrl}companies/${item.providerId}/contacts";
                                                    } else if (item.alertMessage!.contains("E-mail de contact non renseigné") &&
                                                        item.providerContactId != null &&
                                                        item.providerContactId!.isNotEmpty) {
                                                      targetUrl = "${boondUiUrl}contacts/${item.providerContactId}/information";
                                                    }
                                                  }

                                                  final uri = Uri.tryParse(targetUrl);
                                                  if (uri != null && await canLaunchUrl(uri)) {
                                                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                                                  } else {
                                                    if (!context.mounted) return;
                                                    ShadToaster.of(context).show(
                                                      ShadToast.destructive(
                                                        title: const Text("Erreur de redirection"),
                                                        description: Text("Impossible d'ouvrir l'URL : $targetUrl"),
                                                      ),
                                                    );
                                                  }
                                                },
                                                child: const Text("Corriger", style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                                              ),
                                              const SizedBox(width: 8),
                                              _buildRowRefreshButton(item),
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
                                                  const SizedBox(width: 8),
                                                  _buildRowRefreshButton(item),
                                                ],
                                              )
                                            : Row(
                                                children: [
                                                  const Icon(LucideIcons.check, color: Colors.teal, size: 16),
                                                  const SizedBox(width: 8),
                                                  const Expanded(
                                                    child: Text("Fiche administrative conforme", style: TextStyle(color: Colors.teal, fontSize: 11)),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  _buildRowRefreshButton(item),
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
