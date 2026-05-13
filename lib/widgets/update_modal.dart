import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../design_system/viv_colors.dart';
import '../design_system/viv_spacing.dart';
import '../design_system/viv_typography.dart';
import '../providers/update_provider.dart';

class UpdateModal extends ConsumerWidget {
  const UpdateModal({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final updateState = ref.watch(updateProvider);

    return ShadDialog(
      title: const Row(
        children: [
          Icon(LucideIcons.cloudDownload, color: VivColors.black),
          SizedBox(width: VivSpacing.space3),
          Text('Mise à jour disponible'),
        ],
      ),
      description: const Text(
        'Une nouvelle version de VIV Admin Toolbox est disponible.',
      ),
      actions: [
        if (updateState.status != UpdateState.downloading && updateState.status != UpdateState.readyToInstall)
          ShadButton.outline(
            onPressed: () {
              ref.read(updateProvider.notifier).ignoreUpdate();
              Navigator.of(context).pop();
            },
            child: const Text('Ignorer'),
          ),
        if (updateState.status != UpdateState.downloading && updateState.status != UpdateState.readyToInstall)
          ShadButton(
            onPressed: () {
              ref.read(updateProvider.notifier).downloadAndInstall();
            },
            child: const Text('Télécharger et installer'),
          ),
        if (updateState.status == UpdateState.downloading)
          const ShadButton.ghost(
            enabled: false,
            child: Text('Patientez...'),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: VivSpacing.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (updateState.release != null) ...[
              Text(
                'Version ${updateState.release!.tagName}',
                style: VivTypography.body.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: VivSpacing.space2),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(VivSpacing.space3),
                decoration: BoxDecoration(
                  color: VivColors.gray100,
                  borderRadius: BorderRadius.circular(VivSpacing.radiusMd),
                ),
                child: Text(
                  updateState.release!.body.isEmpty 
                      ? 'Améliorations et corrections de bugs.' 
                      : updateState.release!.body,
                  style: VivTypography.small,
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            
            const SizedBox(height: VivSpacing.space4),
            
            if (updateState.status == UpdateState.downloading) ...[
              const Text('Téléchargement en cours...'),
              const SizedBox(height: VivSpacing.space2),
              LinearProgressIndicator(
                value: updateState.downloadProgress,
                backgroundColor: VivColors.gray200,
                color: VivColors.lime,
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: VivSpacing.space1),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '${(updateState.downloadProgress * 100).toStringAsFixed(1)}%',
                  style: VivTypography.small.copyWith(color: VivColors.gray500),
                ),
              ),
            ] else if (updateState.status == UpdateState.error) ...[
              const Text(
                'Une erreur est survenue lors du téléchargement.',
                style: TextStyle(color: Colors.red),
              )
            ],
          ],
        ),
      ),
    );
  }
}

void showUpdateDialog(BuildContext context) {
  showShadDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => const UpdateModal(),
  );
}
