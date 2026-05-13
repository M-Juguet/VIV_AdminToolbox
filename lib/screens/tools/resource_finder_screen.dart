import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../../design_system/viv_colors.dart';
import '../../design_system/viv_spacing.dart';
import '../../design_system/viv_typography.dart';

class ResourceFinderWidget extends StatefulWidget {
  final VoidCallback onClose;
  const ResourceFinderWidget({super.key, required this.onClose});

  @override
  State<ResourceFinderWidget> createState() => _ResourceFinderWidgetState();
}

class _ResourceFinderWidgetState extends State<ResourceFinderWidget> {
  int _currentStep = 0; // 0: Filtres, 1: Résultats, 2: Fiche
  final _searchController = TextEditingController();
  bool _isLoading = false;
  List<Map<String, dynamic>> _results = [];
  Map<String, dynamic>? _selectedResource;

  // Mock data avec TJM et agences réelles
  void _runSearch() {
    setState(() => _isLoading = true);
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _results = [
            {
              'id': '1', 
              'name': 'Jean Dupont', 
              'role': 'Dév Fullstack', 
              'agency': 'VIV Sandbox', 
              'status': 'Dispo', 
              'email': 'j.dupont@viv.fr', 
              'phone': '06 12 34 56 78', 
              'manager': 'M. Lefebvre',
              'tjm': '550 €',
              'type': 'Interne'
            },
            {
              'id': '2', 
              'name': 'Marie Lavoie', 
              'role': 'UX Designer', 
              'agency': 'GENESIS Sandbox', 
              'status': 'Mission', 
              'email': 'm.lavoie@viv.fr', 
              'phone': '06 98 76 54 32', 
              'manager': 'S. Martin',
              'tjm': '620 €',
              'type': 'Externe'
            },
            {
              'id': '3', 
              'name': 'Thomas Martin', 
              'role': 'Architecte Cloud', 
              'agency': 'PCI Sandbox', 
              'status': 'Dispo', 
              'email': 't.martin@viv.fr', 
              'phone': '07 11 22 33 44', 
              'manager': 'L. Durand',
              'tjm': '800 €',
              'type': 'Interne'
            },
          ];
          _currentStep = 1;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(VivSpacing.radiusLg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildCompactHeader(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: VivSpacing.space6),
            child: _buildCurrentStepView(),
          ),
          _buildCompactFooter(),
        ],
      ),
    );
  }

  Widget _buildCompactHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(VivSpacing.space6, VivSpacing.space5, VivSpacing.space6, VivSpacing.space4),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Trouver une ressource", style: VivTypography.h4.copyWith(fontSize: 18)),
              ShadButton.ghost(
                padding: EdgeInsets.zero,width: 28, height: 28,
                onPressed: widget.onClose,
                child: const Icon(LucideIcons.x, size: 18),
              ),
            ],
          ),
          const SizedBox(height: VivSpacing.space4),
          _buildThinStepper(),
        ],
      ),
    );
  }

  Widget _buildThinStepper() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(color: VivColors.offWhite, borderRadius: BorderRadius.circular(VivSpacing.radiusMd)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildStepNode(0, "Filtres", LucideIcons.slidersHorizontal),
          _buildStepLine(_currentStep >= 1),
          _buildStepNode(1, "Résultats", LucideIcons.search),
          _buildStepLine(_currentStep >= 2),
          _buildStepNode(2, "Fiche", LucideIcons.user),
        ],
      ),
    );
  }

  Widget _buildStepNode(int step, String label, IconData icon) {
    final isActive = _currentStep == step;
    final isDone = _currentStep > step;
    final color = isActive || isDone ? VivColors.lime : VivColors.gray400;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(isDone ? LucideIcons.circleCheck : icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: VivTypography.small.copyWith(
            fontSize: 9, 
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isActive ? VivColors.black : VivColors.gray500,
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine(bool active) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10),
        height: 1,
        color: active ? VivColors.lime : VivColors.gray200,
      ),
    );
  }

  Widget _buildCurrentStepView() {
    if (_currentStep == 0) return _buildFiltersStep();
    if (_currentStep == 1) return _buildResultsStep();
    if (_currentStep == 2) return _buildDetailStep();
    return const SizedBox.shrink();
  }

  Widget _buildFiltersStep() {
    return Column(
      key: const ValueKey(0),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSmallLabel("RECHERCHE"),
        const SizedBox(height: 6),
        ShadInput(
          controller: _searchController,
          placeholder: const Text("Nom, compétences..."),
          leading: const Icon(LucideIcons.search, size: 14),
        ),
        const SizedBox(height: VivSpacing.space4),
        
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSmallLabel("AGENCE"),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: double.infinity,
                    child: ShadSelect<String>(
                      placeholder: const Text("Toutes", style: TextStyle(fontSize: 12)),
                      options: [
                        ShadOption(value: 'all', child: const Text('Toutes', style: TextStyle(fontSize: 12))),
                        ShadOption(value: 'VIV', child: const Text('VIV', style: TextStyle(fontSize: 12))),
                        ShadOption(value: 'GENESIS', child: const Text('GENESIS', style: TextStyle(fontSize: 12))),
                        ShadOption(value: 'PCI', child: const Text('PCI', style: TextStyle(fontSize: 12))),
                      ],
                      selectedOptionBuilder: (context, value) => Text(value == 'all' ? 'Toutes' : value, style: const TextStyle(fontSize: 12)),
                      onChanged: (v) {},
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSmallLabel("TYPE"),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: double.infinity,
                    child: ShadSelect<String>(
                      placeholder: const Text("Tous", style: TextStyle(fontSize: 12)),
                      options: [
                        ShadOption(value: 'all', child: const Text('Tous', style: TextStyle(fontSize: 12))),
                        ShadOption(value: 'internal', child: const Text('Interne', style: TextStyle(fontSize: 12))),
                        ShadOption(value: 'external', child: const Text('Externe', style: TextStyle(fontSize: 12))),
                      ],
                      selectedOptionBuilder: (context, value) => Text(value == 'all' ? 'Tous' : (value == 'internal' ? 'Interne' : 'Externe'), style: const TextStyle(fontSize: 12)),
                      onChanged: (v) {},
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        
        const SizedBox(height: VivSpacing.space4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: VivColors.offWhite, borderRadius: BorderRadius.circular(VivSpacing.radiusMd)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Actifs uniquement", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
              Transform.scale(scale: 0.8, child: ShadSwitch(value: true, onChanged: (v) {})),
            ],
          ),
        ),
        const SizedBox(height: VivSpacing.space4),
      ],
    );
  }

  Widget _buildResultsStep() {
    return Column(
      key: const ValueKey(1),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("${_results.length} collaborateurs", style: VivTypography.eyebrow.copyWith(fontSize: 9)),
        const SizedBox(height: 8),
        ..._results.take(4).map((r) => _buildCompactResourceRow(r)),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildCompactResourceRow(Map<String, dynamic> r) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: () => setState(() { _selectedResource = r; _currentStep = 2; }),
        borderRadius: BorderRadius.circular(VivSpacing.radiusMd),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(border: Border.all(color: VivColors.gray100), borderRadius: BorderRadius.circular(VivSpacing.radiusMd)),
          child: Row(
            children: [
              CircleAvatar(radius: 12, backgroundColor: VivColors.lime.withValues(alpha: 0.1), child: Text(r['name'][0], style: const TextStyle(fontSize: 10))),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(r['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  Text("${r['role']} • ${r['agency']}", style: const TextStyle(fontSize: 10, color: VivColors.gray500)),
                ]),
              ),
              const Icon(LucideIcons.chevronRight, size: 14, color: VivColors.gray400),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailStep() {
    if (_selectedResource == null) return const SizedBox.shrink();
    final r = _selectedResource!;
    return Column(
      key: const ValueKey(2),
      children: [
        Row(
          children: [
            CircleAvatar(radius: 20, backgroundColor: VivColors.offWhite, child: Text(r['name'][0], style: const TextStyle(fontWeight: FontWeight.bold))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(r['name'], style: VivTypography.h4.copyWith(fontSize: 16)),
                Text(r['role'], style: const TextStyle(color: VivColors.gray500, fontSize: 11)),
              ]),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _buildCompactInfoSection("COORDONNÉES", [
          _buildTinyRow(LucideIcons.mail, r['email']),
          _buildTinyRow(LucideIcons.phone, r['phone']),
        ]),
        const SizedBox(height: 6),
        _buildCompactInfoSection("ORGANISATION & CONTRAT", [
          _buildTinyRow(LucideIcons.mapPin, r['agency']),
          _buildTinyRow(LucideIcons.user, r['manager']),
          _buildTinyRow(LucideIcons.fileText, "${r['type']} • TJM : ${r['tjm']}"),
        ]),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildCompactInfoSection(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSmallLabel(title),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: VivColors.offWhite, borderRadius: BorderRadius.circular(VivSpacing.radiusMd)),
          child: Column(children: items),
        ),
      ],
    );
  }

  Widget _buildTinyRow(IconData icon, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 10, color: VivColors.gray400),
          const SizedBox(width: 6),
          Text(value, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildCompactFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: VivSpacing.space6, vertical: 12),
      decoration: const BoxDecoration(
        color: VivColors.offWhite,
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(VivSpacing.radiusLg), bottomRight: Radius.circular(VivSpacing.radiusLg)),
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            ShadButton.outline(
              size: ShadButtonSize.sm,
              onPressed: () => setState(() => _currentStep--),
              child: const Text("Retour", style: TextStyle(fontSize: 12)),
            ),
          const Spacer(),
          ShadButton(
            backgroundColor: VivColors.lime,
            size: ShadButtonSize.sm,
            onPressed: _isLoading ? null : (_currentStep < 2 ? _runSearch : widget.onClose),
            child: _isLoading 
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(_currentStep == 0 ? "Rechercher" : (_currentStep == 1 ? "Choisir" : "Fermer"), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallLabel(String text) => Text(text, style: VivTypography.eyebrow.copyWith(fontSize: 8, color: VivColors.gray500));
}
