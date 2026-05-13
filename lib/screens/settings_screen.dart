import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../../design_system/viv_colors.dart';
import '../../design_system/viv_spacing.dart';
import '../../design_system/viv_typography.dart';
import '../../providers/settings_provider.dart';
import '../../services/boond_service.dart';
import '../providers/update_provider.dart';
import '../widgets/update_modal.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _boondUrlController = TextEditingController();
  final _boondUserController = TextEditingController();
  final _boondPassController = TextEditingController();
  final _smtpHostController = TextEditingController();
  final _smtpPortController = TextEditingController();
  final _smtpUserController = TextEditingController();
  final _smtpPassController = TextEditingController();
  bool _isTestingConnection = false;

  Future<void> _testConnection() async {
    setState(() => _isTestingConnection = true);
    
    final service = BoondService(
      baseUrl: _boondUrlController.text,
      user: _boondUserController.text,
      password: _boondPassController.text,
    );

    try {
      await service.testConnection();
      if (mounted) {
        try {
          final profile = await service.getCurrentUserProfile();
          _saveSettings(profile: profile);
        } catch (e) {
          _saveSettings();
        }
      }
    } catch (e) {
      if (mounted) {
        ShadToaster.of(context).show(
          ShadToast.destructive(
            title: const Text('Échec de la connexion'),
            description: Text(e.toString()),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isTestingConnection = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _boondUrlController.text = settings.boondUrl;
    _boondUserController.text = settings.boondUser;
    _boondPassController.text = settings.boondPassword;
    _smtpHostController.text = settings.smtpHost;
    _smtpPortController.text = settings.smtpPort.toString();
    _smtpUserController.text = settings.smtpUser;
    _smtpPassController.text = settings.smtpPassword;
  }

  @override
  void dispose() {
    _boondUrlController.dispose();
    _boondUserController.dispose();
    _boondPassController.dispose();
    _smtpHostController.dispose();
    _smtpPortController.dispose();
    _smtpUserController.dispose();
    _smtpPassController.dispose();
    super.dispose();
  }

  void _saveSettings({Map<String, dynamic>? profile}) {
    final settings = ref.read(settingsProvider);
    final attributes = profile?['attributes'];
    
    final newSettings = settings.copyWith(
      boondUrl: _boondUrlController.text,
      boondUser: _boondUserController.text,
      boondPassword: _boondPassController.text,
      boondFirstName: attributes?['firstName'] ?? settings.boondFirstName,
      boondLastName: attributes?['lastName'] ?? settings.boondLastName,
      smtpHost: _smtpHostController.text,
      smtpPort: int.tryParse(_smtpPortController.text) ?? 587,
      smtpUser: _smtpUserController.text,
      smtpPassword: _smtpPassController.text,
    );
    
    ref.read(settingsProvider.notifier).updateSettings(newSettings);
    
    ShadToaster.of(context).show(
      ShadToast(
        backgroundColor: VivColors.black,
        title: Row(
          children: const [
            Icon(LucideIcons.check, color: VivColors.lime, size: 20),
            SizedBox(width: 8),
            Text('Sauvegarde réussie', style: TextStyle(color: VivColors.lime, fontWeight: FontWeight.bold)),
          ],
        ),
        description: const Text('Vos préférences ont été enregistrées localement.', style: TextStyle(color: VivColors.paper)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(VivSpacing.space6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Connexion BoondManager', LucideIcons.database),
          const SizedBox(height: VivSpacing.space4),
          _buildCard([
            _buildField(
              label: 'URL de l\'API',
              controller: _boondUrlController,
              placeholder: 'https://ui.boondmanager.com/api',
            ),
            const SizedBox(height: VivSpacing.space4),
            Row(
              children: [
                Expanded(
                  child: _buildField(
                    label: 'Utilisateur',
                    controller: _boondUserController,
                    placeholder: 'email@exemple.com',
                  ),
                ),
                const SizedBox(width: VivSpacing.space4),
                Expanded(
                  child: _buildField(
                    label: 'Mot de passe / Token',
                    controller: _boondPassController,
                    placeholder: '••••••••',
                    obscureText: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: VivSpacing.space6),
            Align(
              alignment: Alignment.centerRight,
              child: ShadButton.outline(
                onPressed: _isTestingConnection ? null : _testConnection,
                size: ShadButtonSize.sm,
                child: _isTestingConnection
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: VivColors.black),
                      )
                    : const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.plugZap, size: 14),
                          SizedBox(width: 8),
                          Text('Tester la connexion'),
                        ],
                      ),
              ),
            ),
          ]),
          
          const SizedBox(height: VivSpacing.space8),
          
          _buildSectionHeader('Envoi de mails (SMTP)', LucideIcons.mail),
          const SizedBox(height: VivSpacing.space4),
          _buildCard([
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: _buildField(
                    label: 'Serveur SMTP',
                    controller: _smtpHostController,
                    placeholder: 'smtp.gmail.com',
                  ),
                ),
                const SizedBox(width: VivSpacing.space4),
                Expanded(
                  flex: 1,
                  child: _buildField(
                    label: 'Port',
                    controller: _smtpPortController,
                    placeholder: '587',
                  ),
                ),
              ],
            ),
            const SizedBox(height: VivSpacing.space4),
            Row(
              children: [
                Expanded(
                  child: _buildField(
                    label: 'Utilisateur SMTP',
                    controller: _smtpUserController,
                    placeholder: 'email@identifiant.com',
                  ),
                ),
                const SizedBox(width: VivSpacing.space4),
                Expanded(
                  child: _buildField(
                    label: 'Mot de passe SMTP',
                    controller: _smtpPassController,
                    placeholder: '••••••••',
                    obscureText: true,
                  ),
                ),
              ],
            ),
          ]),

          const SizedBox(height: VivSpacing.space8),
          
          _buildSectionHeader('Application', LucideIcons.monitor),
          const SizedBox(height: VivSpacing.space4),
          _buildCard([
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Afficher en plein écran', style: VivTypography.small.copyWith(fontWeight: FontWeight.bold)),
                    Text('Bascule l\'application en mode plein écran immersif.', style: VivTypography.small.copyWith(color: VivColors.gray500)),
                  ],
                ),
                ShadSwitch(
                  value: settings.isFullScreen,
                  onChanged: (val) => ref.read(settingsProvider.notifier).setFullScreen(val),
                ),
              ],
            ),
          ]),

          const SizedBox(height: VivSpacing.space8),
          
          _buildSectionHeader('Mises à jour', LucideIcons.refreshCw),
          const SizedBox(height: VivSpacing.space4),
          _buildCard([
            Consumer(
              builder: (context, ref, child) {
                final updateState = ref.watch(updateProvider);
                final isLoading = updateState.status == UpdateState.checking;
                
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Version de l\'application', style: VivTypography.small.copyWith(fontWeight: FontWeight.bold)),
                        Text('Version actuelle : ${updateState.currentVersion}', style: VivTypography.small.copyWith(color: VivColors.gray500)),
                      ],
                    ),
                    ShadButton.outline(
                      onPressed: isLoading ? null : () async {
                        await ref.read(updateProvider.notifier).checkForUpdates(silent: false);
                        if (ref.read(updateProvider).status == UpdateState.upToDate) {
                          if (context.mounted) {
                            ShadToaster.of(context).show(
                              const ShadToast(
                                title: Text('À jour'),
                                description: Text('Vous possédez déjà la dernière version de l\'application.'),
                              ),
                            );
                          }
                        } else if (ref.read(updateProvider).status == UpdateState.available) {
                          if (context.mounted) {
                            showUpdateDialog(context);
                          }
                        } else if (ref.read(updateProvider).status == UpdateState.error) {
                          if (context.mounted) {
                            ShadToaster.of(context).show(
                              const ShadToast.destructive(
                                title: Text('Erreur'),
                                description: Text('Impossible de vérifier les mises à jour. Vérifiez votre connexion internet.'),
                              ),
                            );
                          }
                        }
                      },
                      child: isLoading
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: VivColors.black),
                            )
                          : const Text('Rechercher une mise à jour'),
                    ),
                  ],
                );
              },
            ),
          ]),
          
          const SizedBox(height: VivSpacing.space9),
          
          Center(
            child: ShadButton(
              onPressed: _saveSettings,
              child: const Text('Enregistrer les paramètres'),
            ),
          ),
          
          const SizedBox(height: VivSpacing.space9),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: VivColors.lime),
        const SizedBox(width: VivSpacing.space3),
        Text(title, style: VivTypography.h4.copyWith(color: VivColors.black)),
      ],
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(VivSpacing.space6),
      decoration: BoxDecoration(
        color: VivColors.paper,
        borderRadius: BorderRadius.circular(VivSpacing.radiusMd),
        border: Border.all(color: VivColors.gray200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    String? placeholder,
    bool obscureText = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: VivTypography.small.copyWith(fontWeight: FontWeight.bold, color: VivColors.ink800)),
        const SizedBox(height: 8),
        ShadInput(
          controller: controller,
          placeholder: placeholder != null ? Text(placeholder) : null,
          obscureText: obscureText,
        ),
      ],
    );
  }
}
