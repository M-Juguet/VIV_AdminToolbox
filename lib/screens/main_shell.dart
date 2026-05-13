import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:window_manager/window_manager.dart';
import '../design_system/viv_colors.dart';
import '../design_system/viv_spacing.dart';
import '../design_system/viv_typography.dart';
import '../models/app_settings.dart';
import '../providers/settings_provider.dart';
import 'dashboard_screen.dart';
import 'settings_screen.dart';
import 'toolbox_screen.dart';
import '../providers/dashboard_provider.dart';
import '../providers/update_provider.dart';
import '../widgets/update_modal.dart';

final navigationIndexProvider = NotifierProvider<NavigationIndexNotifier, int>(NavigationIndexNotifier.new);

class NavigationIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;
  
  @override
  set state(int value) => super.state = value;
}

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  bool _isSidebarCollapsed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(updateProvider.notifier).checkForUpdates(silent: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<UpdateStateData>(updateProvider, (previous, next) {
      if (previous?.status != UpdateState.available && next.status == UpdateState.available) {
        showUpdateDialog(context);
      }
    });

    final settings = ref.watch(settingsProvider);
    final userEmail = settings.boondUser;
    final selectedIndex = ref.watch(navigationIndexProvider);

    return Scaffold(
      backgroundColor: VivColors.offWhite,
      body: Row(
        children: [
          // Navigation Sidebar
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            width: _isSidebarCollapsed ? 64 : 260,
            decoration: const BoxDecoration(
              color: VivColors.black,
              borderRadius: BorderRadius.only(
                topRight: Radius.circular(8),
                bottomRight: Radius.circular(8),
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 160;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Branding Header
                    DragToMoveArea(
                      child: Container(
                        height: 70,
                        padding: EdgeInsets.symmetric(
                          horizontal: isCompact ? 0 : VivSpacing.space5,
                        ),
                        alignment: isCompact
                            ? Alignment.center
                            : Alignment.centerLeft,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: isCompact
                              ? Image.asset(
                                  'assets/images/viv-mark-white.png',
                                  key: const ValueKey('mark'),
                                  height: 24,
                                )
                              : Image.asset(
                                  'assets/images/viv-horizontal-white.png',
                                  key: const ValueKey('full'),
                                  height: 24,
                                ),
                        ),
                      ),
                    ),

                    const SizedBox(height: VivSpacing.space2),

                    // Nav Items
                    Expanded(
                      child: ListView(
                        padding: EdgeInsets.symmetric(
                          horizontal: isCompact
                              ? VivSpacing.space2
                              : VivSpacing.space3,
                        ),
                        children: [
                          if (!isCompact)
                            const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: VivSpacing.space3,
                                vertical: VivSpacing.space2,
                              ),
                              child: Text(
                                'VUE D\'ENSEMBLE',
                                style: TextStyle(
                                  color: VivColors.gray500,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                          _buildNavItem(
                            icon: LucideIcons.layoutDashboard,
                            title: 'Tableau de bord',
                            index: 0,
                            isCompact: isCompact,
                          ),
                          const SizedBox(height: VivSpacing.space1),
                          _buildNavItem(
                            icon: LucideIcons.filePenLine,
                            title: 'Devis',
                            index: 1,
                            isCompact: isCompact,
                          ),
                          const SizedBox(height: VivSpacing.space1),
                          _buildNavItem(
                            icon: LucideIcons.receiptText,
                            title: 'Bons de commande',
                            index: 2,
                            isCompact: isCompact,
                          ),
                          const SizedBox(height: VivSpacing.space1),
                          _buildNavItem(
                            icon: LucideIcons.chartArea,
                            title: 'Rapports de production',
                            index: 3,
                            isCompact: isCompact,
                          ),
                          const SizedBox(height: VivSpacing.space1),
                          _buildNavItem(
                            icon: LucideIcons.wrench,
                            title: 'Boîte à outils',
                            index: 4,
                            isCompact: isCompact,
                          ),
                          const SizedBox(height: VivSpacing.space5),
                          if (!isCompact)
                            const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: VivSpacing.space3,
                                vertical: VivSpacing.space2,
                              ),
                              child: Text(
                                'SYSTÈME',
                                style: TextStyle(
                                  color: VivColors.gray500,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                          _buildNavItem(
                            icon: LucideIcons.settings,
                            title: 'Paramètres',
                            index: 5,
                            isCompact: isCompact,
                          ),
                        ],
                      ),
                    ),

                    // Footer Profile
                    Padding(
                      padding: const EdgeInsets.only(
                        left: VivSpacing.space3,
                        right: VivSpacing.space3,
                        top: VivSpacing.space3,
                        bottom: VivSpacing.space5,
                      ),
                      child: isCompact
                          ? Center(
                              child: CircleAvatar(
                                radius: 14,
                                backgroundColor: settings.boondUser.isEmpty
                                    ? VivColors.gray300
                                    : VivColors.lime,
                                child: Text(
                                  _getUserInitials(settings),
                                  style: const TextStyle(
                                    color: VivColors.black,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            )
                          : Container(
                              padding: const EdgeInsets.all(VivSpacing.space3),
                              decoration: BoxDecoration(
                                color: VivColors.gray100.withValues(
                                  alpha: 0.05,
                                ),
                                borderRadius: BorderRadius.circular(
                                  VivSpacing.radiusMd,
                                ),
                                border: Border.all(
                                  color: VivColors.gray100.withValues(
                                    alpha: 0.1,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: settings.boondUser.isEmpty
                                        ? VivColors.gray200
                                        : VivColors.lime,
                                    child: settings.boondUser.isEmpty
                                        ? const Icon(
                                            LucideIcons.user,
                                            size: 14,
                                            color: VivColors.gray500,
                                          )
                                        : Text(
                                            _getUserInitials(settings),
                                            style: const TextStyle(
                                              color: VivColors.black,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 10,
                                            ),
                                          ),
                                  ),
                                  const SizedBox(width: VivSpacing.space3),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          _getUserDisplayName(settings),
                                          style: const TextStyle(
                                            color: VivColors.paper,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          userEmail.isEmpty
                                              ? 'Configuration requise'
                                              : userEmail,
                                          style: const TextStyle(
                                            color: VivColors.gray500,
                                            fontSize: 10,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (userEmail.isNotEmpty)
                                    ShadButton.ghost(
                                      padding: EdgeInsets.zero,
                                      width: 24,
                                      height: 24,
                                      onPressed: () => _handleLogout(context),
                                      child: const Icon(
                                        LucideIcons.logOut,
                                        size: 14,
                                        color: VivColors.gray500,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                    ),
                  ],
                );
              },
            ),
          ),

          // Main Area
          Expanded(
            child: Column(
              children: [
                // Top Header
                Container(
                  height: 70,
                  decoration: const BoxDecoration(
                    color: VivColors.paper,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x04000000),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: VivSpacing.space2),
                      IconButton(
                        onPressed: () => setState(
                          () => _isSidebarCollapsed = !_isSidebarCollapsed,
                        ),
                        icon: Icon(
                          _isSidebarCollapsed
                              ? LucideIcons.menu
                              : LucideIcons.panelLeft,
                          size: 20,
                          color: VivColors.black,
                        ),
                      ),
                      Expanded(
                        child: DragToMoveArea(
                          child: Container(
                            height: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: VivSpacing.space2,
                            ),
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _getTitle(selectedIndex),
                              style: VivTypography.h3.copyWith(fontSize: 18),
                            ),
                          ),
                        ),
                      ),
                      Consumer(
                        builder: (context, ref, child) {
                          final stats = ref.watch(dashboardProvider);
                          final agencies = stats.agencies;

                          return Row(
                            children: [
                              if (userEmail.isNotEmpty && agencies.isNotEmpty)
                                ShadSelect<String>(
                                  placeholder: const Text(
                                    'Sélectionner une agence',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  initialValue: stats.selectedAgencyId,
                                  onChanged: (id) {
                                    final agency = agencies.firstWhere(
                                      (a) => a['id'] == id,
                                    );
                                    ref
                                        .read(dashboardProvider.notifier)
                                        .selectAgency(id!, agency['name']!);
                                  },
                                  selectedOptionBuilder: (context, value) =>
                                      ShadBadge(
                                    backgroundColor: VivColors.gray100,
                                    foregroundColor: VivColors.lime,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(LucideIcons.house, size: 12),
                                        const SizedBox(width: 6),
                                        Text(
                                          stats.selectedAgencyName ??
                                              'Sélectionner',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  options: agencies
                                      .map(
                                        (agency) => ShadOption(
                                          value: agency['id']!,
                                          child: Text(agency['name']!),
                                        ),
                                      )
                                      .toList(),
                                )
                              else if (stats.isLoading)
                                const SizedBox(
                                  width: 120,
                                  child: LinearProgressIndicator(
                                    backgroundColor: VivColors.gray100,
                                    valueColor: AlwaysStoppedAnimation<Color>(VivColors.lime),
                                  ),
                                ),
                              const SizedBox(width: VivSpacing.space2),
                              IconButton(
                                icon: const Icon(
                                  LucideIcons.bell,
                                  size: 18,
                                  color: VivColors.gray500,
                                ),
                                onPressed: () {},
                              ),
                              const SizedBox(width: VivSpacing.space2),
                              IconButton(
                                icon: const Icon(
                                  LucideIcons.x,
                                  size: 20,
                                  color: VivColors.gray500,
                                ),
                                hoverColor: Colors.red.withValues(alpha: 0.1),
                                onPressed: () async {
                                  await windowManager.close();
                                },
                              ),
                              const SizedBox(width: VivSpacing.space4),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),

                // Viewport
                Expanded(
                  child: IndexedStack(
                    index: selectedIndex,
                    children: const [
                      DashboardScreen(),
                      Center(child: Text("Gestion des Devis (À venir)")),
                      Center(child: Text("Bons de commande (À venir)")),
                      Center(child: Text("Rapports de production (À venir)")),
                      ToolboxScreen(),
                      SettingsScreen(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _handleLogout(BuildContext context) {
    showShadDialog(
      context: context,
      builder: (context) => ShadDialog(
        title: const Text('Déconnexion'),
        description: const Text(
          'Êtes-vous sûr de vouloir vous déconnecter ? Les identifiants BoondManager et SMTP seront effacés de cet appareil.',
        ),
        actions: [
          ShadButton.outline(
            child: const Text('Annuler'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          ShadButton(
            backgroundColor: Colors.red.shade600,
            child: const Text('Se déconnecter'),
            onPressed: () {
              ref.read(settingsProvider.notifier).logout();
              ref.invalidate(dashboardProvider);
              ref.read(navigationIndexProvider.notifier).state = 0;
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  String _getUserInitials(AppSettings settings) {
    if (settings.boondUser.isEmpty) return ' ';
    if (settings.boondFirstName.isNotEmpty &&
        settings.boondLastName.isNotEmpty) {
      return (settings.boondFirstName[0] + settings.boondLastName[0])
          .toUpperCase();
    }
    final email = settings.boondUser;
    if (email.isEmpty) return '?';
    final name = email.split('@')[0];
    if (name.length >= 2) {
      return name.substring(0, 2).toUpperCase();
    }
    return name.toUpperCase();
  }

  String _getUserDisplayName(AppSettings settings) {
    if (settings.boondUser.isEmpty) return 'Profil inconnu';
    if (settings.boondFirstName.isNotEmpty ||
        settings.boondLastName.isNotEmpty) {
      return "${settings.boondFirstName} ${settings.boondLastName}";
    }
    final email = settings.boondUser;
    if (email.isEmpty) return 'Profil inconnu';
    final name = email.split('@')[0];
    if (name.isNotEmpty) {
      return name[0].toUpperCase() + name.substring(1);
    }
    return name;
  }

  String _getTitle(int index) {
    switch (index) {
      case 0:
        return 'Tableau de bord';
      case 1:
        return 'Gestion des Devis';
      case 2:
        return 'Gestion des Commandes';
      case 3:
        return 'Rapports de production';
      case 4:
        return 'Boîte à outils';
      case 5:
        return 'Paramètres du système';
      default:
        return 'Tableau de bord';
    }
  }

  Widget _buildNavItem({
    required IconData icon,
    required String title,
    required int index,
    required bool isCompact,
  }) {
    bool isSelected = ref.watch(navigationIndexProvider) == index;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: InkWell(
        onTap: () => ref.read(navigationIndexProvider.notifier).state = index,
        borderRadius: BorderRadius.circular(VivSpacing.radiusMd),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.all(
            isCompact ? VivSpacing.space2 : VivSpacing.space3,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? VivColors.lime.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(VivSpacing.radiusMd),
            border: Border.all(
              color: isSelected
                  ? VivColors.lime.withValues(alpha: 0.2)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisAlignment: isCompact
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: [
              Icon(
                icon,
                color: isSelected ? VivColors.lime : VivColors.gray400,
                size: isCompact ? 22 : 20,
              ),
              if (!isCompact) ...[
                const SizedBox(width: VivSpacing.space3),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    softWrap: false,
                    style: TextStyle(
                      color: isSelected ? VivColors.paper : VivColors.gray400,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
