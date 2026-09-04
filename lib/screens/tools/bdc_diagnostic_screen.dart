import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../../design_system/viv_colors.dart';
import '../../design_system/viv_spacing.dart';
import '../../design_system/viv_typography.dart';
import '../../services/boond_service.dart';
import '../../services/calendar_service.dart';
import '../../services/email_service.dart';
import '../../providers/settings_provider.dart';

class BdcDiagnosticScreen extends ConsumerStatefulWidget {
  final VoidCallback onClose;
  const BdcDiagnosticScreen({super.key, required this.onClose});

  @override
  ConsumerState<BdcDiagnosticScreen> createState() => _BdcDiagnosticScreenState();
}

class _BdcDiagnosticScreenState extends ConsumerState<BdcDiagnosticScreen> {
  bool _isLoading = false;
  String _statusText = "Prêt à tester.";
  String _jsonResponse = "";
  int _apiCallsCount = 0;

  // Filtres & Période pour le banc de test
  String _selectedMonth = "08";
  String _selectedYear = "2026";
  int _maxPagesLimit = 50; // 50 = sans restriction pratique
  String _agencyId = "";
  String _smtpTestRecipient = "";

  // Résultats structurés du test Approche A
  Map<String, dynamic>? _lastAuditReport;

  Future<void> _runApprocheATest() async {
    setState(() {
      _isLoading = true;
      _statusText = "🚀 Démarrage du banc d'essai Approche A (Période : $_selectedMonth/$_selectedYear)...";
      _jsonResponse = "";
      _lastAuditReport = null;
    });

    final service = ref.read(boondServiceProvider);
    final monthInt = int.tryParse(_selectedMonth) ?? DateTime.now().month;
    final yearInt = int.tryParse(_selectedYear) ?? DateTime.now().year;
    final lastDay = DateTime(yearInt, monthInt + 1, 0).day;
    final startDateStr = "$yearInt-${monthInt.toString().padLeft(2, '0')}-01";
    final endDateStr = "$yearInt-${monthInt.toString().padLeft(2, '0')}-${lastDay.toString().padLeft(2, '0')}";

    final startTime = DateTime.now();
    int httpCallsCount = 0;

    try {
      // 1. Jours fériés
      setState(() => _statusText = "1/4 Chargement des jours fériés et du référentiel...");
      final holidays = await service.getHolidays(yearInt);
      httpCallsCount++;

      // 2. Dictionnaire (État Sortie et Contact Administratif)
      final dict = await service.getDictionary(forceRefresh: false);
      httpCallsCount++;
      final resourceStates = dict['data']?['setting']?['state']?['resource'] as List? ?? [];
      int? exitStateId;
      for (var state in resourceStates) {
        final label = (state['value'] ?? state['label'] ?? '').toString().toLowerCase();
        if (label.contains('sortie')) {
          exitStateId = int.tryParse(state['id']?.toString() ?? '');
          break;
        }
      }

      final contactTypes = dict['data']?['setting']?['typeOf']?['contact'] as List? ?? [];
      int? adminTypeId;
      for (var type in contactTypes) {
        final val = (type['value'] ?? type['label'] ?? '').toString().toLowerCase();
        if (val.contains('administratif')) {
          adminTypeId = int.tryParse(type['id']?.toString() ?? '');
          break;
        }
      }

      // 3. Projets actifs paginés avec dates en amont
      setState(() => _statusText = "2/4 Récupération paginée des projets actifs sur la période ($startDateStr au $endDateStr)...");

      final Map<String, dynamic> projectFilters = {
        'states[]': 1,
        'startDate': startDateStr,
        'endDate': endDateStr,
      };
      if (_agencyId.isNotEmpty) {
        projectFilters['agency'] = _agencyId;
      }

      final projectsResponse = await service.getAllProjectsWithInclusions(
        filters: projectFilters,
        inclusions: ['company'],
        maxPages: _maxPagesLimit,
        maxResultsPerPage: 50,
        forceRefresh: true,
        onProgress: (page, totalPages, count) {
          setState(() {
            _statusText = "2/4 Récupération des projets : Page $page / $totalPages ($count projets)...";
          });
        },
      );

      final List<dynamic> projects = projectsResponse['data'] as List? ?? [];
      final List<dynamic> included = projectsResponse['included'] as List? ?? [];
      final meta = projectsResponse['meta'] as Map? ?? {};
      httpCallsCount += (meta['pagesLoaded'] as int? ?? 1);

      // Résolution rapide des clients
      final Map<String, String> companyNames = {};
      for (var item in included) {
        if (item['type'] == 'company' || item['type'] == 'companies') {
          final id = item['id']?.toString() ?? '';
          final name = item['attributes']?['name']?.toString() ?? 'Société sans nom';
          companyNames[id] = name;
        }
      }

      setState(() => _statusText = "3/4 Analyse des prestations pour ${projects.length} projets (parallélisation contrôlée)...");

      // 4. Parallélisation par lots (Pool de 6 projets simultanés)
      final List<Map<String, dynamic>> detectedPrestas = [];
      const int batchSize = 6;

      for (int i = 0; i < projects.length; i += batchSize) {
        final batch = projects.skip(i).take(batchSize).toList();
        
        final batchFutures = batch.map((p) async {
          final projectIdStr = p['id']?.toString() ?? '';
          final projectId = int.tryParse(projectIdStr);
          if (projectId == null) return <Map<String, dynamic>>[];

          final projectName = p['attributes']?['reference']?.toString() ?? 'Projet sans nom';
          final clientRel = p['relationships']?['company']?['data'];
          final clientId = clientRel?['id']?.toString();
          final clientName = companyNames[clientId] ?? 'Client inconnu';

          // Prestations du projet
          final List<dynamic> deliveries = await service.getDeliveries(projectId, forceRefresh: false);

          final List<Map<String, dynamic>> localPrestas = [];

          for (var delivery in deliveries) {
            final delId = delivery['id']?.toString() ?? '';
            final delAttr = delivery['attributes'] ?? {};
            final delTitle = delAttr['title']?.toString() ?? 'Prestation sans titre';

            if (delTitle.toLowerCase().contains('shift')) continue;

            final startStr = delAttr['startDate']?.toString();
            final endStr = delAttr['endDate']?.toString();

            if (startStr != null) {
              final dStart = DateTime.tryParse(startStr);
              final dEnd = endStr != null ? DateTime.tryParse(endStr) : null;
              if (dStart != null) {
                final intersection = CalendarService.getIntersection(
                  prestationStart: dStart,
                  prestationEnd: dEnd,
                  month: monthInt,
                  year: yearInt,
                );
                if (intersection == null) {
                  // Hors période
                  continue;
                }
              }
            }

            final dependsOn = delivery['relationships']?['dependsOn']?['data'];
            final purchaseRel = delivery['relationships']?['purchase']?['data'];

            // Ressource
            bool isExternal = false;
            String resourceName = "Non spécifié";
            String? consultantTitle;
            bool isExit = false;

            if (dependsOn != null) {
              final resId = int.tryParse(dependsOn['id']?.toString() ?? '');
              if (resId != null) {
                try {
                  final res = await service.getResource(resId);
                  final rAttr = res['attributes'] ?? {};
                  final rState = int.tryParse(rAttr['state']?.toString() ?? '');
                  if (rState != null && exitStateId != null && rState == exitStateId) {
                    isExit = true;
                  } else {
                    resourceName = "${rAttr['firstName'] ?? ''} ${rAttr['lastName'] ?? ''}".trim();
                    consultantTitle = rAttr['title']?.toString() ?? rAttr['function']?.toString();
                    if (rAttr['typeOf'] == 1) {
                      isExternal = true;
                    }
                  }
                } catch (_) {}
              }
            }

            if (isExit) continue;
            if (!isExternal && purchaseRel == null) continue; // Ignorer salariés internes sans achat

            // Achat & Fournisseur
            String providerName = "Aucun";
            String providerId = "";
            String providerAddress = "";
            String providerPostcode = "";
            String providerTown = "";
            String providerCountry = "France";
            String? alertMessage;
            String contactName = "Aucun";
            String contactEmail = "";
            String? purchaseIdStr;
            double purchaseTjm = 0;

            if (purchaseRel == null) {
              alertMessage = "Aucun achat associé à la prestation.";
            } else {
              final purchaseId = int.tryParse(purchaseRel['id']?.toString() ?? '');
              purchaseIdStr = purchaseId?.toString();
              if (purchaseId != null) {
                try {
                  final pResponse = await service.getPurchaseWithInclusions(purchaseId, forceRefresh: false);
                  final pAttr = pResponse['data']?['attributes'] ?? {};
                  purchaseTjm = double.tryParse(pAttr['averageDailyCost']?.toString() ?? '0') ?? 0;
                  final pIncluded = pResponse['included'] as List? ?? [];

                  // Société Fournisseur
                  final compObj = pIncluded.firstWhere(
                    (item) => item['type'] == 'companies' || item['type'] == 'company',
                    orElse: () => null,
                  );
                  if (compObj != null) {
                    providerName = compObj['attributes']?['name']?.toString() ?? 'Société sans nom';
                    providerId = compObj['id']?.toString() ?? '';
                  }

                  // Coordonnées postales complètes
                  if (providerId.isNotEmpty && int.tryParse(providerId) != null) {
                    try {
                      final compInfo = await service.getCompanyInformation(int.parse(providerId));
                      final cInfoAttr = compInfo['attributes'] ?? {};
                      providerAddress = cInfoAttr['address']?.toString() ?? '';
                      providerPostcode = cInfoAttr['postcode']?.toString() ?? '';
                      providerTown = cInfoAttr['town']?.toString() ?? '';
                      providerCountry = cInfoAttr['country']?.toString() ?? 'France';
                    } catch (_) {}
                  }

                  // Contact
                  final contactObj = pIncluded.firstWhere(
                    (item) => item['type'] == 'contacts' || item['type'] == 'contact',
                    orElse: () => null,
                  );
                  if (contactObj != null) {
                    final cAttr = contactObj['attributes'] ?? {};
                    contactName = "${cAttr['firstName'] ?? ''} ${cAttr['lastName'] ?? ''}".trim();
                    contactEmail = (cAttr['email'] ?? cAttr['email1'] ?? cAttr['emailPro'] ?? '').toString();
                  } else if (providerId.isNotEmpty && int.tryParse(providerId) != null) {
                    // Fallback contact administratif
                    try {
                      final contactsList = await service.getCompanyContacts(int.parse(providerId));
                      if (contactsList.isEmpty) {
                        alertMessage = "Aucun contact renseigné pour le fournisseur.";
                      } else {
                        final adminContacts = contactsList.where((c) {
                          if (adminTypeId == null) return false;
                          final tAttr = c['attributes']?['type'] ?? c['attributes']?['typesOf'];
                          return tAttr?.toString().contains(adminTypeId.toString()) ?? false;
                        }).toList();

                        final targetContact = adminContacts.isNotEmpty ? adminContacts.first : contactsList.first;
                        final cAttr = targetContact['attributes'] ?? {};
                        contactName = "${cAttr['firstName'] ?? ''} ${cAttr['lastName'] ?? ''}".trim();
                        contactEmail = (cAttr['email'] ?? cAttr['email1'] ?? cAttr['emailPro'] ?? '').toString();
                        if (adminContacts.isEmpty && contactsList.length > 1) {
                          alertMessage = "Plusieurs contacts détectés, aucun typé 'Administratif'.";
                        }
                      }
                    } catch (_) {}
                  }
                } catch (_) {}
              }
            }

            // Calcul UO
            int uoCount = 0;
            if (startStr != null) {
              final dStart = DateTime.tryParse(startStr);
              final dEnd = endStr != null ? DateTime.tryParse(endStr) : null;
              if (dStart != null) {
                final intersection = CalendarService.getIntersection(
                  prestationStart: dStart,
                  prestationEnd: dEnd,
                  month: monthInt,
                  year: yearInt,
                );
                if (intersection != null) {
                  uoCount = CalendarService.calculateWorkingDays(
                    start: intersection['start']!,
                    end: intersection['end']!,
                    holidays: holidays,
                  );
                }
              }
            }

            // Vérification alertes
            if (alertMessage == null) {
              if (providerId.isEmpty) {
                alertMessage = "Aucun fournisseur lié à la prestation.";
              } else if (contactEmail.isEmpty || !contactEmail.contains('@')) {
                alertMessage = "E-mail de contact manquant ou invalide.";
              }
            }

            // Récupérer le détail de la prestation pour avoir le averageDailyCost précis
            Map<String, dynamic> deliveryDetail = {};
            Map<String, dynamic> deliveryDetailAttr = {};
            try {
              final delIdInt = int.tryParse(delId);
              if (delIdInt != null) {
                deliveryDetail = await service.getDelivery(delIdInt, forceRefresh: false);
                deliveryDetailAttr = deliveryDetail['data']?['attributes'] ?? {};
              }
            } catch (_) {}

            // Calcul du TJM d'achat (averageDailyCost)
            double averageDailyCost = _parseTjm(deliveryDetailAttr['averageDailyCost']);
            if (averageDailyCost == 0) {
              averageDailyCost = _parseTjm(deliveryDetailAttr['contractAverageDailyCost']);
            }
            if (averageDailyCost == 0) {
              averageDailyCost = _parseTjm(delAttr['averageDailyCost']);
            }
            if (averageDailyCost == 0) {
              averageDailyCost = _parseTjm(delAttr['contractAverageDailyCost']);
            }
            if (averageDailyCost == 0) {
              averageDailyCost = purchaseTjm;
            }
            if (averageDailyCost == 0) {
              final double quantitySold = double.tryParse(delAttr['numberOfDaysInvoicedOrQuantity']?.toString() ?? '0') ?? 0;
              final double costsSimulated = double.tryParse(delAttr['costsSimulatedExcludingTax']?.toString() ?? '0') ?? 0;
              if (quantitySold > 0 && costsSimulated > 0) {
                averageDailyCost = costsSimulated / quantitySold;
              }
            }

            localPrestas.add({
              'deliveryId': delId,
              'title': delTitle,
              'projectId': projectIdStr,
              'projectName': projectName,
              'clientName': clientName,
              'consultantName': resourceName,
              'consultantTitle': consultantTitle,
              'providerId': providerId,
              'providerName': providerName,
              'providerAddress': providerAddress,
              'providerPostcode': providerPostcode,
              'providerTown': providerTown,
              'providerCountry': providerCountry,
              'contactName': contactName,
              'contactEmail': contactEmail,
              'purchaseId': purchaseIdStr,
              'tjmAchat': averageDailyCost,
              'uoCount': uoCount,
              'totalHt': uoCount * averageDailyCost,
              'startDate': startStr,
              'endDate': endStr,
              'alertMessage': alertMessage,
              'hasAlert': alertMessage != null,
            });
          }

          return localPrestas;
        });

        final results = await Future.wait(batchFutures);
        for (var res in results) {
          detectedPrestas.addAll(res);
        }
      }

      final endTime = DateTime.now();
      final durationMs = endTime.difference(startTime).inMilliseconds;

      // Synthèse
      final Set<String> distinctProviders = detectedPrestas
          .map((p) => p['providerName'].toString())
          .where((name) => name != "Aucun" && name.isNotEmpty)
          .toSet();

      final int alertCount = detectedPrestas.where((p) => p['hasAlert'] == true).length;
      final int validCount = detectedPrestas.length - alertCount;
      final double totalMontantHt = detectedPrestas.fold(0.0, (sum, item) => sum + (item['totalHt'] as double? ?? 0.0));

      final report = {
        'performance': {
          'durationMs': durationMs,
          'durationSeconds': (durationMs / 1000).toStringAsFixed(1),
          'httpCallsCount': httpCallsCount,
          'pagesLoaded': meta['pagesLoaded'] ?? 1,
          'totalPages': meta['totalPages'] ?? 1,
        },
        'summary': {
          'totalProjectsScanned': projects.length,
          'totalPrestasDetected': detectedPrestas.length,
          'distinctProvidersCount': distinctProviders.length,
          'validPrestasCount': validCount,
          'alertPrestasCount': alertCount,
          'totalMontantHt': totalMontantHt,
        },
        'providers': distinctProviders.toList(),
        'prestas': detectedPrestas,
      };

      setState(() {
        _isLoading = false;
        _apiCallsCount += httpCallsCount;
        _lastAuditReport = report;
        _statusText = "✅ Test Approche A complété en ${(durationMs / 1000).toStringAsFixed(1)}s !\n"
            "• Projets scannés : ${projects.length} (Pages : ${meta['pagesLoaded']}/${meta['totalPages']})\n"
            "• Prestations détectées pour $_selectedMonth/$_selectedYear : ${detectedPrestas.length}\n"
            "• Fournisseurs uniques : ${distinctProviders.length}\n"
            "• Conformes : $validCount | Avec alertes : $alertCount\n"
            "• Volume HT global simulé : ${totalMontantHt.toStringAsFixed(2)} € HT";
        _jsonResponse = const JsonEncoder.withIndent('  ').convert(report);
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusText = "❌ Erreur durant le test Approche A :\n$e";
        _jsonResponse = "";
      });
    }
  }

  Future<void> _runProjectsTest() async {
    setState(() {
      _isLoading = true;
      _statusText = "Appel GET /projects en cours...";
      _jsonResponse = "";
      _lastAuditReport = null;
    });

    final service = ref.read(boondServiceProvider);

    try {
      final List<String> inclusions = ['company', 'deliveries'];

      final Map<String, dynamic> filters = {
        'states[]': 1,
      };
      if (_agencyId.isNotEmpty) {
        filters['agency'] = _agencyId;
      }

      final startTime = DateTime.now();
      
      final response = await service.getProjectsWithInclusions(
        filters: filters,
        inclusions: inclusions,
      );

      final endTime = DateTime.now();
      final duration = endTime.difference(startTime).inMilliseconds;

      final projects = response['data'] as List? ?? [];
      final included = response['included'] as List? ?? [];

      setState(() {
        _isLoading = false;
        _apiCallsCount++;
        _statusText = "Succès en $duration ms.\n"
            "Projets retournés (Page 1 sans pagination) : ${projects.length}\n"
            "Objets inclus : ${included.length}";
        _jsonResponse = const JsonEncoder.withIndent('  ').convert(response);
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusText = "Erreur : $e";
        _jsonResponse = "";
      });
    }
  }

  Future<void> _runSmtpTest() async {
    setState(() {
      _isLoading = true;
      _statusText = "Tentative d'envoi d'e-mail de test SMTP...";
      _jsonResponse = "";
    });

    final settings = ref.read(settingsProvider);
    final emailService = ref.read(emailServiceProvider);

    try {
      final startTime = DateTime.now();

      final testRecipient = _smtpTestRecipient.trim().isNotEmpty
          ? _smtpTestRecipient.trim()
          : settings.smtpUser;
      if (testRecipient.isEmpty) {
        throw 'Aucun destinataire ou utilisateur SMTP configuré. Veuillez saisir un e-mail destinataire.';
      }

      await emailService.sendEmail(
        settings: settings,
        to: testRecipient,
        subject: "Test Diagnostic SMTP - BDC Opsis",
        body: "Bonjour,\n\nCeci est un e-mail de test envoyé depuis l'application Opsis pour valider la configuration SMTP.\n\nDate : ${DateTime.now().toLocal()}\nServeur : ${settings.smtpHost}:${settings.smtpPort}\nUtilisateur : ${settings.smtpUser}\n\nCordialement,\nL'assistant Opsis.",
      );

      final endTime = DateTime.now();
      final duration = endTime.difference(startTime).inMilliseconds;

      setState(() {
        _isLoading = false;
        _apiCallsCount++;
        _statusText = "Succès en $duration ms !\n"
            "L'e-mail de test SMTP a été envoyé avec succès à : $testRecipient.";
        _jsonResponse = "{\n  \"status\": \"success\",\n  \"recipient\": \"$testRecipient\",\n  \"server\": \"${settings.smtpHost}:${settings.smtpPort}\"\n}";
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusText = "Erreur SMTP :\n$e";
        _jsonResponse = "";
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
                  Expanded(
                    flex: 2,
                    child: _buildControlPanel(),
                  ),
                  const VerticalDivider(width: 24),
                  Expanded(
                    flex: 3,
                    child: _buildLogPanel(),
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
              Text("Banc d'Essai & Diagnostic BDC (Lecture Seule)", style: VivTypography.h3),
              const SizedBox(height: 4),
              Text(
                "Validez la pagination, le filtrage par dates en amont et la complétude des données BDC (Approche A).",
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
          Text("PÉRIODE DU BANC D'ESSAI", style: VivTypography.eyebrow),
          const SizedBox(height: VivSpacing.space3),
          
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Mois", style: VivTypography.small.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    ShadSelect<String>(
                      initialValue: _selectedMonth,
                      options: const [
                        ShadOption(value: "01", child: Text("01 - Janvier")),
                        ShadOption(value: "02", child: Text("02 - Février")),
                        ShadOption(value: "03", child: Text("03 - Mars")),
                        ShadOption(value: "04", child: Text("04 - Avril")),
                        ShadOption(value: "05", child: Text("05 - Mai")),
                        ShadOption(value: "06", child: Text("06 - Juin")),
                        ShadOption(value: "07", child: Text("07 - Juillet")),
                        ShadOption(value: "08", child: Text("08 - Août")),
                        ShadOption(value: "09", child: Text("09 - Septembre")),
                        ShadOption(value: "10", child: Text("10 - Octobre")),
                        ShadOption(value: "11", child: Text("11 - Novembre")),
                        ShadOption(value: "12", child: Text("12 - Décembre")),
                      ],
                      selectedOptionBuilder: (context, value) => Text(value),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedMonth = val);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Année", style: VivTypography.small.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    ShadSelect<String>(
                      initialValue: _selectedYear,
                      options: const [
                        ShadOption(value: "2025", child: Text("2025")),
                        ShadOption(value: "2026", child: Text("2026")),
                        ShadOption(value: "2027", child: Text("2027")),
                      ],
                      selectedOptionBuilder: (context, value) => Text(value),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedYear = val);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: VivSpacing.space4),
          Text("Plafond de pagination (Sécurité)", style: VivTypography.small.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          ShadSelect<int>(
            initialValue: _maxPagesLimit,
            options: const [
              ShadOption(value: 50, child: Text("Sans limite (Tous les projets, max 50 pages)")),
              ShadOption(value: 5, child: Text("Test rapide (Max 5 pages = ~250 projets)")),
              ShadOption(value: 2, child: Text("Test ultra-court (Max 2 pages = ~100 projets)")),
            ],
            selectedOptionBuilder: (context, value) => Text(value == 50 ? "Tous les projets (max 50 pages)" : "Max $value pages"),
            onChanged: (val) {
              if (val != null) setState(() => _maxPagesLimit = val);
            },
          ),

          const SizedBox(height: VivSpacing.space4),
          Text("Filtre Agence Boond (Optionnel)", style: VivTypography.small.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          ShadInput(
            placeholder: const Text("ex: 1 (Laissez vide pour toutes les agences)"),
            onChanged: (val) => setState(() => _agencyId = val.trim()),
          ),

          const SizedBox(height: VivSpacing.space6),
          Text("TEST PRINCIPAL RECOMMANDÉ", style: VivTypography.eyebrow),
          const SizedBox(height: VivSpacing.space3),
          
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ShadButton(
              backgroundColor: VivColors.lime,
              onPressed: _isLoading ? null : _runApprocheATest,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(LucideIcons.rocket, size: 18, color: VivColors.black),
                  const SizedBox(width: 8),
                  Text(
                    "Lancer le Test Approche A",
                    style: VivTypography.body.copyWith(fontWeight: FontWeight.bold, color: VivColors.black),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Exécute la détection paginée complète avec dates en amont, inclusions et audit exhaustif des champs BDC.",
            style: VivTypography.small.copyWith(color: VivColors.gray500, fontSize: 12),
          ),

          const SizedBox(height: VivSpacing.space8),
          Text("AUTRES TESTS UNITAIRES", style: VivTypography.eyebrow),
          const SizedBox(height: VivSpacing.space3),

          SizedBox(
            width: double.infinity,
            child: ShadButton.outline(
              onPressed: _isLoading ? null : _runProjectsTest,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.play, size: 14),
                  SizedBox(width: 8),
                  Text("Tester appel brut GET /projects (Page 1)"),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text("Test Envoi Email SMTP", style: VivTypography.small.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          ShadInput(
            placeholder: const Text("Destinataire test (ex: nom@domaine.com)"),
            onChanged: (val) => setState(() => _smtpTestRecipient = val.trim()),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: ShadButton.outline(
              onPressed: _isLoading ? null : _runSmtpTest,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.mail, size: 14),
                  SizedBox(width: 8),
                  Text("Tester l'envoi SMTP"),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("STATUT & RÉSULTATS DU BANC D'ESSAI", style: VivTypography.eyebrow),
            Text("Appels API exécutés : $_apiCallsCount", style: VivTypography.small.copyWith(color: VivColors.gray500, fontWeight: FontWeight.bold)),
          ],
        ),
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
            style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: VivColors.black, height: 1.4),
          ),
        ),
        const SizedBox(height: VivSpacing.space4),
        
        if (_lastAuditReport != null) ...[
          Text("TABLEAU DE CONTRÔLE DE COMPLÉTUDE (ÉCHANTILLON DÉTECTÉ)", style: VivTypography.eyebrow),
          const SizedBox(height: VivSpacing.space2),
          Expanded(
            child: _buildAuditTable(_lastAuditReport!['prestas'] as List? ?? []),
          ),
        ] else ...[
          Text("RÉPONSE BRUTE / LOG TECHNIQUE", style: VivTypography.eyebrow),
          const SizedBox(height: VivSpacing.space3),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(VivSpacing.space4),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(VivSpacing.radiusMd),
              ),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: VivColors.lime))
                  : _jsonResponse.isEmpty
                      ? const Center(child: Text("Cliquez sur 'Lancer le Test Approche A' pour exécuter le banc d'essai.", style: TextStyle(color: Colors.white60, fontSize: 12)))
                      : SingleChildScrollView(
                          child: SelectableText(
                            _jsonResponse,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 10,
                              color: Color(0xFF9CDCFE),
                            ),
                          ),
                        ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAuditTable(List<dynamic> prestas) {
    if (prestas.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(VivSpacing.space4),
        decoration: BoxDecoration(
          color: VivColors.gray50,
          borderRadius: BorderRadius.circular(VivSpacing.radiusMd),
          border: Border.all(color: VivColors.gray200),
        ),
        child: const Center(child: Text("Aucune prestation sous-traitée trouvée pour cette période.")),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(VivSpacing.radiusMd),
        border: Border.all(color: VivColors.gray200),
      ),
      child: ListView.separated(
        itemCount: prestas.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final p = prestas[index] as Map<String, dynamic>;
          final hasAlert = p['hasAlert'] == true;
          final alertMessage = p['alertMessage']?.toString();

          return Padding(
            padding: const EdgeInsets.all(VivSpacing.space3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: hasAlert ? Colors.amber.shade100 : Colors.green.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        hasAlert ? "⚠️ Alerte" : "✅ Complet",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: hasAlert ? Colors.amber.shade900 : Colors.green.shade900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "${p['consultantName']} — ${p['title']}",
                        style: VivTypography.small.copyWith(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      "${(p['totalHt'] as double? ?? 0).toStringAsFixed(0)} € HT (${p['uoCount']} UO @ ${p['tjmAchat']} €)",
                      style: VivTypography.small.copyWith(fontWeight: FontWeight.bold, color: VivColors.black),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        "🏢 Fournisseur : ${p['providerName']} (${p['providerPostcode']} ${p['providerTown']})",
                        style: VivTypography.small.copyWith(color: VivColors.ink700, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        "✉️ Contact : ${p['contactName']} <${p['contactEmail']}>",
                        style: VivTypography.small.copyWith(color: VivColors.ink700, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  "📁 Projet : ${p['projectName']} | Client : ${p['clientName']} | Dates : ${p['startDate'] ?? 'N/A'} au ${p['endDate'] ?? 'N/A'}",
                  style: VivTypography.small.copyWith(color: VivColors.gray500, fontSize: 11),
                ),
                if (hasAlert && alertMessage != null) ...[
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Text(
                      "Motif de l'alerte : $alertMessage",
                      style: TextStyle(fontSize: 10, color: Colors.amber.shade900),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_lastAuditReport != null)
            Text(
              "Résultats : ${_lastAuditReport!['summary']['totalPrestasDetected']} prestations détectées (${_lastAuditReport!['summary']['distinctProvidersCount']} fournisseurs)",
              style: VivTypography.small.copyWith(fontWeight: FontWeight.bold),
            )
          else
            const SizedBox.shrink(),
          ShadButton.outline(
            onPressed: widget.onClose,
            child: const Text("Fermer"),
          ),
        ],
      ),
    );
  }
}

double _parseTjm(dynamic value) {
  if (value == null) return 0;
  final cleanString = value.toString()
      .replaceAll(',', '.')
      .replaceAll(RegExp(r'[^0-9.-]'), '');
  return double.tryParse(cleanString) ?? 0;
}
