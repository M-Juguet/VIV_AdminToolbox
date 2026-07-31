class DashboardStats {
  final DateTime selectedMonth;
  final int upcomingRenewals;
  final int pendingOrders;
  final int closedOrdersThisMonth;
  final int externalPrestationsCount; // Nouveau : Prestations "Freelance" détectées
  final double totalPlannedDays; // Nouveau : Somme des jours ouvrés calculés
  final int totalWorkingDaysMonth; // Nouveau : Jours ouvrés théoriques du mois
  final int totalHolidaysMonth; // Nouveau : Jours fériés détectés dans le mois
  final List<ComplianceAlert> alerts;
  final bool isLoading;
  final bool isComplianceLoading; // Nouvel état discret
  final String? error;
  final List<Map<String, String>> agencies;
  final String? selectedAgencyId;
  final String? selectedAgencyName;
  final bool isInitialized; // Indique si le chargement a déjà été effectué au moins une fois

  DashboardStats({
    DateTime? selectedMonth,
    this.upcomingRenewals = 0,
    this.pendingOrders = 0,
    this.closedOrdersThisMonth = 0,
    this.externalPrestationsCount = 0,
    this.totalPlannedDays = 0.0,
    this.totalWorkingDaysMonth = 0,
    this.totalHolidaysMonth = 0,
    this.alerts = const [],
    this.isLoading = false,
    this.isComplianceLoading = false,
    this.error,
    this.agencies = const [],
    this.selectedAgencyId,
    this.selectedAgencyName,
    this.isInitialized = false,
  }) : selectedMonth = selectedMonth ?? DateTime(DateTime.now().year, DateTime.now().month, 1);

  DashboardStats copyWith({
    DateTime? selectedMonth,
    int? upcomingRenewals,
    int? pendingOrders,
    int? closedOrdersThisMonth,
    int? externalPrestationsCount,
    double? totalPlannedDays,
    int? totalWorkingDaysMonth,
    int? totalHolidaysMonth,
    List<ComplianceAlert>? alerts,
    bool? isLoading,
    bool? isComplianceLoading,
    String? error,
    bool clearError = false,
    List<Map<String, String>>? agencies,
    String? selectedAgencyId,
    String? selectedAgencyName,
    bool? isInitialized,
  }) {
    return DashboardStats(
      selectedMonth: selectedMonth ?? this.selectedMonth,
      upcomingRenewals: upcomingRenewals ?? this.upcomingRenewals,
      pendingOrders: pendingOrders ?? this.pendingOrders,
      closedOrdersThisMonth: closedOrdersThisMonth ?? this.closedOrdersThisMonth,
      externalPrestationsCount: externalPrestationsCount ?? this.externalPrestationsCount,
      totalPlannedDays: totalPlannedDays ?? this.totalPlannedDays,
      totalWorkingDaysMonth: totalWorkingDaysMonth ?? this.totalWorkingDaysMonth,
      totalHolidaysMonth: totalHolidaysMonth ?? this.totalHolidaysMonth,
      alerts: alerts ?? this.alerts,
      isLoading: isLoading ?? this.isLoading,
      isComplianceLoading: isComplianceLoading ?? this.isComplianceLoading,
      error: clearError ? null : (error ?? this.error),
      agencies: agencies ?? this.agencies,
      selectedAgencyId: selectedAgencyId ?? this.selectedAgencyId,
      selectedAgencyName: selectedAgencyName ?? this.selectedAgencyName,
      isInitialized: isInitialized ?? this.isInitialized,
    );
  }
}

class ComplianceAlert {
  final String title;
  final String description;
  final AlertSeverity severity;
  final String? actionUrl; // URL pour corriger l'anomalie

  ComplianceAlert({
    required this.title,
    required this.description,
    this.severity = AlertSeverity.info,
    this.actionUrl,
  });
}

enum AlertSeverity { info, warning, critical }
