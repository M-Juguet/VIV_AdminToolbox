import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/update_service.dart';
import '../models/github_release.dart';

enum UpdateState { initial, checking, upToDate, available, downloading, readyToInstall, error }

class UpdateStateData {
  final UpdateState status;
  final GithubRelease? release;
  final String currentVersion;
  final double downloadProgress;
  final String? exePath;

  UpdateStateData({
    required this.status,
    this.release,
    this.currentVersion = '',
    this.downloadProgress = 0.0,
    this.exePath,
  });

  UpdateStateData copyWith({
    UpdateState? status,
    GithubRelease? release,
    String? currentVersion,
    double? downloadProgress,
    String? exePath,
  }) {
    return UpdateStateData(
      status: status ?? this.status,
      release: release ?? this.release,
      currentVersion: currentVersion ?? this.currentVersion,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      exePath: exePath ?? this.exePath,
    );
  }
}

final updateServiceProvider = Provider((ref) => UpdateService());

final updateProvider = NotifierProvider<UpdateNotifier, UpdateStateData>(
  () => UpdateNotifier(),
);

class UpdateNotifier extends Notifier<UpdateStateData> {
  late UpdateService _service;

  @override
  UpdateStateData build() {
    _service = ref.read(updateServiceProvider);
    // On lance la récupération de version locale en arrière-plan
    Future.microtask(_initVersion);
    return UpdateStateData(status: UpdateState.initial);
  }

  Future<void> _initVersion() async {
    final version = await _service.getCurrentVersion();
    state = state.copyWith(currentVersion: version);
  }

  Future<void> checkForUpdates({bool silent = false}) async {
    if (state.status == UpdateState.checking || state.status == UpdateState.downloading) return;
    
    state = state.copyWith(status: UpdateState.checking);
    
    try {
      final currentVersion = await _service.getCurrentVersion();
      state = state.copyWith(currentVersion: currentVersion);
      
      final release = await _service.checkUpdate();
      
      if (release != null && release.isNewerThan(currentVersion)) {
        state = state.copyWith(status: UpdateState.available, release: release);
      } else {
        state = state.copyWith(status: UpdateState.upToDate);
        if (silent) {
          Future.delayed(const Duration(seconds: 3), () {
            state = state.copyWith(status: UpdateState.initial);
          });
        }
      }
    } catch (e) {
      state = state.copyWith(status: UpdateState.error);
    }
  }

  Future<void> downloadAndInstall() async {
    if (state.release?.downloadUrl == null) return;
    
    state = state.copyWith(status: UpdateState.downloading, downloadProgress: 0.0);
    
    final path = await _service.downloadUpdate(
      state.release!.downloadUrl!,
      (received, total) {
        if (total != -1) {
          state = state.copyWith(downloadProgress: received / total);
        }
      },
    );
    
    if (path != null) {
      state = state.copyWith(status: UpdateState.readyToInstall, exePath: path);
      await _service.installUpdate(path);
    } else {
      state = state.copyWith(status: UpdateState.error);
    }
  }
  
  void ignoreUpdate() {
    state = state.copyWith(status: UpdateState.initial);
  }
}

