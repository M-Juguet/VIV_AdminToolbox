import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart' as fp;
import 'package:shadcn_ui/shadcn_ui.dart';
import '../../design_system/viv_colors.dart';
import '../../design_system/viv_spacing.dart';
import '../../design_system/viv_typography.dart';
import '../../services/bdc_reconciliation_service.dart';

class BdcReconciliationScreen extends ConsumerStatefulWidget {
  final VoidCallback onClose;
  const BdcReconciliationScreen({super.key, required this.onClose});

  @override
  ConsumerState<BdcReconciliationScreen> createState() => _BdcReconciliationScreenState();
}

class _BdcReconciliationScreenState extends ConsumerState<BdcReconciliationScreen> {
  final TextEditingController _pstPathController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  String _selectedMonth = "09";
  String _selectedYear = "2026";
  bool _isLoading = false;
  bool _isCleaning = false;
  String _statusText = "Sélectionnez un fichier PST et lancez l'analyse.";
  
  BdcReconciliationReport? _report;
  String _filterTab = "all"; // 'all', 'confirmed', 'missing'

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = now.month.toString().padLeft(2, '0');
    _selectedYear = now.year.toString();
    _searchController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _pstPathController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _pickPstFile() async {
    try {
      final files = await fp.FilePicker.pickFiles(
        dialogTitle: 'Sélectionner le fichier d\'export Outlook (.pst)',
        type: fp.FileType.custom,
        allowedExtensions: ['pst'],
      );

      if (files.isNotEmpty && files.first.path != null) {
        setState(() {
          _pstPathController.text = files.first.path!;
        });
      }
    } catch (e) {
      if (mounted) {
        ShadToaster.of(context).show(
          ShadToast.destructive(
            title: const Text('Erreur de sélection'),
            description: Text(e.toString()),
          ),
        );
      }
    }
  }

  Future<void> _runReconciliation() async {
    final pstPath = _pstPathController.text.trim();
    if (pstPath.isEmpty) {
      ShadToaster.of(context).show(
        const ShadToast.destructive(
          title: Text('Fichier manquant'),
          description: Text('Veuillez sélectionner un fichier .pst.'),
        ),
      );
      return;
    }

    if (!File(pstPath).existsSync()) {
      ShadToaster.of(context).show(
        const ShadToast.destructive(
          title: Text('Fichier introuvable'),
          description: Text('Le chemin spécifié n\'existe pas.'),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _statusText = "Analyse du fichier PST et comparaison avec la base locale...";
      _report = null;
    });

    try {
      final service = BdcReconciliationService();
      final period = '$_selectedMonth/$_selectedYear';
      final report = await service.reconcileWithDatabase(
        pstPath: pstPath,
        period: period,
      );

      setState(() {
        _report = report;
        _isLoading = false;
        _statusText = "Analyse terminée avec succès.";
      });

      if (mounted) {
        ShadToaster.of(context).show(
          ShadToast(
            title: const Text('Analyse terminée'),
            description: Text(
              '${report.confirmedCount} confirmés / ${report.missingCount} non reçus sur ${report.totalInDatabase} BDC.',
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusText = "Erreur : $e";
      });
      if (mounted) {
        ShadToaster.of(context).show(
          ShadToast.destructive(
            title: const Text('Erreur d\'analyse'),
            description: Text(e.toString()),
          ),
        );
      }
    }
  }

  Future<void> _confirmAndCleanDatabase() async {
    if (_report == null || _report!.missingCount == 0) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmer la réinitialisation ciblée'),
        content: Text(
          'Cette action va supprimer de la base locale uniquement les ${_report!.missingCount} enregistrements '
          'non confirmés pour la période ${_report!.period}.\n\n'
          'Les ${_report!.confirmedCount} BDC confirmés reçus resteront intacts.\n\n'
          'Les ${_report!.missingCount} prestataires redeviendront cochés et prêts à être envoyés dans l\'étape 1 de l\'écran BDC.\n\n'
          'Voulez-vous continuer ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ShadButton.destructive(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Réinitialiser les ${_report!.missingCount} BDC'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isCleaning = true;
    });

    try {
      final service = BdcReconciliationService();
      final deleted = await service.deleteMissingLogs(
        period: _report!.period,
        missingProviderIds: _report!.missingProviderIds,
      );

      // Re-lancer la réconciliation pour mettre à jour l'affichage
      final newReport = await service.reconcileWithDatabase(
        pstPath: _report!.pstPath,
        period: _report!.period,
      );

      setState(() {
        _report = newReport;
        _isCleaning = false;
      });

      if (mounted) {
        ShadToaster.of(context).show(
          ShadToast(
            title: const Text('Base nettoyée avec succès'),
            description: Text('$deleted enregistrements ont été réinitialisés pour $_selectedMonth/$_selectedYear.'),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isCleaning = false;
      });
      if (mounted) {
        ShadToaster.of(context).show(
          ShadToast.destructive(
            title: const Text('Erreur lors du nettoyage'),
            description: Text(e.toString()),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: VivColors.offWhite,
      child: Column(
        children: [
          // Header
          _buildHeader(),
          
          // Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(VivSpacing.space5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Formulaire de configuration
                  _buildConfigCard(),
                  const SizedBox(height: VivSpacing.space5),

                  // Résultats
                  if (_isLoading)
                    _buildLoadingState()
                  else if (_report != null)
                    _buildReportView()
                  else
                    _buildEmptyState(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: VivSpacing.space5,
        vertical: VivSpacing.space3,
      ),
      decoration: const BoxDecoration(
        color: VivColors.paper,
        border: Border(
          bottom: BorderSide(color: VivColors.gray200),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(VivSpacing.space2),
                decoration: BoxDecoration(
                  color: VivColors.lime.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(VivSpacing.radiusSm),
                ),
                child: const Icon(
                  LucideIcons.mailCheck,
                  color: Colors.black,
                  size: 24,
                ),
              ),
              const SizedBox(width: VivSpacing.space4),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Audit & Réconciliation des Bons de Commande",
                    style: VivTypography.h3,
                  ),
                  Text(
                    "Croisez les réceptions réelles Outlook (.pst) avec la base locale pour corriger les faux positifs d'envoi",
                    style: VivTypography.small.copyWith(
                      color: VivColors.gray500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          ShadButton.outline(
            onPressed: widget.onClose,
            child: const Row(
              children: [
                Icon(LucideIcons.x, size: 16),
                SizedBox(width: VivSpacing.space1),
                Text("Fermer"),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigCard() {
    final months = [
      {'value': '01', 'label': 'Janvier'},
      {'value': '02', 'label': 'Février'},
      {'value': '03', 'label': 'Mars'},
      {'value': '04', 'label': 'Avril'},
      {'value': '05', 'label': 'Mai'},
      {'value': '06', 'label': 'Juin'},
      {'value': '07', 'label': 'Juillet'},
      {'value': '08', 'label': 'Août'},
      {'value': '09', 'label': 'Septembre'},
      {'value': '10', 'label': 'Octobre'},
      {'value': '11', 'label': 'Novembre'},
      {'value': '12', 'label': 'Décembre'},
    ];

    final years = ['2025', '2026', '2027'];

    return ShadCard(
      child: Padding(
        padding: const EdgeInsets.all(VivSpacing.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(LucideIcons.settings2, size: 18, color: Colors.black),
                const SizedBox(width: VivSpacing.space2),
                Text("Paramètres d'analyse", style: VivTypography.h4),
              ],
            ),
            const SizedBox(height: VivSpacing.space4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Sélecteur Mois
                SizedBox(
                  width: 160,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Mois concerné", style: VivTypography.small),
                      const SizedBox(height: 6),
                      ShadSelect<String>(
                        placeholder: const Text('Mois'),
                        initialValue: _selectedMonth,
                        options: months.map(
                          (m) => ShadOption(
                            value: m['value']!,
                            child: Text(m['label']!),
                          ),
                        ).toList(),
                        selectedOptionBuilder: (context, value) {
                          final match = months.firstWhere((m) => m['value'] == value);
                          return Text(match['label']!);
                        },
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedMonth = val);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: VivSpacing.space4),

                // Sélecteur Année
                SizedBox(
                  width: 120,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Année", style: VivTypography.small),
                      const SizedBox(height: 6),
                      ShadSelect<String>(
                        placeholder: const Text('Année'),
                        initialValue: _selectedYear,
                        options: years.map(
                          (y) => ShadOption(
                            value: y,
                            child: Text(y),
                          ),
                        ).toList(),
                        selectedOptionBuilder: (context, value) => Text(value),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedYear = val);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: VivSpacing.space4),

                // Fichier PST
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Fichier d'export Outlook (.pst)", style: VivTypography.small),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: ShadInput(
                              controller: _pstPathController,
                              placeholder: const Text("C:\\chemin\\vers\\exportMailsBDC.pst"),
                            ),
                          ),
                          const SizedBox(width: VivSpacing.space2),
                          ShadButton.outline(
                            onPressed: _pickPstFile,
                            child: const Row(
                              children: [
                                Icon(LucideIcons.folderOpen, size: 16),
                                SizedBox(width: VivSpacing.space1),
                                Text("Parcourir..."),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: VivSpacing.space4),

                // Bouton Analyser
                ShadButton(
                  backgroundColor: Colors.black,
                  onPressed: _isLoading ? null : _runReconciliation,
                  child: Row(
                    children: [
                      if (_isLoading)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      else
                        const Icon(LucideIcons.searchCheck, size: 16, color: Colors.white),
                      const SizedBox(width: VivSpacing.space1),
                      const Text("Analyser & Auditer", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(VivSpacing.space8),
        child: Column(
          children: [
            const CircularProgressIndicator(color: Colors.black),
            const SizedBox(height: VivSpacing.space4),
            Text(_statusText, style: VivTypography.body),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(VivSpacing.space8),
      decoration: BoxDecoration(
        color: VivColors.paper,
        borderRadius: BorderRadius.circular(VivSpacing.radiusMd),
        border: Border.all(color: VivColors.gray200),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(LucideIcons.fileSpreadsheet, size: 48, color: VivColors.gray400),
            const SizedBox(height: VivSpacing.space4),
            Text("Aucune analyse effectuée", style: VivTypography.h4),
            const SizedBox(height: VivSpacing.space1),
            Text(
              "Sélectionnez le fichier .pst exporté depuis la boîte Outlook et cliquez sur « Analyser & Auditer ».",
              style: VivTypography.body,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportView() {
    final report = _report!;
    final query = _searchController.text.trim().toLowerCase();

    final filteredEntries = report.entries.where((e) {
      if (_filterTab == 'confirmed' && !e.isConfirmedInPst) return false;
      if (_filterTab == 'missing' && e.isConfirmedInPst) return false;

      if (query.isNotEmpty) {
        final provId = e.providerId.toLowerCase();
        final bdc = (e.bdcNumber ?? '').toLowerCase();
        final consult = (e.consultantName ?? '').toLowerCase();
        final client = (e.clientName ?? '').toLowerCase();
        final email = (e.sentToEmail ?? '').toLowerCase();
        return provId.contains(query) ||
            bdc.contains(query) ||
            consult.contains(query) ||
            client.contains(query) ||
            email.contains(query);
      }
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cartes de statistiques
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                title: "Total en base locale",
                value: "${report.totalInDatabase}",
                subtitle: "Période : ${report.period}",
                icon: LucideIcons.database,
                color: Colors.black,
                bgColor: VivColors.gray100,
              ),
            ),
            const SizedBox(width: VivSpacing.space4),
            Expanded(
              child: _buildMetricCard(
                title: "Confirmés dans Outlook",
                value: "${report.confirmedCount}",
                subtitle: "Reçus avec succès dans la boîte",
                icon: LucideIcons.circleCheck,
                color: Colors.teal.shade700,
                bgColor: Colors.teal.shade50,
              ),
            ),
            const SizedBox(width: VivSpacing.space4),
            Expanded(
              child: _buildMetricCard(
                title: "Non reçus (Manquants)",
                value: "${report.missingCount}",
                subtitle: "À réinitialiser pour ré-envoi",
                icon: LucideIcons.triangleAlert,
                color: report.missingCount > 0 ? Colors.red.shade700 : Colors.teal.shade700,
                bgColor: report.missingCount > 0 ? Colors.red.shade50 : Colors.teal.shade50,
              ),
            ),
          ],
        ),
        const SizedBox(height: VivSpacing.space5),

        // Barre d'actions & nettoyage
        if (report.missingCount > 0)
          Container(
            padding: const EdgeInsets.all(VivSpacing.space4),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(VivSpacing.radiusSm),
              border: Border.all(color: Colors.amber.shade300),
            ),
            child: Row(
              children: [
                Icon(LucideIcons.circleAlert, color: Colors.amber.shade800),
                const SizedBox(width: VivSpacing.space4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Désynchronisation détectée (${report.missingCount} BDC non reçus)",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.amber.shade900,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        "Ces ${report.missingCount} prestataires sont enregistrés comme envoyés dans la base, mais ne sont jamais arrivés dans la boîte mail.",
                        style: TextStyle(
                          color: Colors.amber.shade900,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: VivSpacing.space4),
                ShadButton.destructive(
                  onPressed: _isCleaning ? null : _confirmAndCleanDatabase,
                  child: Row(
                    children: [
                      if (_isCleaning)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      else
                        const Icon(LucideIcons.rotateCcw, size: 16),
                      const SizedBox(width: VivSpacing.space1),
                      Text("Réinitialiser les ${report.missingCount} BDC non reçus"),
                    ],
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(VivSpacing.space4),
            decoration: BoxDecoration(
              color: Colors.teal.shade50,
              borderRadius: BorderRadius.circular(VivSpacing.radiusSm),
              border: Border.all(color: Colors.teal.shade300),
            ),
            child: Row(
              children: [
                Icon(LucideIcons.checkCheck, color: Colors.teal.shade800),
                const SizedBox(width: VivSpacing.space4),
                Expanded(
                  child: Text(
                    "Parfait ! Tous les ${report.totalInDatabase} BDC de la base sont confirmés reçus dans Outlook.",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.teal.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: VivSpacing.space5),

        // Tableau détaillé avec recherche et filtres
        ShadCard(
          child: Padding(
            padding: const EdgeInsets.all(VivSpacing.space4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        _buildFilterButton('all', 'Tous (${report.entries.length})'),
                        const SizedBox(width: VivSpacing.space2),
                        _buildFilterButton('confirmed', 'Confirmés (${report.confirmedCount})'),
                        const SizedBox(width: VivSpacing.space2),
                        _buildFilterButton('missing', 'Non reçus (${report.missingCount})'),
                      ],
                    ),
                    SizedBox(
                      width: 260,
                      child: ShadInput(
                        controller: _searchController,
                        placeholder: const Text("Rechercher (Nom, BDC, ID)..."),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: VivSpacing.space4),

                // Table
                if (filteredEntries.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(VivSpacing.space6),
                    child: Center(
                      child: Text("Aucun résultat pour ce filtre", style: VivTypography.body),
                    ),
                  )
                else
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(VivColors.gray100),
                      columns: const [
                        DataColumn(label: Text('Statut')),
                        DataColumn(label: Text('ID Fournisseur')),
                        DataColumn(label: Text('N° BDC')),
                        DataColumn(label: Text('Consultant / Prestataire')),
                        DataColumn(label: Text('Client')),
                        DataColumn(label: Text('E-mail destinataire')),
                        DataColumn(label: Text('Montant HT')),
                        DataColumn(label: Text('Date réception PST')),
                      ],
                      rows: filteredEntries.map((e) {
                        return DataRow(
                          cells: [
                            DataCell(
                              e.isConfirmedInPst
                                  ? _buildStatusBadge(
                                      'Reçu dans Outlook',
                                      Colors.teal.shade700,
                                      Colors.teal.shade50,
                                      LucideIcons.check,
                                    )
                                  : _buildStatusBadge(
                                      'Non reçu (À réinitialiser)',
                                      Colors.red.shade700,
                                      Colors.red.shade50,
                                      LucideIcons.x,
                                    ),
                            ),
                            DataCell(Text(e.providerId, style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataCell(Text(e.bdcNumber ?? '-')),
                            DataCell(Text(e.consultantName ?? '-')),
                            DataCell(Text(e.clientName ?? '-')),
                            DataCell(Text(e.sentToEmail ?? '-')),
                            DataCell(Text(e.totalHt != null ? "${e.totalHt!.toStringAsFixed(2)} €" : '-')),
                            DataCell(Text(e.receivedTime ?? '-')),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterButton(String key, String label) {
    final isSelected = _filterTab == key;
    return GestureDetector(
      onTap: () => setState(() => _filterTab = key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : VivColors.gray100,
          borderRadius: BorderRadius.circular(VivSpacing.radiusSm),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : VivColors.ink,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String text, Color textColor, Color bgColor, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(VivSpacing.radiusSm),
        border: Border.all(color: textColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(VivSpacing.space4),
      decoration: BoxDecoration(
        color: VivColors.paper,
        borderRadius: BorderRadius.circular(VivSpacing.radiusMd),
        border: Border.all(color: VivColors.gray200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(VivSpacing.space3),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(VivSpacing.radiusSm),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: VivSpacing.space4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: VivTypography.small.copyWith(color: VivColors.gray500)),
                Text(
                  value,
                  style: VivTypography.h2.copyWith(color: color, fontWeight: FontWeight.bold),
                ),
                Text(subtitle, style: VivTypography.small.copyWith(color: VivColors.gray400)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
