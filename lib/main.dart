import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:window_manager/window_manager.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'design_system/viv_theme.dart';
import 'design_system/viv_shadcn_theme.dart';
import 'screens/main_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialisation de la locale pour le formatage des dates (ex: "Mars 2026")
  await initializeDateFormatting('fr_FR', null);

  // Initialisation de la gestion de fenêtre
  await windowManager.ensureInitialized();

  WindowOptions windowOptions = const WindowOptions(
    size: Size(1280, 800),
    minimumSize: Size(1280, 800), // Taille minimale imposée
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden, // Masque la barre de titre Windows
  );
  
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(
    // ProviderScope pour l'état global Riverpod
    const ProviderScope(
      child: OpsisApp(),
    ),
  );
}

class OpsisApp extends StatelessWidget {
  const OpsisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ShadApp(
      title: 'Opsis - VIV Support',
      debugShowCheckedModeBanner: false,
      theme: VivShadcnTheme.lightTheme,
      materialThemeBuilder: (context, shadTheme) {
        return VivTheme.lightTheme;
      },
      home: const MainShell(),
    );
  }
}
