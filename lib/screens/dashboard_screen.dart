import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/string_extensions.dart';
import '../design_system/viv_colors.dart';
import '../design_system/viv_spacing.dart';
import '../design_system/viv_typography.dart';
import '../models/app_settings.dart';
import '../models/dashboard_stats.dart';
import '../providers/settings_provider.dart';
import '../providers/dashboard_provider.dart';
import 'main_shell.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Chargement initial seulement si nécessaire (mémoire interne)
    Future.microtask(() => ref.read(dashboardProvider.notifier).init());
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final stats = ref.watch(dashboardProvider);
    final isConfigured = settings.boondUrl.isNotEmpty && settings.boondUser.isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(VivSpacing.space6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context, settings, stats),
          if (stats.error != null)
            Padding(
              padding: const EdgeInsets.only(top: VivSpacing.space6),
              child: _buildErrorState(stats.error!),
            )
          else if (isConfigured) // Uniquement si configuré
            if (!stats.isInitialized && !stats.isLoading)
              _buildManualLoadPrompt()
            else if (stats.isLoading && !stats.isInitialized)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 80),
                child: Center(
                  child: CircularProgressIndicator(
                    color: VivColors.lime,
                  ),
                ),
              )
            else
              Column(
                children: [
                  const SizedBox(height: VivSpacing.space6),
                  _buildStatsGrid(stats),
                  const SizedBox(height: VivSpacing.space4),
                  _buildCalendarGrid(stats),
                  const SizedBox(height: VivSpacing.space8),
                  _buildAlertsSection(stats),
                  const SizedBox(height: VivSpacing.space8),
                ],
              )
          else // Message d'invitation si non configuré
            _buildEmptyState(),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid(DashboardStats stats) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GridView.count(
          crossAxisCount: constraints.maxWidth > 800 ? 3 : 1,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: VivSpacing.space4,
          mainAxisSpacing: VivSpacing.space4,
          childAspectRatio: constraints.maxWidth > 800 ? 4.0 : 5.0,
          children: [
            _buildSmallInfoCard(
              'Jours Ouvrés (Mois)',
              '${stats.totalWorkingDaysMonth} jours',
              LucideIcons.calendarDays,
              VivColors.gray500,
            ),
            _buildSmallInfoCard(
              'Jours Fériés (Mois)',
              '${stats.totalHolidaysMonth} jours',
              LucideIcons.treePalm,
              Colors.orange,
            ),
          ],
        );
      },
    );
  }

  Widget _buildSmallInfoCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return ShadCard(
      padding: const EdgeInsets.symmetric(
        horizontal: VivSpacing.space4,
        vertical: VivSpacing.space3,
      ),
      backgroundColor: VivColors.paper.withValues(alpha: 0.5),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: VivSpacing.space3),
          Text(
            title,
            style: VivTypography.small.copyWith(
              color: VivColors.gray500,
              fontSize: 13,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: VivTypography.small.copyWith(
              fontWeight: FontWeight.bold,
              color: VivColors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return ShadCard(
      padding: const EdgeInsets.all(VivSpacing.space6),
      backgroundColor: VivColors.paper,
      child: Center(
        child: Column(
          children: [
            Icon(LucideIcons.circleAlert, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              "Erreur de récupération",
              style: VivTypography.h4.copyWith(color: VivColors.black),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: VivTypography.small.copyWith(color: VivColors.gray500),
            ),
            const SizedBox(height: 16),
            ShadButton.outline(
              onPressed: () => ref.read(dashboardProvider.notifier).refresh(),
              child: const Text("Réessayer"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    AppSettings settings,
    DashboardStats stats,
  ) {
    final isConfigured =
        settings.boondUrl.isNotEmpty && settings.boondUser.isNotEmpty;
    final displayName = isConfigured
        ? (settings.boondFirstName.isNotEmpty
            ? settings.boondFirstName
            : "Admin VIV")
        : "sur Opsis Compliance";

    // Formater le mois sélectionné (ex: Mars 2024)
    final monthFormat = DateFormat.yMMMM('fr_FR');
    final monthLabel = monthFormat.format(stats.selectedMonth);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isConfigured ? 'Bonjour $displayName' : 'Bienvenue $displayName', style: VivTypography.h2),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isConfigured ? VivColors.lime : VivColors.gray300,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  isConfigured
                      ? 'Période : ${monthLabel.capitalize()}'
                      : 'BoondManager non configuré',
                  style: VivTypography.small.copyWith(
                    color: VivColors.gray500,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (stats.isLoading) ...[
                  const SizedBox(width: 12),
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: VivColors.lime,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        Row(
          children: [
            if (isConfigured && stats.isInitialized)
              ShadButton.outline(
                onPressed: stats.isLoading
                    ? null
                    : () => ref.read(dashboardProvider.notifier).refresh(),
                child: const Row(
                  children: [
                    Icon(LucideIcons.refreshCcw, size: 14),
                    SizedBox(width: 8),
                    Text("Actualiser"),
                  ],
                ),
              ),
            const SizedBox(width: 8),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsGrid(DashboardStats stats) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GridView.count(
          crossAxisCount: constraints.maxWidth > 800 ? 3 : 1,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: VivSpacing.space4,
          mainAxisSpacing: VivSpacing.space4,
          childAspectRatio: constraints.maxWidth > 800 ? 2.5 : 4.0,
          children: [
            _buildStatCard(
              'Renouvellements (< 30j)',
              stats.upcomingRenewals.toString(),
              LucideIcons.calendarClock,
              VivColors.black,
            ),
            _buildStatCard(
              'BdC à générer',
              stats.externalPrestationsCount.toString(),
              LucideIcons.fileSpreadsheet,
              VivColors.lime,
            ),
            _buildStatCard(
              'Total Jours Prévus',
              '${stats.totalPlannedDays.toStringAsFixed(1)} j',
              LucideIcons.sigma,
              VivColors.green600,
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color accentColor,
  ) {
    return ShadCard(
      padding: const EdgeInsets.all(VivSpacing.space5),
      backgroundColor: VivColors.paper,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(VivSpacing.radiusMd),
            ),
            child: Icon(icon, color: accentColor, size: 24),
          ),
          const SizedBox(width: VivSpacing.space4),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: VivTypography.small.copyWith(color: VivColors.gray500),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  value,
                  style: VivTypography.h3.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertsSection(DashboardStats stats) {
    if (stats.alerts.isEmpty && !stats.isLoading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(LucideIcons.shieldCheck, "Conformité", stats),
          const SizedBox(height: VivSpacing.space4),
          ShadCard(
            backgroundColor: VivColors.paper,
            padding: const EdgeInsets.all(VivSpacing.space8),
            child: Center(
              child: Column(
                children: [
                  Icon(LucideIcons.sparkles, color: VivColors.lime, size: 32),
                  const SizedBox(height: 12),
                  Text("Tout est en ordre !", style: VivTypography.h4),
                  Text(
                    "Aucune anomalie détectée sur les projets actifs.",
                    style: VivTypography.small.copyWith(
                      color: VivColors.gray500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          LucideIcons.shieldAlert,
          "Alertes de conformité",
          stats,
        ),
        const SizedBox(height: VivSpacing.space4),
        ...stats.alerts.map(
          (alert) => Padding(
            padding: const EdgeInsets.only(bottom: VivSpacing.space3),
            child: ShadCard(
              backgroundColor: VivColors.paper,
              padding: const EdgeInsets.all(VivSpacing.space4),
              child: Row(
                children: [
                  Icon(
                    alert.severity == AlertSeverity.critical
                        ? LucideIcons.triangleAlert
                        : LucideIcons.info,
                    color: alert.severity == AlertSeverity.critical
                        ? Colors.red
                        : VivColors.lime,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          alert.title,
                          style: VivTypography.small.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        _buildStyledText(
                          alert.description,
                          VivTypography.small.copyWith(
                            color: VivColors.gray500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ShadButton.ghost(
                    onPressed: alert.actionUrl != null
                        ? () => launchUrl(Uri.parse(alert.actionUrl!))
                        : null,
                    child: const Text("Corriger"),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 80),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: ShadCard(
            padding: const EdgeInsets.all(VivSpacing.space8),
            backgroundColor: VivColors.paper,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: VivColors.lime.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    LucideIcons.databaseZap,
                    size: 40,
                    color: VivColors.lime,
                  ),
                ),
                const SizedBox(height: VivSpacing.space6),
                Text(
                  "Configuration requise",
                  style: VivTypography.h3,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: VivSpacing.space4),
                Text(
                  "Veuillez vous connecter à votre compte BoondManager pour accéder au tableau de bord et aux alertes de conformité.",
                  textAlign: TextAlign.center,
                  style: VivTypography.small.copyWith(
                    color: VivColors.gray500,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: VivSpacing.space8),
                ShadButton(
                  onPressed: () {
                    ref.read(navigationIndexProvider.notifier).state = 5;
                  },
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.settings, size: 16),
                      SizedBox(width: 8),
                      Text("Configurer BoondManager"),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    IconData icon,
    String title,
    DashboardStats stats,
  ) {
    return Row(
      children: [
        Icon(icon, size: 20, color: VivColors.black),
        const SizedBox(width: 8),
        Text(title, style: VivTypography.h4),
        const SizedBox(width: 12),
        // Le rafraîchissement cible maintenant uniquement la conformité
        if (title.contains("conformité") && stats.isComplianceLoading)
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: VivColors.lime,
            ),
          )
        else if (title.contains("conformité"))
          IconButton(
            onPressed: () => ref
                .read(dashboardProvider.notifier)
                .refresh(onlyCompliance: true),
            icon: const Icon(LucideIcons.refreshCcw, size: 14),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: "Actualiser la conformité",
          ),
      ],
    );
  }

  Widget _buildStyledText(String text, TextStyle baseStyle) {
    final List<TextSpan> spans = [];
    final parts = text.split('***');

    for (int i = 0; i < parts.length; i++) {
      if (i % 2 == 1) {
        // Segment en gras italique
        spans.add(
          TextSpan(
            text: parts[i],
            style: baseStyle.copyWith(
              fontWeight: FontWeight.bold,
              fontStyle: FontStyle.italic,
              color: VivColors.black,
            ),
          ),
        );
      } else {
        // Segment normal
        spans.add(TextSpan(text: parts[i]));
      }
    }

    return RichText(
      text: TextSpan(style: baseStyle, children: spans),
    );
  }

  Widget _buildManualLoadPrompt() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 80),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: ShadCard(
            padding: const EdgeInsets.all(VivSpacing.space8),
            backgroundColor: VivColors.paper,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: VivColors.lime.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    LucideIcons.refreshCcw,
                    size: 40,
                    color: VivColors.lime,
                  ),
                ),
                const SizedBox(height: VivSpacing.space6),
                Text(
                  "Synchronisation requise",
                  style: VivTypography.h3,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: VivSpacing.space4),
                Text(
                  "Afin de préserver vos quotas d'appels API BoondManager, les indicateurs et alertes de conformité ne sont pas chargés automatiquement.",
                  textAlign: TextAlign.center,
                  style: VivTypography.small.copyWith(
                    color: VivColors.gray500,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: VivSpacing.space8),
                ShadButton(
                  onPressed: () {
                    ref.read(dashboardProvider.notifier).refresh();
                  },
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.play, size: 16),
                      SizedBox(width: 8),
                      Text("Charger les données"),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
