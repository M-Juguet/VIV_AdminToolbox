import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../design_system/viv_colors.dart';
import '../design_system/viv_spacing.dart';
import '../design_system/viv_typography.dart';
import 'tools/resource_finder_screen.dart';
import 'tools/bdc_diagnostic_screen.dart';
import 'tools/data_extraction_widget.dart';
import 'tools/api_quota_diagnostic_screen.dart';
import 'tools/bdc_rules_diagnostic_screen.dart';
import 'tools/create_resource_tool_screen.dart';
import 'tools/create_company_tool_screen.dart';
import '../services/bdc_sent_logs_service.dart';


class ToolboxScreen extends StatelessWidget {
  const ToolboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(VivSpacing.space6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: VivSpacing.space8),
          _buildCategory(
            context,
            title: "Gestion & Édition",
            icon: LucideIcons.pencilRuler,
            tools: [
              _ToolDefinition(
                title: "Créer un projet",
                description:
                    "Initialiser un nouveau projet BoondManager de zéro ou par duplication d'un existant.",
                icon: LucideIcons.circlePlus,
                onPressed: () {
                  // Prochainement
                },
                status: ToolStatus.comingSoon,
              ),
              _ToolDefinition(
                title: "Créer une prestation",
                description:
                    "Générer une nouvelle prestation (mission) avec les paramètres standard et liens automatiques.",
                icon: LucideIcons.layers,
                onPressed: () {
                  // Prochainement
                },
                status: ToolStatus.comingSoon,
              ),
              _ToolDefinition(
                title: "Créer une ressource",
                description:
                    "Créer et configurer une nouvelle ressource dans BoondManager.",
                icon: LucideIcons.userPlus,
                onPressed: () {
                  showDialog(
                    context: context,
                    barrierDismissible: true,
                    builder: (context) => Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1000, maxHeight: 800),
                          child: CreateResourceToolWidget(
                            onClose: () => Navigator.of(context).pop(),
                          ),
                        ),
                      ),
                    ),
                  );
                },
                status: ToolStatus.wip,
              ),
              _ToolDefinition(
                title: "Créer une société",
                description:
                    "Ajouter une nouvelle fiche société (client ou fournisseur).",
                icon: LucideIcons.building,
                onPressed: () {
                  showDialog(
                    context: context,
                    barrierDismissible: true,
                    builder: (context) => Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1000, maxHeight: 800),
                          child: CreateCompanyToolWidget(
                            onClose: () => Navigator.of(context).pop(),
                          ),
                        ),
                      ),
                    ),
                  );
                },
                status: ToolStatus.wip,
              ),
              _ToolDefinition(
                title: "Créer un contact",
                description:
                    "Créer un nouveau contact rattaché à une fiche société.",
                icon: LucideIcons.contact,
                onPressed: () {
                  // En développement
                },
                status: ToolStatus.wip,
              ),
              _ToolDefinition(
                title: "Gestion des contrats",
                description:
                    "Visualiser, créer et associer des contrats administratifs ou RH.",
                icon: LucideIcons.fileText,
                onPressed: () {
                  // En développement
                },
                status: ToolStatus.wip,
              ),
            ],
          ),
          const SizedBox(height: VivSpacing.space8),
          _buildCategory(
            context,
            title: "Exploration des données",
            icon: LucideIcons.database,
            tools: [
              _ToolDefinition(
                title: "Trouver une prestation",
                description:
                    "Récupérer instantanément les détails d'une prestation via sa référence technique.",
                icon: LucideIcons.search,
                onPressed: () {
                  // Prochainement
                },
                status: ToolStatus.comingSoon,
              ),
              _ToolDefinition(
                title: "Trouver une ressource",
                description:
                    "Rechercher rapidement un prestataire ou collaborateur et accéder à sa fiche BoondManager.",
                icon: LucideIcons.users,
                onPressed: () {
                  // On laisse 120px de marge totale (60px de chaque côté)
                  showDialog(
                    context: context,
                    barrierDismissible: true,
                    builder: (context) => Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 800),
                          child: ResourceFinderWidget(
                            onClose: () => Navigator.of(context).pop(),
                          ),
                        ),
                      ),
                    ),
                  );
                },
                status: ToolStatus.wip,
              ),
              _ToolDefinition(
                title: "Diagnostic BDC",
                description:
                    "Outil temporaire pour tester les inclusions d'API BoondManager et analyser les retours JSON bruts.",
                icon: LucideIcons.shieldAlert,
                onPressed: () {
                  showDialog(
                    context: context,
                    barrierDismissible: true,
                    builder: (context) => Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1000, maxHeight: 850),
                          child: BdcDiagnosticScreen(
                            onClose: () => Navigator.of(context).pop(),
                          ),
                        ),
                      ),
                    ),
                  );
                },
                status: ToolStatus.wip,
              ),
              _ToolDefinition(
                title: "Configuration Règles BDC",
                description:
                    "Outil de test pour configurer et visualiser les règles de calcul spécifiques des UO et des libellés.",
                icon: LucideIcons.pencilRuler,
                onPressed: () {
                  showDialog(
                    context: context,
                    barrierDismissible: true,
                    builder: (context) => Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1050, maxHeight: 880),
                          child: BdcRulesDiagnosticScreen(
                            onClose: () => Navigator.of(context).pop(),
                          ),
                        ),
                      ),
                    ),
                  );
                },
                status: ToolStatus.wip,
              ),
              _ToolDefinition(
                title: "Alertes CRA manquants",
                description:
                    "Identifier les prestataires n'ayant pas encore renseigné leurs temps sur le mois en cours.",
                icon: LucideIcons.calendarClock,
                onPressed: () {
                  // Prochainement
                },
                status: ToolStatus.comingSoon,
              ),
              _ToolDefinition(
                title: "Alerte 80% temps signé",
                description:
                    "Alerter quand un consultant consomme 80% du temps signé.",
                icon: LucideIcons.bell,
                onPressed: () {
                  // Prochainement
                },
                status: ToolStatus.comingSoon,
              ),
              _ToolDefinition(
                title: "Diagnostic Quotas API",
                description:
                    "Analyser les en-têtes HTTP de BoondManager pour tester la détection de quotas.",
                icon: LucideIcons.activity,
                onPressed: () {
                  showDialog(
                    context: context,
                    barrierDismissible: true,
                    builder: (context) => Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 800, maxHeight: 750),
                          child: ApiQuotaDiagnosticScreen(
                            onClose: () => Navigator.of(context).pop(),
                          ),
                        ),
                      ),
                    ),
                  );
                },
                status: ToolStatus.wip,
              ),
            ],
          ),
          const SizedBox(height: VivSpacing.space8),
          _buildCategory(
            context,
            title: "Extractions de données",
            icon: LucideIcons.download,
            tools: [
              _ToolDefinition(
                title: "Extracteur BoondManager",
                description:
                    "Extraire des fichiers CSV paginés complets directement depuis BoondManager pour alimenter vos analyses.",
                icon: LucideIcons.fileSpreadsheet,
                onPressed: () {
                  showDialog(
                    context: context,
                    barrierDismissible: true,
                    builder: (context) => Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 650, maxHeight: 850),
                          child: DataExtractionWidget(
                            onClose: () => Navigator.of(context).pop(),
                          ),
                        ),
                      ),
                    ),
                  );
                },
                status: ToolStatus.wip,
              ),
            ],
          ),
          const SizedBox(height: VivSpacing.space8),
          _buildCategory(
            context,
            title: "Utilitaires & Calculs",
            icon: LucideIcons.calculator,
            tools: [
              _ToolDefinition(
                title: "Jours ouvrés",
                description:
                    "Calculer le nombre exact de jours ouvrés entre deux dates (hors week-ends et jours fériés).",
                icon: LucideIcons.calendarDays,
                onPressed: () {
                  // Prochainement
                },
                status: ToolStatus.wip,
              ),
              _ToolDefinition(
                title: "Nettoyage base BDC",
                description:
                    "Supprimer l'historique d'envoi et les PDF archivés localement pour réinitialiser le module BDC (Mode Démo).",
                icon: LucideIcons.trash2,
                onPressed: () {
                  _showResetBdcDialog(context);
                },
                status: ToolStatus.wip,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showResetBdcDialog(BuildContext context) {
    final toaster = ShadToaster.of(context);
    
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 450),
          child: ShadCard(
            title: const Text("Réinitialiser l'historique BDC"),
            description: const Text(
              "Attention, cette action va vider complètement la base de données locale des bons envoyés et supprimer physiquement tous les fichiers PDF de BDC archivés sur votre ordinateur. Cela permet de recommencer une démo à blanc.",
            ),
            footer: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ShadButton.outline(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text("Annuler"),
                ),
                const SizedBox(width: 8),
                ShadButton.destructive(
                  onPressed: () async {
                    Navigator.of(dialogContext).pop();
                    try {
                      await BdcSentLogsService().clearAllSentLogs();
                      
                      toaster.show(
                        const ShadToast(
                          title: Text("Nettoyage effectué"),
                          description: Text("L'historique des BDC et les fichiers PDF locaux ont été supprimés avec succès."),
                          backgroundColor: Colors.teal,
                        ),
                      );
                    } catch (e) {
                      toaster.show(
                        ShadToast.destructive(
                          title: const Text("Erreur"),
                          description: Text("Une erreur s'est produite lors de la purge : $e"),
                        ),
                      );
                    }
                  },
                  child: const Text("Confirmer la purge"),
                ),
              ],
            ),
            child: const SizedBox(height: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Boîte à outils", style: VivTypography.h1),
        const SizedBox(height: 8),
        Text(
          "Outils utilitaires pour optimiser la gestion quotidienne des administrateurs.",
          style: VivTypography.small.copyWith(color: VivColors.gray500),
        ),
      ],
    );
  }

  Widget _buildCategory(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<_ToolDefinition> tools,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: VivColors.black),
            const SizedBox(width: 8),
            Text(title, style: VivTypography.h3),
          ],
        ),
        const SizedBox(height: VivSpacing.space4),
        LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = constraints.maxWidth > 900
                ? 3
                : (constraints.maxWidth > 600 ? 2 : 1);
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: VivSpacing.space4,
                mainAxisSpacing: VivSpacing.space4,
                mainAxisExtent: 180,
              ),
              itemCount: tools.length,
              itemBuilder: (context, index) {
                final tool = tools[index];
                return _buildToolCard(tool);
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildToolCard(_ToolDefinition tool) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ShadCard(
          padding: const EdgeInsets.all(VivSpacing.space5),
          backgroundColor: VivColors.paper,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // En-tête : Icône et Titre fusionnés
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: VivColors.lime.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(tool.icon, color: VivColors.lime, size: 16),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          tool.title,
                          style: VivTypography.small.copyWith(
                            fontWeight: FontWeight.bold,
                            color: VivColors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Description occupant toute la largeur
                  Text(
                    tool.description,
                    style: VivTypography.small.copyWith(
                      color: VivColors.gray500,
                      fontSize: 12,
                      height: 1.5,
                    ),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              // Zone de bouton alignée à droite
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: tool.onPressed,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              VivColors.lime,
                              VivColors.lime.withValues(alpha: 0.8),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(VivSpacing.radiusMd),
                          boxShadow: [
                            BoxShadow(
                              color: VivColors.lime.withValues(alpha: 0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          "Lancer l'outil",
                          style: VivTypography.small.copyWith(
                            fontWeight: FontWeight.bold,
                            fontStyle: FontStyle.italic,
                            color: VivColors.black,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: _buildStatusBadge(tool.status),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(ToolStatus status) {
    final style = _getStatusStyle(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: style.bgColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: style.color.withValues(alpha: 0.2)),
      ),
      child: Text(
        style.label,
        style: VivTypography.small.copyWith(
          fontSize: 6.5,
          fontWeight: FontWeight.bold,
          color: style.color.withValues(alpha: 0.7),
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  _StatusStyle _getStatusStyle(ToolStatus status) {
    switch (status) {
      case ToolStatus.comingSoon:
        return const _StatusStyle(
          label: "COMING SOON",
          color: VivColors.gray500,
          bgColor: VivColors.gray100,
        );
      case ToolStatus.alpha:
        return const _StatusStyle(
          label: "ALPHA",
          color: Colors.deepPurple,
          bgColor: Color(0xFFF3E5F5),
        );
      case ToolStatus.beta:
        return const _StatusStyle(
          label: "BETA",
          color: Colors.blue,
          bgColor: Color(0xFFE3F2FD),
        );
      case ToolStatus.newTag:
        return const _StatusStyle(
          label: "NEW",
          color: VivColors.lime,
          bgColor: Color(0xFFF9FBE7),
        );
      case ToolStatus.wip:
        return const _StatusStyle(
          label: "EN DÉVELOPPEMENT",
          color: Colors.orange,
          bgColor: Color(0xFFFFF3E0),
        );
    }
  }
}

class _ToolDefinition {
  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onPressed;
  final ToolStatus status;

  const _ToolDefinition({
    required this.title,
    required this.description,
    required this.icon,
    required this.onPressed,
    this.status = ToolStatus.comingSoon,
  });
}

enum ToolStatus {
  comingSoon,
  alpha,
  beta,
  newTag,
  wip,
}

class _StatusStyle {
  final String label;
  final Color color;
  final Color bgColor;

  const _StatusStyle({
    required this.label,
    required this.color,
    required this.bgColor,
  });
}
