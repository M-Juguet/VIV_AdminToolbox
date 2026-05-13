import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/dashboard_stats.dart';
import '../services/boond_service.dart';
import '../services/calendar_service.dart';
import 'settings_provider.dart';

final dashboardProvider = NotifierProvider<DashboardNotifier, DashboardStats>(
  () {
    return DashboardNotifier();
  },
);

class DashboardNotifier extends Notifier<DashboardStats> {
  // Caches persistants pour minimiser les appels API (Purchases, Companies, Contacts)
  final Map<int, Map<String, dynamic>> _purchaseCache = {};
  final Map<int, Map<String, dynamic>> _companyCache = {};
  final Map<int, List<dynamic>> _contactsCache = {};

  @override
  DashboardStats build() {
    // On watch le boondUser. Si l'utilisateur change ou se déconnecte, 
    // le Notifier est entièrement reconstruit (état réinitialisé).
    ref.watch(settingsProvider.select((s) => s.boondUser));
    
    return DashboardStats();
  }

  void reset() {
    state = DashboardStats();
    _purchaseCache.clear();
    _companyCache.clear();
    _contactsCache.clear();
  }

  Future<void> changeMonth(DateTime newMonth) async {
    state = state.copyWith(selectedMonth: newMonth);
    await refresh();
  }

  Future<void> selectAgency(String id, String name) async {
    state = state.copyWith(selectedAgencyId: id, selectedAgencyName: name);
    await refresh();
  }

  /// Initialisation intelligente : ne charge que si les données sont absentes
  Future<void> init() async {
    if (state.agencies.isEmpty && !state.isLoading) {
      await refresh();
    }
  }

  Future<void> refresh({bool onlyCompliance = false}) async {
    final settings = ref.read(settingsProvider);

    // Si la config est vide, on vide impérativement la mémoire
    if (settings.boondUrl.isEmpty || settings.boondUser.isEmpty) {
      reset();
      state = state.copyWith(
        error: "Configuration BoondManager requise",
        isLoading: false,
      );
      return;
    }

    if (onlyCompliance) {
      state = state.copyWith(isComplianceLoading: true);
    } else {
      state = state.copyWith(isLoading: true, clearError: true);
      // On vide le cache persistant sur un refresh global ou changement d'agence
      _purchaseCache.clear();
      _companyCache.clear();
      _contactsCache.clear();
    }

    try {
      final service = BoondService(
        baseUrl: settings.boondUrl,
        user: settings.boondUser,
        password: settings.boondPassword,
      );

      // 1. Profil et Agence
      final profile = await service.getCurrentUserProfile();
      final profileAgencyId =
          profile['relationships']?['agency']?['data']?['id']?.toString();
      final profileAgencyName =
          profile['relationships']?['agency']?['data']?['name']?.toString();

      // Charger les agences si vide
      List<Map<String, String>> agencies = state.agencies;
      if (agencies.isEmpty) {
        final rawAgencies = await service.getAgencies();
        agencies = rawAgencies
            .map(
              (e) => {
                'id': e['id'].toString(),
                'name': e['name'].toString(),
                'calendarId': e['calendarId']?.toString() ?? '',
              },
            )
            .toList();
      }

      // Agence active : soit celle sélectionnée, soit celle du profil par défaut
      final activeAgencyId = state.selectedAgencyId ?? profileAgencyId;
      final activeAgency = agencies.firstWhere(
        (a) => a['id'] == activeAgencyId,
        orElse: () => {
          'name': profileAgencyName ?? 'Inconnue',
          'calendarId': '',
        },
      );
      final activeAgencyName = state.selectedAgencyName ?? activeAgency['name'];
      final activeCalendarId = activeAgency['calendarId'];

      // 2. Référentiel
      final dict = await service.getDictionary();
      final data = dict['data'] as Map<String, dynamic>;
      final setting = data['setting'] as Map<String, dynamic>;

      final activeProjectStateId = _findId(
        setting['state']?['project'] ?? [],
        'en cours',
        fallback: 1,
      );
      final pendingOrderStateId = _findId(
        setting['state']?['order'] ?? [],
        'en attente',
        fallback: 3,
      );
      final validatedOrderStateId = _findId(
        setting['state']?['order'] ?? [],
        'en cours',
        fallback: 1,
      );

      // 3. Dates & Vacances
      final firstDayOfMonth = DateTime(
        state.selectedMonth.year,
        state.selectedMonth.month,
        1,
      );
      final lastDayOfMonth = DateTime(
        state.selectedMonth.year,
        state.selectedMonth.month + 1,
        0,
      );
      final holidays = await service.getHolidays(
        state.selectedMonth.year,
        agencyId: activeCalendarId,
      );

      final totalWorkingDaysMonth = CalendarService.calculateWorkingDays(
        start: firstDayOfMonth,
        end: lastDayOfMonth,
        holidays: holidays,
      ).toInt();

      int totalHolidaysMonth = 0;
      for (var holidayStr in holidays) {
        final holidayDate = DateTime.tryParse(holidayStr);
        if (holidayDate != null &&
            holidayDate.month == state.selectedMonth.month &&
            holidayDate.year == state.selectedMonth.year) {
          if (holidayDate.weekday >= 1 && holidayDate.weekday <= 5) {
            totalHolidaysMonth++;
          }
        }
      }

      // 4. Projets actifs sur l'agence
      final Map<String, dynamic> projectFilters = {
        'states[]': activeProjectStateId,
      };
      if (activeAgencyId != null) {
        projectFilters['agency'] = activeAgencyId;
      }
      var allAgencyProjects = await service.getProjects(
        filters: projectFilters,
      );

      // Filtrage agence local (sécurité)
      if (activeAgencyId != null) {
        allAgencyProjects = allAgencyProjects.where((p) {
          final pAgencyId = p['relationships']?['agency']?['data']?['id']
              ?.toString();
          return pAgencyId == activeAgencyId;
        }).toList();
      }

      // Filtrage temporel strict (Demande utilisateur : inutile de traiter les projets hors période)
      final projects = allAgencyProjects.where((p) {
        final pAttr = p['attributes'];
        final pStart = DateTime.tryParse(pAttr['startDate']?.toString() ?? '');
        final pEnd = DateTime.tryParse(pAttr['endDate']?.toString() ?? '');

        return CalendarService.getIntersection(
              prestationStart: pStart ?? DateTime(1970),
              prestationEnd: pEnd,
              month: state.selectedMonth.month,
              year: state.selectedMonth.year,
            ) !=
            null;
      }).toList();

      // 5. Commandes (Optionnel si onlyCompliance)
      List<dynamic> allOrders = [];
      if (!onlyCompliance) {
        final Map<String, dynamic> orderFilters = {};
        if (activeAgencyId != null) orderFilters['agency'] = activeAgencyId;
        allOrders = await service.getOrders(filters: orderFilters);

        if (activeAgencyId != null) {
          allOrders = allOrders.where((o) {
            final oAgencyId = o['relationships']?['agency']?['data']?['id']
                ?.toString();
            return oAgencyId == activeAgencyId;
          }).toList();
        }
      }

      // --- CALCULS ---
      final now = DateTime.now();
      final targetRenewalDate = now.add(const Duration(days: 30));

      int upcomingRenewals = onlyCompliance ? state.upcomingRenewals : 0;
      int externalPrestationsCount = 0;
      double totalPlannedDays = 0.0;
      List<ComplianceAlert> alerts = [];

      for (var project in projects) {
        final projectId = int.tryParse(project['id'].toString()) ?? 0;
        final attributes = project['attributes'];

        // Renewals : On ne recalcule que si on n'est pas en mode "onlyCompliance"
        if (!onlyCompliance) {
          final endDateStr = attributes['endDate']?.toString();
          if (endDateStr != null && endDateStr.isNotEmpty) {
            final endDate = DateTime.tryParse(endDateStr);
            if (endDate != null &&
                endDate.isBefore(targetRenewalDate) &&
                endDate.isAfter(now)) {
              upcomingRenewals++;
            }
          }
        }

        // --- PRESTATIONS ---
        try {
          final deliveries = await service.getDeliveries(projectId);

          for (var delivery in deliveries) {
            final delAttr = delivery['attributes'] ?? {};
            final delRel = delivery['relationships'] ?? {};
            final delTitle = (delAttr['title']?.toString() ?? '').trim();
            final delId = delivery['id'].toString();
            final delRef = delAttr['reference']?.toString() ?? "MIS$delId";

            final delStart = DateTime.tryParse(
              delAttr['startDate']?.toString() ?? '',
            );
            final delEnd = DateTime.tryParse(
              delAttr['endDate']?.toString() ?? '',
            );
            final purchaseIdRaw = delRel['purchase']?['data']?['id'];

            if (delStart != null) {
              final intersection = CalendarService.getIntersection(
                prestationStart: delStart,
                prestationEnd: delEnd,
                month: state.selectedMonth.month,
                year: state.selectedMonth.year,
              );

              if (intersection != null) {
                // 1. KPIs
                if (purchaseIdRaw != null) {
                  externalPrestationsCount++;
                  final workingDays = CalendarService.calculateWorkingDays(
                    start: intersection['start']!,
                    end: intersection['end']!,
                    holidays: holidays,
                  );
                  totalPlannedDays += workingDays;
                }

                // 2. Conformité
                if (purchaseIdRaw == null) {
                  // ALERTE : Prestation sans Achat
                  final label = delTitle.isEmpty
                      ? "***$delRef***"
                      : "***$delTitle*** (***$delRef***)";
                  alerts.add(
                    ComplianceAlert(
                      title: "Lien Achat manquant",
                      description:
                          "Projet ${attributes['reference']} : La prestation $label n'est liée à aucun achat.",
                      severity: AlertSeverity.critical,
                      actionUrl:
                          "https://ui.boondmanager.com/deliveries/$delId",
                    ),
                  );
                } else {
                  final pId = int.tryParse(purchaseIdRaw.toString()) ?? 0;
                  try {
                    final purchase =
                        _purchaseCache[pId] ?? await service.getPurchase(pId);
                    _purchaseCache[pId] = purchase;

                    final companyRel =
                        purchase['relationships']?['company']?['data'];
                    if (companyRel == null) {
                      final label = delTitle.isEmpty
                          ? "***$delRef***"
                          : "***$delTitle*** (***$delRef***)";
                      alerts.add(
                        ComplianceAlert(
                          title: "Achat sans fournisseur",
                          description:
                              "Projet ${attributes['reference']} : L'achat lié à $label n'a aucun fournisseur rattaché.",
                          severity: AlertSeverity.critical,
                          actionUrl:
                              "https://ui.boondmanager.com/deliveries/$delId",
                        ),
                      );
                    } else {
                      final companyId =
                          int.tryParse(companyRel['id'].toString()) ?? 0;
                      final company =
                          _companyCache[companyId] ??
                          await service.getCompany(companyId);
                      _companyCache[companyId] = company;

                      final comAttr = company['attributes'] ?? {};
                      final rawCompanyName =
                          comAttr['name'] ?? 'Fournisseur inconnu';
                      final comRef =
                          comAttr['reference']?.toString() ?? "CSOC$companyId";
                      final companyDisplayName =
                          "***$rawCompanyName*** (***$comRef***)";
                      final companyUrl =
                          "https://ui.boondmanager.com/companies/$companyId";

                      final contacts =
                          _contactsCache[companyId] ??
                          await service.getCompanyContacts(companyId);
                      _contactsCache[companyId] = contacts;

                      dynamic selectedContact;
                      bool alertMissing = false;
                      bool alertMultiple = false;

                      if (contacts.isEmpty) {
                        alertMissing = true;
                      } else if (contacts.length == 1) {
                        // Cas 1 : Un seul contact trouvé, on l'utilise directement
                        selectedContact = contacts.first;
                      } else {
                        // Cas 2 : Plusieurs contacts, on cherche celui qui est Validé (9) et Administratif (5)
                        final filtered = contacts.where((c) {
                          final cAttr = c['attributes'] ?? {};
                          return cAttr['state'].toString() == '9' &&
                              cAttr['typeOf'].toString() == '5';
                        }).toList();

                        if (filtered.length == 1) {
                          selectedContact = filtered.first;
                        } else if (filtered.isEmpty) {
                          alertMissing = true;
                        } else {
                          alertMultiple = true;
                        }
                      }

                      if (alertMissing) {
                        alerts.add(
                          ComplianceAlert(
                            title: "Contact Administratif Manquant",
                            description:
                                "Le fournisseur $companyDisplayName n'a pas de contact administratif valide.",
                            severity: AlertSeverity.warning,
                            actionUrl: companyUrl,
                          ),
                        );
                      } else if (alertMultiple) {
                        alerts.add(
                          ComplianceAlert(
                            title: "Multiples Contacts Administratifs",
                            description:
                                "Le fournisseur $companyDisplayName possède plusieurs contacts administratifs sans distinction claire.",
                            severity: AlertSeverity.warning,
                            actionUrl: companyUrl,
                          ),
                        );
                      } else if (selectedContact != null) {
                        // Validation de l'email du contact sélectionné
                        final attr = selectedContact['attributes'] ?? {};
                        final email = (attr['email'] ??
                                attr['email1'] ??
                                attr['emailOne'] ??
                                attr['emailPro'])
                            ?.toString();
                        if (email == null || !email.contains('@')) {
                          alerts.add(
                            ComplianceAlert(
                              title: "Email Invalide",
                              description:
                                  "Le contact administratif de $companyDisplayName n'a pas de mail valide.",
                              severity: AlertSeverity.critical,
                              actionUrl: companyUrl,
                            ),
                          );
                        }
                      }
                    }
                  } catch (e) {
                    final label = delTitle.isEmpty
                        ? "***$delRef***"
                        : "***$delTitle*** (***$delRef***)";
                    alerts.add(
                      ComplianceAlert(
                        title: "Lien Achat rompu",
                        description:
                            "Projet ${attributes['reference']} : La prestation $label pointe vers un achat inaccessible.",
                        severity: AlertSeverity.critical,
                        actionUrl:
                            "https://ui.boondmanager.com/deliveries/$delId",
                      ),
                    );
                  }
                }
              }
            }
          }
        } catch (_) {}
      }

      int pendingOrders = state.pendingOrders;
      int closedOrdersThisMonth = state.closedOrdersThisMonth;
      if (!onlyCompliance) {
        pendingOrders = 0;
        closedOrdersThisMonth = 0;
        for (var order in allOrders) {
          final attr = order['attributes'];
          if (attr['state'] == pendingOrderStateId) {
            pendingOrders++;
          }
          if (attr['state'] == validatedOrderStateId) {
            final date = DateTime.tryParse(attr['date']?.toString() ?? '');
            if (date != null &&
                date.month == now.month &&
                date.year == now.year) {
              closedOrdersThisMonth++;
            }
          }
        }
      }

      state = state.copyWith(
        upcomingRenewals: upcomingRenewals,
        pendingOrders: pendingOrders,
        closedOrdersThisMonth: closedOrdersThisMonth,
        externalPrestationsCount: externalPrestationsCount,
        totalPlannedDays: totalPlannedDays,
        totalWorkingDaysMonth: totalWorkingDaysMonth,
        totalHolidaysMonth: totalHolidaysMonth,
        alerts: alerts,
        isLoading: false,
        isComplianceLoading: false,
        clearError: true,
        agencies: agencies,
        selectedAgencyId: activeAgencyId,
        selectedAgencyName: activeAgencyName,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isComplianceLoading: false,
        error: e.toString(),
      );
    }
  }

  int _findId(List<dynamic> list, String labelPart, {required int fallback}) {
    try {
      final entry = list.firstWhere(
        (e) => e['value'].toString().toLowerCase().contains(
          labelPart.toLowerCase(),
        ),
        orElse: () => null,
      );
      return entry != null
          ? int.tryParse(entry['id'].toString()) ?? fallback
          : fallback;
    } catch (_) {
      return fallback;
    }
  }
}
