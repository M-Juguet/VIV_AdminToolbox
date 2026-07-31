import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../../design_system/viv_colors.dart';
import '../../design_system/viv_spacing.dart';
import '../../design_system/viv_typography.dart';
import '../../services/boond_service.dart';
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

  // Filtres locaux
  String _agencyId = "";
  bool _includeDeliveries = true;
  bool _includePurchase = true;
  bool _includeCompany = true;
  String _smtpTestRecipient = "";

  Future<void> _runProjectsTest() async {
    setState(() {
      _isLoading = true;
      _statusText = "Appel en cours...";
      _jsonResponse = "";
    });

    final service = ref.read(boondServiceProvider);

    try {
      final List<String> inclusions = [];
      if (_includeDeliveries) inclusions.add("deliveries");
      if (_includeDeliveries && _includePurchase) inclusions.add("deliveries.purchase");
      if (_includeDeliveries && _includePurchase && _includeCompany) {
        inclusions.add("deliveries.purchase.company");
      }
      if (_includeCompany) inclusions.add("company");

      final Map<String, dynamic> filters = {
        'states[]': 1, // Projets "En cours"
      };
      if (_agencyId.isNotEmpty) {
        filters['agency'] = _agencyId;
      }

      final startTime = DateTime.now();
      
      // Appel API unique
      final response = await service.getProjectsWithInclusions(
        filters: filters,
        inclusions: inclusions,
      );

      final endTime = DateTime.now();
      final duration = endTime.difference(startTime).inMilliseconds;

      final projects = response['data'] as List? ?? [];
      final included = response['included'] as List? ?? [];

      // Analyse locale des objets inclus
      int deliveriesCount = 0;
      int purchasesCount = 0;
      int companiesCount = 0;
      final Set<String> types = {};

      for (var item in included) {
        final type = item['type']?.toString() ?? 'unknown';
        types.add(type);
        if (type == 'deliveries') deliveriesCount++;
        if (type == 'purchases') purchasesCount++;
        if (type == 'companies') companiesCount++;
      }

      // Analyse des relations du premier projet pour comprendre la structure
      String relKeysStr = "Aucune";
      if (projects.isNotEmpty) {
        final firstProj = projects.first as Map;
        final rels = firstProj['relationships'] as Map?;
        if (rels != null) {
          relKeysStr = rels.keys.join(', ');
        }
      }

      setState(() {
        _isLoading = false;
        _apiCallsCount++;
        _statusText = "Succès en $duration ms.\n"
            "Projets retournés : ${projects.length}\n"
            "Relations du 1er projet : $relKeysStr\n"
            "Objets inclus : ${included.length} (Prestations: $deliveriesCount, Achats: $purchasesCount, Sociétés Fournisseurs: $companiesCount)\n"
            "Types d'entités reçues : ${types.join(', ')}";
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

  Future<void> _runHolidaysTest() async {
    setState(() {
      _isLoading = true;
      _statusText = "Appel jours fériés en cours...";
      _jsonResponse = "";
    });

    final service = ref.read(boondServiceProvider);
    final now = DateTime.now();

    try {
      final startTime = DateTime.now();
      final holidays = await service.getHolidays(now.year);
      final endTime = DateTime.now();
      final duration = endTime.difference(startTime).inMilliseconds;

      setState(() {
        _isLoading = false;
        _apiCallsCount++;
        _statusText = "Succès en $duration ms.\n"
            "Jours fériés détectés pour ${now.year} : ${holidays.length} jours.";
        _jsonResponse = const JsonEncoder.withIndent('  ').convert(holidays);
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusText = "Erreur : $e";
        _jsonResponse = "";
      });
    }
  }

  Future<void> _runPurchasesTest() async {
    setState(() {
      _isLoading = true;
      _statusText = "Appel achats en cours...";
      _jsonResponse = "";
    });

    final service = ref.read(boondServiceProvider);

    try {
      final List<String> inclusions = [
        "project",
        "providerCompany",
        "providerContact"
      ];

      final Map<String, dynamic> filters = {};
      if (_agencyId.isNotEmpty) {
        filters['agency'] = _agencyId;
      }

      final startTime = DateTime.now();
      
      final response = await service.getPurchasesWithInclusions(
        filters: filters,
        inclusions: inclusions,
      );

      final endTime = DateTime.now();
      final duration = endTime.difference(startTime).inMilliseconds;

      final purchases = response['data'] as List? ?? [];
      final included = response['included'] as List? ?? [];

      int projectsCount = 0;
      int companiesCount = 0;
      int contactsCount = 0;
      final Set<String> types = {};

      for (var item in included) {
        final type = item['type']?.toString() ?? 'unknown';
        types.add(type);
        if (type == 'project' || type == 'projects') projectsCount++;
        if (type == 'company' || type == 'companies') companiesCount++;
        if (type == 'contact' || type == 'contacts') contactsCount++;
      }

      setState(() {
        _isLoading = false;
        _apiCallsCount++;
        _statusText = "Succès en $duration ms.\n"
            "Achats (purchases) retournés : ${purchases.length}\n"
            "Objets inclus : ${included.length} (Projets: $projectsCount, Sociétés: $companiesCount, Contacts: $contactsCount)\n"
            "Types d'entités reçues : ${types.join(', ')}";
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

  Future<void> _runDeliveriesTest() async {
    if (_agencyId.isEmpty || int.tryParse(_agencyId) == null) {
      setState(() {
        _statusText = "Erreur : Vous devez saisir un ID de projet valide dans le champ en haut à gauche pour l'appel Prestations.";
        _jsonResponse = "";
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _statusText = "Appel prestations du projet $_agencyId en cours...";
      _jsonResponse = "";
    });

    final service = ref.read(boondServiceProvider);
    final projectId = int.parse(_agencyId);

    try {
      final startTime = DateTime.now();
      
      // On fait l'appel direct à l'endpoint de projet existant
      final response = await service.getDeliveries(projectId);
      
      final endTime = DateTime.now();
      final duration = endTime.difference(startTime).inMilliseconds;

      final Set<String> types = {};
      int withPurchase = 0;
      int withResource = 0;

      for (var item in response) {
        final type = item['type']?.toString() ?? 'unknown';
        types.add(type);
        final rels = item['relationships'] as Map?;
        if (rels != null) {
          if (rels['purchase'] != null && rels['purchase']['data'] != null) withPurchase++;
          if (rels['resource'] != null && rels['resource']['data'] != null) withResource++;
        }
      }

      setState(() {
        _isLoading = false;
        _apiCallsCount++;
        _statusText = "Succès en $duration ms.\n"
            "Prestations (deliveries) du projet $projectId retournées : ${response.length}\n"
            "Prestations avec achat lié : $withPurchase | avec ressource : $withResource";
        _jsonResponse = const JsonEncoder.withIndent('  ').convert({'data': response});
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
            "L'e-mail de test SMTP a été envoyé avec succès à : $testRecipient.\n"
            "Veuillez vérifier votre boîte de réception (et vos spams).";
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

  Future<void> _runFullBdcSimulation() async {
    setState(() {
      _isLoading = true;
      _statusText = _agencyId.isEmpty 
          ? "Simulation du flux de données BDC pour TOUS les projets actifs..."
          : "Simulation du flux de données BDC pour le projet $_agencyId...";
      _jsonResponse = "";
    });

    final service = ref.read(boondServiceProvider);

    try {
      final startTime = DateTime.now();
      final List<Map<String, dynamic>> projectsToSimulate = [];

      if (_agencyId.isNotEmpty && int.tryParse(_agencyId) != null) {
        final projectId = int.parse(_agencyId);
        final response = await service.getProjectWithInclusions(
          projectId,
          inclusions: ['company'],
        );
        final projData = response['data'] as Map? ?? {};
        final included = response['included'] as List? ?? [];
        final name = projData['attributes']?['reference']?.toString() ?? 'Projet ID $projectId';
        
        final clientRel = projData['relationships']?['company']?['data'];
        final clientId = clientRel?['id']?.toString();
        
        String clientName = 'Client inconnu';
        if (clientId != null) {
          final clientObj = included.firstWhere(
            (item) => item['type'] == 'company' && item['id']?.toString() == clientId,
            orElse: () => null,
          );
          if (clientObj != null) {
            clientName = clientObj['attributes']?['name']?.toString() ?? 'Société sans nom';
          }
        }
        projectsToSimulate.add({'id': projectId, 'name': name, 'clientName': clientName});
      } else {
        final response = await service.getProjectsWithInclusions(
          filters: {'states[]': 1},
          inclusions: ['company'],
        );
        final projects = response['data'] as List? ?? [];
        final included = response['included'] as List? ?? [];

        final Map<String, String> companyNames = {};
        for (var item in included) {
          if (item['type'] == 'company') {
            final id = item['id']?.toString() ?? '';
            final name = item['attributes']?['name']?.toString() ?? 'Société sans nom';
            companyNames[id] = name;
          }
        }

        for (var p in projects) {
          final id = int.tryParse(p['id']?.toString() ?? '');
          final name = p['attributes']?['reference']?.toString() ?? 'Projet sans nom';
          final clientRel = p['relationships']?['company']?['data'];
          final clientId = clientRel?['id']?.toString();
          if (id != null) {
            final clientName = companyNames[clientId] ?? 'Client inconnu';
            projectsToSimulate.add({'id': id, 'name': name, 'clientName': clientName});
          }
        }
      }

      if (projectsToSimulate.isEmpty) {
        throw 'Aucun projet actif trouvé pour la simulation.';
      }

      final buffer = StringBuffer();
      buffer.writeln("=== RAPPORT DE SIMULATION MULTI-PROJETS BDC ===");
      buffer.writeln("Nombre de projets simulés : ${projectsToSimulate.length}\n");

      final holidaysRaw = await service.getHolidays(DateTime.now().year);
      final List<DateTime> holidays = holidaysRaw.map((h) => DateTime.parse(h.toString())).toList();

      for (var proj in projectsToSimulate) {
        final projectId = proj['id'] as int;
        final projectName = proj['name'] as String;
        final clientName = proj['clientName'] as String;

        final List<dynamic> deliveries = await service.getDeliveries(projectId);
        
        // On filtre pour ne garder que les prestations sous-traitées
        final subcontractorDeliveries = deliveries.where((d) => 
          d['relationships']?['purchase']?['data'] != null
        ).toList();

        if (subcontractorDeliveries.isEmpty) {
          continue;
        }

        buffer.writeln("=================================================================");
        buffer.writeln("PROJET : $projectName (ID: $projectId) | Client : $clientName");
        buffer.writeln("=================================================================");

        for (var delivery in subcontractorDeliveries) {
          final delAttr = delivery['attributes'] ?? {};
          final delId = delivery['id']?.toString() ?? 'unknown';
          final delTitle = delAttr['title']?.toString() ?? 'Prestation sans titre';
          final startDateStr = delAttr['startDate']?.toString();
          final endDateStr = delAttr['endDate']?.toString();
          
          final dependsOn = delivery['relationships']?['dependsOn']?['data'];
          final purchaseRel = delivery['relationships']?['purchase']?['data'];

          buffer.writeln("\nPrestation : $delTitle (ID: $delId)");
          buffer.writeln("Dates : $startDateStr au $endDateStr");

          if (startDateStr == null || endDateStr == null) {
            buffer.writeln("[Alerte] Dates de prestation manquantes.");
            continue;
          }

          final startDate = DateTime.parse(startDateStr);
          final endDate = DateTime.parse(endDateStr);

          final double costsSimulated = double.tryParse(delAttr['costsSimulatedExcludingTax']?.toString() ?? '0') ?? 0;
          final double totalQuantity = double.tryParse(delAttr['numberOfDaysInvoicedOrQuantity']?.toString() ?? '0') ?? 0;
          double averageDailyCost = 0;
          if (totalQuantity > 0) {
            averageDailyCost = costsSimulated / totalQuantity;
          }
          buffer.writeln("TJM d'achat calculé : $averageDailyCost € HT");

          String resourceName = "Inconnu";
          if (dependsOn != null) {
            final resId = int.tryParse(dependsOn['id']?.toString() ?? '');
            if (resId != null) {
              try {
                final res = await service.getResource(resId);
                final rAttr = res['attributes'] ?? {};
                resourceName = "${rAttr['firstName'] ?? ''} ${rAttr['lastName'] ?? ''}".trim();
              } catch (_) {}
            }
          }
          buffer.writeln("Consultant : $resourceName");

          String providerName = "Aucun";
          String providerNum = "Aucun";
          String providerAddr = "Inconnue";
          String providerCity = "Inconnue";
          final purchaseId = int.tryParse(purchaseRel['id']?.toString() ?? '');
          if (purchaseId != null) {
            try {
              final purchase = await service.getPurchase(purchaseId);
              final compRel = purchase['relationships']?['company']?['data'];
              if (compRel != null) {
                final compId = int.tryParse(compRel['id']?.toString() ?? '');
                if (compId != null) {
                  final company = await service.getCompanyInformation(compId);
                  final cAttr = company['attributes'] ?? {};
                  providerName = cAttr['name']?.toString() ?? 'Société sans nom';
                  providerNum = compId.toString();
                  providerAddr = cAttr['address']?.toString() ?? 'Non renseignée';
                  final postcode = cAttr['postcode']?.toString() ?? '';
                  final town = cAttr['town']?.toString() ?? '';
                  final country = cAttr['country']?.toString() ?? '';
                  providerCity = "$postcode $town $country".trim();
                }
              }
            } catch (e) {
              buffer.writeln("[Alerte] Erreur lors du chargement de l'achat/fournisseur : $e");
            }
          }
          buffer.writeln("Fournisseur : $providerName (N° : $providerNum)");
          buffer.writeln("Adresse : $providerAddr - $providerCity");

          DateTime temp = DateTime(startDate.year, startDate.month, 1);
          final endLimit = DateTime(endDate.year, endDate.month, 1);

          buffer.writeln("Calcul des UO théoriques mobilisables par mois :");
          while (temp.isBefore(endLimit) || temp.isAtSameMomentAs(endLimit)) {
            final year = temp.year;
            final month = temp.month;
            final monthName = _getMonthName(month);

            final firstOfMonth = DateTime(year, month, 1);
            final lastOfMonth = DateTime(year, month + 1, 0);

            int uoCount = 0;
            if (startDate.isAfter(firstOfMonth) || endDate.isBefore(lastOfMonth)) {
              final calcStart = startDate.isAfter(firstOfMonth) ? startDate : firstOfMonth;
              final calcEnd = endDate.isBefore(lastOfMonth) ? endDate : lastOfMonth;
              uoCount = _countWorkingDays(calcStart, calcEnd, holidays);
              buffer.writeln(" - $monthName $year : $uoCount UO (Décompte partiel)");
            } else {
              uoCount = _countWorkingDays(firstOfMonth, lastOfMonth, holidays);
              buffer.writeln(" - $monthName $year : $uoCount UO (Mois complet)");
            }

            final yearSuffix = year.toString().substring(2);
            final monthSuffix = month.toString().padLeft(2, '0');
            final bdcRef = "VIV-PO-$providerNum-$yearSuffix$monthSuffix";
            final bdcMontant = uoCount * averageDailyCost;

            buffer.writeln("   ➔ Réf BDC simulée : $bdcRef | Montant max : $bdcMontant € HT");

            temp = DateTime(year, month + 1, 1);
          }
        }
        buffer.writeln("\n");
      }

      final endTime = DateTime.now();
      final duration = endTime.difference(startTime).inMilliseconds;

      setState(() {
        _isLoading = false;
        _apiCallsCount++;
        _statusText = "Simulation multi-projets réussie en $duration ms.";
        _jsonResponse = buffer.toString();
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusText = "Erreur de simulation multi-projets :\n$e";
        _jsonResponse = "";
      });
    }
  }

  String _getMonthName(int month) {
    const months = ["Janvier", "Février", "Mars", "Avril", "Mai", "Juin", "Juillet", "Août", "Septembre", "Octobre", "Novembre", "Décembre"];
    return months[month - 1];
  }

  int _countWorkingDays(DateTime start, DateTime end, List<DateTime> holidays) {
    int count = 0;
    DateTime current = start;
    while (current.isBefore(end) || current.isAtSameMomentAs(end)) {
      if (current.weekday != DateTime.saturday && current.weekday != DateTime.sunday) {
        final isHoliday = holidays.any((h) => h.year == current.year && h.month == current.month && h.day == current.day);
        if (!isHoliday) {
          count++;
        }
      }
      current = current.add(const Duration(days: 1));
    }
    return count;
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
              Text("Outil de Diagnostic API (Lecture Seule)", style: VivTypography.h3),
              const SizedBox(height: 4),
              Text(
                "Testez les requêtes optimisées vers BoondManager pour valider les inclusions relationnelles.",
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
          Text("FILTRES & PARAMÈTRES", style: VivTypography.eyebrow),
          const SizedBox(height: VivSpacing.space4),
          
          Text("ID Agence / ID Projet (Optionnel)", style: VivTypography.small.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          ShadInput(
            placeholder: const Text("ex: 1 (Sert d'ID Projet pour l'appel Prestations)"),
            onChanged: (val) => setState(() => _agencyId = val.trim()),
          ),
          
          const SizedBox(height: VivSpacing.space6),
          Text("INCLUSIONS RELATIONNELLES JSON:API", style: VivTypography.small.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          
          ShadCheckbox(
            value: _includeDeliveries,
            onChanged: (val) => setState(() => _includeDeliveries = val),
            label: const Text("Prestations (deliveries)"),
          ),
          const SizedBox(height: 4),
          ShadCheckbox(
            value: _includePurchase,
            enabled: _includeDeliveries,
            onChanged: (val) => setState(() => _includePurchase = val),
            label: const Text("Achats sous-traitants (deliveries.purchase)"),
          ),
          const SizedBox(height: 4),
          ShadCheckbox(
            value: _includeCompany,
            enabled: _includeDeliveries && _includePurchase,
            onChanged: (val) => setState(() => _includeCompany = val),
            label: const Text("Société Fournisseur (deliveries.purchase.company)"),
          ),

          const SizedBox(height: VivSpacing.space8),
          Text("ACTIONS DE DIAGNOSTIC", style: VivTypography.eyebrow),
          const SizedBox(height: VivSpacing.space4),
          
          SizedBox(
            width: double.infinity,
            child: ShadButton(
              backgroundColor: VivColors.lime,
              onPressed: _isLoading ? null : _runProjectsTest,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.play, size: 16),
                  SizedBox(width: 8),
                  Text("Tester l'appel GET Projets"),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ShadButton(
              backgroundColor: Colors.blueGrey,
              onPressed: _isLoading ? null : _runPurchasesTest,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.shoppingBag, size: 16),
                  SizedBox(width: 8),
                  Text("Tester l'appel GET Achats (Purchases)"),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ShadButton(
              backgroundColor: Colors.teal,
              onPressed: _isLoading ? null : _runDeliveriesTest,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.folderClosed, size: 16),
                  SizedBox(width: 8),
                  Text("Tester GET Prestations (Deliveries)"),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ShadButton(
              backgroundColor: Colors.blueAccent,
              onPressed: _isLoading ? null : _runFullBdcSimulation,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.binary, size: 16),
                  SizedBox(width: 8),
                  Text("Simuler flux complet BDC"),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text("Destinataire Email Test SMTP", style: VivTypography.small.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          ShadInput(
            placeholder: const Text("Destinataire (ex: votre@email.com)"),
            onChanged: (val) => setState(() => _smtpTestRecipient = val.trim()),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: ShadButton(
              backgroundColor: Colors.indigo,
              onPressed: _isLoading ? null : _runSmtpTest,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.mail, size: 16),
                  SizedBox(width: 8),
                  Text("Tester l'envoi SMTP (Étape 2)"),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ShadButton.outline(
              onPressed: _isLoading ? null : _runHolidaysTest,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.calendarDays, size: 16),
                  SizedBox(width: 8),
                  Text("Tester l'appel Jours Fériés"),
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
            Text("STATUT & LOG DE RÉPONSE", style: VivTypography.eyebrow),
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
            style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: VivColors.black),
          ),
        ),
        const SizedBox(height: VivSpacing.space4),
        Text("RÉPONSE JSON BRUTE", style: VivTypography.eyebrow),
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
                    ? const Center(child: Text("Aucune donnée chargée.", style: TextStyle(color: Colors.white60, fontSize: 12)))
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
