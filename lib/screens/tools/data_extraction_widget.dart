import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../design_system/viv_colors.dart';
import '../../design_system/viv_spacing.dart';
import '../../design_system/viv_typography.dart';
import '../../services/extraction_service.dart';


enum ExtractionStatus { idle, running, success, error }

class ExtractionToolItem {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  ExtractionStatus status;
  String? progressMessage;
  String? errorMessage;
  String? outputFilePath;

  ExtractionToolItem({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    this.status = ExtractionStatus.idle,
    this.progressMessage,
    this.errorMessage,
    this.outputFilePath,
  });
}

class DataExtractionWidget extends ConsumerStatefulWidget {
  final VoidCallback onClose;

  const DataExtractionWidget({
    super.key,
    required this.onClose,
  });

  @override
  ConsumerState<DataExtractionWidget> createState() => _DataExtractionWidgetState();
}

class _DataExtractionWidgetState extends ConsumerState<DataExtractionWidget> {
  String _exportDirectory = "Chargement...";
  final List<String> _logs = [];
  final ScrollController _logScrollController = ScrollController();
  bool _isExtractingAll = false;

  late final List<ExtractionToolItem> _tools;

  @override
  void initState() {
    super.initState();
    _initExportDirectory();
    _tools = [
      ExtractionToolItem(
        id: 'clients',
        title: "Clients",
        description: "Extraction des entreprises actives et prospects de BoondManager.",
        icon: LucideIcons.building2,
      ),
      ExtractionToolItem(
        id: 'ressources',
        title: "Ressources",
        description: "Extraction des collaborateurs, candidats et prestataires externes.",
        icon: LucideIcons.users,
      ),
      ExtractionToolItem(
        id: 'timesheets',
        title: "Feuilles de temps",
        description: "Extraction détaillée des temps saisis (CRA) avec taux et unités d'œuvre.",
        icon: LucideIcons.calendarClock,
      ),
      ExtractionToolItem(
        id: 'contrats',
        title: "Contrats",
        description: "Extraction des contrats de travail et de sous-traitance des ressources.",
        icon: LucideIcons.fileText,
      ),
      ExtractionToolItem(
        id: 'projets',
        title: "Projets",
        description: "Extraction des données financières, dates et statuts des projets.",
        icon: LucideIcons.folder,
      ),
      ExtractionToolItem(
        id: 'managers',
        title: "Managers",
        description: "Extraction de la liste des managers et administrateurs de l'instance.",
        icon: LucideIcons.userCheck,
      ),
      ExtractionToolItem(
        id: 'purchases',
        title: "Achats",
        description: "Extraction de la liste des achats (licences, sous-traitance, matériels).",
        icon: LucideIcons.shoppingBag,
      ),
      ExtractionToolItem(
        id: 'contacts',
        title: "Contacts clients",
        description: "Extraction des coordonnées des contacts clients associés aux entreprises.",
        icon: LucideIcons.contact,
      ),
    ];
    _addLog("Outil d'extraction BoondManager initialisé.");
  }

  @override
  void dispose() {
    _logScrollController.dispose();
    super.dispose();
  }

  Future<void> _initExportDirectory() async {
    try {
      Directory? directory;
      if (Platform.isWindows) {
        // Sous Windows, on tente d'obtenir le dossier Téléchargements standard
        final home = Platform.environment['USERPROFILE'];
        if (home != null) {
          final downloads = Directory('$home\\Downloads');
          if (await downloads.exists()) {
            directory = downloads;
          }
        }
      }
      
      // Fallback sur le dossier document par défaut si non trouvé
      directory ??= await getApplicationDocumentsDirectory();

      if (mounted) {
        setState(() {
          _exportDirectory = directory!.path;
        });
        _addLog("Dossier d'exportation configuré : $_exportDirectory");
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _exportDirectory = "Erreur lors de la détection du dossier";
        });
        _addLog("Erreur lors de l'initialisation du dossier d'export : $e");
      }
    }
  }

  void _addLog(String message) {
    final timestamp = DateTime.now().toString().substring(11, 19);
    setState(() {
      _logs.add("[$timestamp] $message");
    });
    // Auto scroll vers le bas des logs
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logScrollController.hasClients) {
        _logScrollController.animateTo(
          _logScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _clearLogs() {
    setState(() {
      _logs.clear();
    });
  }

  // Placeholder pour le lancement des extractions (sera développé outil par outil)
  Future<void> _runExtraction(ExtractionToolItem tool) async {
    if (tool.status == ExtractionStatus.running) return;

    setState(() {
      tool.status = ExtractionStatus.running;
      tool.progressMessage = "Initialisation...";
      tool.errorMessage = null;
    });
    _addLog("Début de l'extraction : ${tool.title}...");

    try {
      if (tool.id == 'clients') {
        // --- EXTRACTION RÉELLE DES CLIENTS ---
        final service = ref.read(extractionServiceProvider);
        final resultPath = await service.extractPagedCsv(
          path: 'companies/extraction',
          queryParameters: {
            'keywordsType': '',
            'order': 'asc',
            'period': '',
            'states': '8,1',
            'viewMode': 'list',
          },
          destinationDir: _exportDirectory,
          fileName: 'extraction_clients.csv',
          onProgress: (msg) {
            if (mounted) {
              setState(() {
                tool.progressMessage = msg;
              });
              _addLog("[${tool.title}] $msg");
            }
          },
        );

        if (mounted) {
          setState(() {
            tool.status = ExtractionStatus.success;
            tool.progressMessage = null;
            tool.outputFilePath = resultPath;
          });
          _addLog("[${tool.title}] Extraction réussie ! Enregistré dans : $resultPath");
        }
      } else if (tool.id == 'ressources') {
        // --- EXTRACTION RÉELLE DES RESSOURCES ---
        final service = ref.read(extractionServiceProvider);
        final resultPath = await service.extractPagedCsv(
          path: 'resources/extraction',
          queryParameters: {
            'excludeManager': 'false',
            'order': 'asc',
            'viewMode': 'list',
          },
          destinationDir: _exportDirectory,
          fileName: 'extraction_ressources.csv',
          onProgress: (msg) {
            if (mounted) {
              setState(() {
                tool.progressMessage = msg;
              });
              _addLog("[${tool.title}] $msg");
            }
          },
        );

        if (mounted) {
          setState(() {
            tool.status = ExtractionStatus.success;
            tool.progressMessage = null;
            tool.outputFilePath = resultPath;
          });
          _addLog("[${tool.title}] Extraction réussie ! Enregistré dans : $resultPath");
        }
      } else if (tool.id == 'timesheets') {
        // --- EXTRACTION RÉELLE DES FEUILLES DE TEMPS ---
        final service = ref.read(extractionServiceProvider);
        
        // Détermination dynamique de la période (mois précédent et mois en cours)
        // car l'export de feuilles de temps global peut être bloqué par le serveur BoondManager sans dates.
        final now = DateTime.now();
        final prev = DateTime(now.year, now.month - 1);
        final startMonthStr = "${prev.year}-${prev.month.toString().padLeft(2, '0')}";
        final endMonthStr = "${now.year}-${now.month.toString().padLeft(2, '0')}";
        
        final params = {
          'extractType': 'detailedInWorkUnitRate',
          'order': 'asc',
          'startMonth': startMonthStr,
          'endMonth': endMonthStr,
        };

        String resultPath;
        try {
          // Essai 1 : Route sans tiret (d'origine n8n)
          resultPath = await service.extractPagedCsv(
            path: 'timesreports/extraction',
            queryParameters: params,
            destinationDir: _exportDirectory,
            fileName: 'extraction_feuilles_de_temps.csv',
            onProgress: (msg) {
              if (mounted) {
                setState(() {
                  tool.progressMessage = msg;
                });
                _addLog("[${tool.title}] $msg");
              }
            },
          );
        } catch (e) {
          // Si l'erreur signale du HTML (redirection de route invalide), on tente le repli avec tiret
          if (e.toString().contains('HTML')) {
            _addLog("[${tool.title}] Repli : Tentative avec la route alternative 'times-reports'...");
            resultPath = await service.extractPagedCsv(
              path: 'times-reports/extraction',
              queryParameters: params,
              destinationDir: _exportDirectory,
              fileName: 'extraction_feuilles_de_temps.csv',
              onProgress: (msg) {
                if (mounted) {
                  setState(() {
                    tool.progressMessage = msg;
                  });
                  _addLog("[${tool.title}] (Alternative) $msg");
                }
              },
            );
          } else {
            rethrow;
          }
        }

        if (mounted) {
          setState(() {
            tool.status = ExtractionStatus.success;
            tool.progressMessage = null;
            tool.outputFilePath = resultPath;
          });
          _addLog("[${tool.title}] Extraction réussie ! Enregistré dans : $resultPath");
        }
      } else if (tool.id == 'contrats') {
        // --- EXTRACTION RÉELLE DES CONTRATS ---
        final service = ref.read(extractionServiceProvider);
        final resultPath = await service.extractPagedCsv(
          path: 'apps/contracts/contracts/extraction',
          queryParameters: {
            'order': 'desc',
            'sort': 'endDate',
          },
          destinationDir: _exportDirectory,
          fileName: 'extraction_contrats.csv',
          onProgress: (msg) {
            if (mounted) {
              setState(() {
                tool.progressMessage = msg;
              });
              _addLog("[${tool.title}] $msg");
            }
          },
        );

        if (mounted) {
          setState(() {
            tool.status = ExtractionStatus.success;
            tool.progressMessage = null;
            tool.outputFilePath = resultPath;
          });
          _addLog("[${tool.title}] Extraction réussie ! Enregistré dans : $resultPath");
        }
      } else if (tool.id == 'projets') {
        // --- EXTRACTION RÉELLE DES PROJETS ---
        final service = ref.read(extractionServiceProvider);
        final resultPath = await service.extractPagedCsv(
          path: 'projects/extraction',
          queryParameters: {
            'order': 'asc',
            'period': '',
            'sumAdditionalData': 'true',
          },
          destinationDir: _exportDirectory,
          fileName: 'extraction_projets.csv',
          onProgress: (msg) {
            if (mounted) {
              setState(() {
                tool.progressMessage = msg;
              });
              _addLog("[${tool.title}] $msg");
            }
          },
        );

        if (mounted) {
          setState(() {
            tool.status = ExtractionStatus.success;
            tool.progressMessage = null;
            tool.outputFilePath = resultPath;
          });
          _addLog("[${tool.title}] Extraction réussie ! Enregistré dans : $resultPath");
        }
      } else if (tool.id == 'managers') {
        // --- EXTRACTION RÉELLE DES MANAGERS ---
        final service = ref.read(extractionServiceProvider);
        final resultPath = await service.extractPagedCsv(
          path: 'apps/extractbi/requests/5971/download',
          queryParameters: {
            'language': 'fr',
            'encoding': 'UTF-8',
          },
          destinationDir: _exportDirectory,
          fileName: 'extraction_managers.csv',
          onProgress: (msg) {
            if (mounted) {
              setState(() {
                tool.progressMessage = msg;
              });
              _addLog("[${tool.title}] $msg");
            }
          },
        );

        if (mounted) {
          setState(() {
            tool.status = ExtractionStatus.success;
            tool.progressMessage = null;
            tool.outputFilePath = resultPath;
          });
          _addLog("[${tool.title}] Extraction réussie ! Enregistré dans : $resultPath");
        }
      } else if (tool.id == 'purchases') {
        // --- EXTRACTION RÉELLE DES ACHATS ---
        final service = ref.read(extractionServiceProvider);
        final resultPath = await service.extractPagedCsv(
          path: 'purchases/extraction',
          queryParameters: {
            'order': 'asc',
          },
          destinationDir: _exportDirectory,
          fileName: 'extraction_achats.csv',
          onProgress: (msg) {
            if (mounted) {
              setState(() {
                tool.progressMessage = msg;
              });
              _addLog("[${tool.title}] $msg");
            }
          },
        );

        if (mounted) {
          setState(() {
            tool.status = ExtractionStatus.success;
            tool.progressMessage = null;
            tool.outputFilePath = resultPath;
          });
          _addLog("[${tool.title}] Extraction réussie ! Enregistré dans : $resultPath");
        }
      } else if (tool.id == 'contacts') {
        // --- EXTRACTION RÉELLE DES CONTACTS CLIENTS ---
        final service = ref.read(extractionServiceProvider);
        final resultPath = await service.extractPagedCsv(
          path: 'contacts/extraction',
          queryParameters: {
            'order': 'asc',
            'viewMode': 'list',
          },
          destinationDir: _exportDirectory,
          fileName: 'extraction_contacts.csv',
          onProgress: (msg) {
            if (mounted) {
              setState(() {
                tool.progressMessage = msg;
              });
              _addLog("[${tool.title}] $msg");
            }
          },
        );

        if (mounted) {
          setState(() {
            tool.status = ExtractionStatus.success;
            tool.progressMessage = null;
            tool.outputFilePath = resultPath;
          });
          _addLog("[${tool.title}] Extraction réussie ! Enregistré dans : $resultPath");
        }
      } else {
        // --- SIMULATION POUR LES AUTRES OUTILS A VENIR ---
        await Future.delayed(const Duration(seconds: 1));
        if (!mounted) return;

        setState(() {
          tool.progressMessage = "Pagination : Page 1...";
        });
        _addLog("[${tool.title}] Téléchargement des données (simulé)...");

        await Future.delayed(const Duration(seconds: 1));
        if (!mounted) return;

        setState(() {
          tool.status = ExtractionStatus.success;
          tool.progressMessage = null;
          tool.outputFilePath = "$_exportDirectory${Platform.pathSeparator}extraction_${tool.id}.csv";
        });
        _addLog("[${tool.title}] Extraction réussie ! Fichier enregistré.");
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          tool.status = ExtractionStatus.error;
          tool.progressMessage = null;
          tool.errorMessage = e.toString();
        });
        _addLog("[${tool.title}] ERREUR : $e");
      }
    }
  }

  Future<void> _runAllExtractions() async {
    if (_isExtractingAll) return;
    setState(() {
      _isExtractingAll = true;
    });
    _addLog("Lancement global de toutes les extractions...");

    for (var tool in _tools) {
      if (!mounted) break;
      await _runExtraction(tool);
    }

    if (mounted) {
      setState(() {
        _isExtractingAll = false;
      });
      _addLog("Toutes les extractions terminées.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return ShadCard(
      padding: EdgeInsets.zero,
      backgroundColor: VivColors.paper,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: VivSpacing.space6,
                vertical: VivSpacing.space4,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFolderSelector(),
                  const SizedBox(height: VivSpacing.space5),
                  Text("Extractions disponibles (${_tools.length})", style: VivTypography.h4),
                  const SizedBox(height: VivSpacing.space3),
                  _buildToolsList(),
                  const SizedBox(height: VivSpacing.space5),
                  _buildConsoleLogs(),
                ],
              ),
            ),
          ),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(VivSpacing.space5),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: VivColors.gray100)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: VivColors.lime.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(VivSpacing.radiusSm),
                ),
                child: const Icon(LucideIcons.download, color: VivColors.lime, size: 20),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Extracteur de Données BoondManager", style: VivTypography.h3),
                  Text(
                    "Téléchargez les données brutes paginées pour alimenter vos analyses.",
                    style: VivTypography.small.copyWith(color: VivColors.gray500, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
          IconButton(
            onPressed: widget.onClose,
            icon: const Icon(LucideIcons.x, size: 18),
            style: IconButton.styleFrom(
              hoverColor: VivColors.gray100,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(VivSpacing.radiusSm),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFolderSelector() {
    return Container(
      padding: const EdgeInsets.all(VivSpacing.space4),
      decoration: BoxDecoration(
        color: VivColors.gray50,
        borderRadius: BorderRadius.circular(VivSpacing.radiusMd),
        border: Border.all(color: VivColors.gray100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.folder, size: 16, color: VivColors.gray500),
              const SizedBox(width: 8),
              Text(
                "Dossier de destination",
                style: VivTypography.small.copyWith(fontWeight: FontWeight.bold, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  _exportDirectory,
                  style: VivTypography.small.copyWith(
                    color: VivColors.gray500,
                    fontFamily: 'monospace',
                    fontSize: 10,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              ShadButton.outline(
                size: ShadButtonSize.sm,
                onPressed: _initExportDirectory,
                child: const Text("Réinitialiser", style: TextStyle(fontSize: 10)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToolsList() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _tools.length,
      separatorBuilder: (context, index) => const SizedBox(height: VivSpacing.space3),
      itemBuilder: (context, index) {
        final tool = _tools[index];
        return Container(
          padding: const EdgeInsets.all(VivSpacing.space4),
          decoration: BoxDecoration(
            color: VivColors.paper,
            borderRadius: BorderRadius.circular(VivSpacing.radiusMd),
            border: Border.all(
              color: tool.status == ExtractionStatus.running 
                  ? VivColors.lime 
                  : VivColors.gray100,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: VivColors.gray100,
                  borderRadius: BorderRadius.circular(VivSpacing.radiusSm),
                ),
                child: Icon(tool.icon, size: 20, color: VivColors.black),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tool.title,
                      style: VivTypography.small.copyWith(
                        fontWeight: FontWeight.bold,
                        color: VivColors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tool.description,
                      style: VivTypography.small.copyWith(color: VivColors.gray500, fontSize: 11),
                    ),
                    if (tool.progressMessage != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const SizedBox(
                            width: 10,
                            height: 10,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: VivColors.lime,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              tool.progressMessage!,
                              style: VivTypography.small.copyWith(
                                color: VivColors.limeDeep,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else if (tool.status == ExtractionStatus.success) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(LucideIcons.check, size: 12, color: Colors.green),
                          const SizedBox(width: 6),
                          Text(
                            "Exporté avec succès",
                            style: VivTypography.small.copyWith(
                              color: Colors.green,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ] else if (tool.status == ExtractionStatus.error) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(LucideIcons.shieldAlert, size: 12, color: Colors.red),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              tool.errorMessage ?? "Échec de l'exportation",
                              style: VivTypography.small.copyWith(
                                color: Colors.red,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ]
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _buildToolActionButton(tool),
            ],
          ),
        );
      },
    );
  }

  Widget _buildToolActionButton(ExtractionToolItem tool) {
    if (tool.status == ExtractionStatus.running) {
      return const SizedBox(
        width: 32,
        height: 32,
        child: Padding(
          padding: EdgeInsets.all(8.0),
          child: CircularProgressIndicator(strokeWidth: 2, color: VivColors.black),
        ),
      );
    }

    if (tool.status == ExtractionStatus.success) {
      return ShadButton.outline(
        size: ShadButtonSize.sm,
        onPressed: () async {
          if (tool.outputFilePath != null) {
            _addLog("Ouverture du fichier : ${tool.outputFilePath}");
            try {
              final Uri fileUri = Uri.file(tool.outputFilePath!);
              if (!await launchUrl(fileUri)) {
                // Fallback: ouvrir le répertoire parent
                final Directory dir = Directory(_exportDirectory);
                await launchUrl(Uri.file(dir.path));
              }
            } catch (e) {
              _addLog("Impossible d'ouvrir le fichier : $e");
            }
          }
        },
        child: const Icon(LucideIcons.externalLink, size: 14),
      );
    }

    return ShadButton(
      size: ShadButtonSize.sm,
      backgroundColor: VivColors.black,
      hoverBackgroundColor: VivColors.ink800,
      onPressed: _isExtractingAll ? null : () => _runExtraction(tool),
      child: const Text("Extraire", style: TextStyle(color: Colors.white, fontSize: 11)),
    );
  }

  Widget _buildConsoleLogs() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(LucideIcons.terminal, size: 14, color: VivColors.gray500),
                const SizedBox(width: 6),
                Text(
                  "Journal de progression",
                  style: VivTypography.small.copyWith(fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ],
            ),
            TextButton(
              onPressed: _clearLogs,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                "Effacer",
                style: VivTypography.small.copyWith(color: VivColors.gray500, fontSize: 10),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: 120,
          width: double.infinity,
          padding: const EdgeInsets.all(VivSpacing.space3),
          decoration: BoxDecoration(
            color: VivColors.ink900,
            borderRadius: BorderRadius.circular(VivSpacing.radiusMd),
          ),
          child: ListView.builder(
            controller: _logScrollController,
            itemCount: _logs.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 2.0),
                child: Text(
                  _logs[index],
                  style: const TextStyle(
                    color: Color(0xFF00FF00),
                    fontFamily: 'monospace',
                    fontSize: 9.5,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(VivSpacing.space5),
      decoration: const BoxDecoration(
        color: VivColors.gray50,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(VivSpacing.radiusMd),
          bottomRight: Radius.circular(VivSpacing.radiusMd),
        ),
        border: Border(top: BorderSide(color: VivColors.gray100)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            _isExtractingAll ? "Extraction globale en cours..." : "Prêt pour les extractions",
            style: VivTypography.small.copyWith(color: VivColors.gray500, fontSize: 11),
          ),
          Row(
            children: [
              ShadButton.outline(
                onPressed: widget.onClose,
                child: const Text("Fermer"),
              ),
              const SizedBox(width: 12),
              ShadButton(
                backgroundColor: VivColors.lime,
                hoverBackgroundColor: VivColors.green600,
                onPressed: _isExtractingAll || _tools.any((t) => t.status == ExtractionStatus.running)
                    ? null
                    : _runAllExtractions,
                child: Text(
                  "Tout extraire",
                  style: VivTypography.small.copyWith(
                    fontWeight: FontWeight.bold,
                    color: VivColors.black,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
