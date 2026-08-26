import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:opsis_app/screens/bdc_screen.dart'; // Pour importer BdcPrestaStep2
import 'package:image/image.dart' as img;
import 'package:opsis_app/services/bdc_sent_logs_service.dart';

class BdcPdfService {
  /// Génère le PDF d'un bon de commande sous forme d'octets (Uint8List).
  static Future<Uint8List> generateBdcPdf(
    BdcPrestaStep2 presta,
    String periodMonth,
    String periodYear,
  ) async {
    final pdf = pw.Document();

    // Charger les polices locales Noto Sans pour le support Unicode (€ et œ)
    final regularFontData = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
    final regularFont = pw.Font.ttf(regularFontData);

    final italicFontData = await rootBundle.load('assets/fonts/NotoSans-Italic.ttf');
    final italicFont = pw.Font.ttf(italicFontData);

    final boldItalicFontData = await rootBundle.load('assets/fonts/NotoSans-BoldItalic.ttf');
    final boldItalicFont = pw.Font.ttf(boldItalicFontData);

    // Charger Playfair Display pour le titre "Bon de commande"
    final playfairData = await rootBundle.load('assets/fonts/PlayfairDisplay-BoldItalic.ttf');
    final playfairFont = pw.Font.ttf(playfairData);

    // Récupérer la police Bold de Google Fonts (avec fallback local régulier pour le hors-ligne)
    pw.Font? boldFont;
    try {
      boldFont = await PdfGoogleFonts.notoSansBold();
    } catch (_) {
      boldFont = regularFont;
    }

    final theme = pw.ThemeData.withFont(
      base: regularFont,
      italic: italicFont,
      bold: boldFont,
      boldItalic: boldItalicFont,
    );

    // Récupérer les dates réelles de la prestation
    final String startDate = presta.startDate;
    final String endDate = presta.endDate;

    // Date du jour pour la signature ("Le $TODAY$")
    final String todayDate = DateFormat('dd/MM/yyyy').format(DateTime.now());

    // Calculer le numéro séquentiel dynamique du BDC pour ce fournisseur et cette année
    final logsService = BdcSentLogsService();
    final int existingCount = await logsService.getSentCountForProvider(presta.providerId, periodYear);
    final String seqStr = (existingCount + 1).toString().padLeft(2, '0');
    final String yearSuffix = periodYear.substring(periodYear.length - 2);
    final String bdcNumber = "VIV-PO-CSOC${presta.providerId}-$yearSuffix$seqStr";

    // Charger l'image du logo Viv blanc depuis les assets de manière robuste (CPU-only)
    final logoImage = await _loadRobustImage('assets/images/viv-horizontal-white-sm.png');

    // Charger l'image du badge Ecovadis de manière robuste (CPU-only)
    final ecovadisImage = await _loadRobustImage('assets/images/ecovadis-or-2024.png');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero, // Marge de page zéro pour en-tête pleine largeur
        theme: theme, // Application du thème Unicode Noto Sans
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // 1. BANDEAU EN-TÊTE NOIR (Logo à gauche, Date à droite)
              pw.Container(
                color: PdfColor.fromHex('#000000'),
                padding: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 16),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    if (logoImage != null)
                      pw.Image(logoImage, height: 32, fit: pw.BoxFit.contain)
                    else
                      pw.Text(
                        "VIV",
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 22,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    pw.Text(
                      "Le $todayDate",
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              // Bandeau de dégradé/ligne verte sous l'en-tête
              pw.Container(
                height: 4,
                color: PdfColor.fromHex('#A3E635'), // Couleur verte de Viv
              ),

              // Corps du PDF avec marges intérieures de 36
              pw.Expanded(
                child: pw.Padding(
                  padding: const pw.EdgeInsets.fromLTRB(36, 20, 36, 24),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // 2. TITRE DU BON DE COMMANDE
                      pw.Align(
                        alignment: pw.Alignment.centerLeft,
                        child: pw.RichText(
                          text: pw.TextSpan(
                            children: [
                              pw.TextSpan(
                                text: "Bon de commande ",
                                style: pw.TextStyle(
                                  font: playfairFont,
                                  fontSize: 18,
                                  color: PdfColors.black,
                                ),
                              ),
                              pw.TextSpan(
                                text: "N° $bdcNumber",
                                style: pw.TextStyle(
                                  fontSize: 18,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 20),

                      // 3. BLOCS D'ADRESSES CÔTE À CÔTE
                      pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          // Adresse de Facturation (Gauche)
                          pw.Expanded(
                            child: pw.Container(
                              padding: const pw.EdgeInsets.all(10),
                              height: 120,
                              decoration: pw.BoxDecoration(
                                border: pw.Border.all(color: PdfColors.black, width: 1),
                              ),
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text(
                                    "Adresse de facturation :",
                                    style: pw.TextStyle(
                                      fontWeight: pw.FontWeight.bold,
                                      fontSize: 10,
                                      decoration: pw.TextDecoration.underline,
                                    ),
                                  ),
                                  pw.SizedBox(height: 6),
                                  pw.Text("VIV", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                                  pw.Text("Service Comptabilité Fournisseurs", style: pw.TextStyle(fontSize: 9)),
                                  pw.Text("14 rue de Mantes", style: pw.TextStyle(fontSize: 9)),
                                  pw.Text("92700 Colombes", style: pw.TextStyle(fontSize: 9)),
                                  pw.Text("France", style: pw.TextStyle(fontSize: 9)),
                                  pw.Text("TVA FR89811694215", style: pw.TextStyle(fontSize: 9)),
                                ],
                              ),
                            ),
                          ),
                          pw.SizedBox(width: 16),
                          // Réf. Contrat Fournisseur (Droite)
                          pw.Expanded(
                            child: pw.Container(
                              padding: const pw.EdgeInsets.all(10),
                              height: 120,
                              decoration: pw.BoxDecoration(
                                border: pw.Border.all(color: PdfColors.black, width: 1),
                              ),
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text(
                                    "Réf. Contrat fournisseur : $periodYear-CSOC${presta.providerId}",
                                    style: pw.TextStyle(
                                      fontWeight: pw.FontWeight.bold,
                                      fontSize: 10,
                                      decoration: pw.TextDecoration.underline,
                                    ),
                                  ),
                                  pw.SizedBox(height: 6),
                                  pw.Text(presta.providerName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                                  pw.Text(presta.providerAddress, style: pw.TextStyle(fontSize: 9)),
                                  pw.Text("${presta.providerPostcode} ${presta.providerTown}", style: pw.TextStyle(fontSize: 9)),
                                  pw.Text(presta.providerCountry, style: pw.TextStyle(fontSize: 9)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 20),

                      // 4. RÉFÉRENCES À RAPPELER
                      pw.RichText(
                        text: pw.TextSpan(
                          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
                          children: [
                            const pw.TextSpan(text: "Références à rappeler "),
                            pw.TextSpan(
                              text: "obligatoirement",
                              style: pw.TextStyle(decoration: pw.TextDecoration.underline),
                            ),
                            const pw.TextSpan(text: " sur vos factures :"),
                          ],
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Row(
                        children: [
                          pw.Text("N° du Bon de commande : ", style: pw.TextStyle(fontSize: 9)),
                          pw.Text(bdcNumber, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                      pw.SizedBox(height: 12),

                      // 5. TABLEAU DES PRESTATIONS
                      pw.Table(
                        border: pw.TableBorder.all(color: PdfColors.black, width: 1),
                        columnWidths: {
                          0: const pw.FlexColumnWidth(3),
                          1: const pw.FlexColumnWidth(1.2),
                          2: const pw.FlexColumnWidth(1.2),
                          3: const pw.FlexColumnWidth(0.8),
                          4: const pw.FlexColumnWidth(1.5),
                        },
                        children: [
                          // En-têtes du tableau
                          pw.TableRow(
                            children: [
                              _buildTableHeaderCell("Prestation engageable"),
                              _buildTableHeaderCell("Date de début"),
                              _buildTableHeaderCell("Date de fin"),
                              _buildTableHeaderCell("Unité"),
                              _buildTableHeaderCell("Prix Unit. HT EUR"),
                            ],
                          ),
                          // Ligne de contenu
                          pw.TableRow(
                            children: [
                              _buildTableCell(
                                presta.prestationRef,
                                subtitle: presta.prestationTitle.replaceAll(RegExp(r'^MIS\d+\s*-\s*'), ''),
                              ),
                              _buildTableCell(startDate, alignCenter: true),
                              _buildTableCell(endDate, alignCenter: true),
                              _buildTableCell("UO", alignCenter: true),
                              _buildTableCell("${presta.tjm.toStringAsFixed(2)} €", alignRight: true),
                            ],
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 16),

                      // 6. TOTALISATEURS (UO et Montants maximums)
                      pw.Align(
                        alignment: pw.Alignment.centerRight,
                        child: pw.Container(
                          width: 320, // Alignement à droite impeccable des valeurs
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.end,
                            children: [
                              pw.Row(
                                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                children: [
                                  pw.Text(
                                    "Nombre maximum d'UO autorisé",
                                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                                  ),
                                  pw.Text(
                                    presta.uoCount.toStringAsFixed(2),
                                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                                  ),
                                ],
                              ),
                              pw.SizedBox(height: 4),
                              pw.Row(
                                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                children: [
                                  pw.Text(
                                    "Montant maximum HT EUR (non engageant)",
                                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                                  ),
                                  pw.Text(
                                    "${presta.totalHt.toStringAsFixed(2)} €",
                                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 24),

                      // 7. CONDITIONS DE PRESTATION (Mentions légales en petits caractères)
                      pw.Text(
                        "Cette commande ne constitue en aucun cas un engagement ferme. Elle correspond à une prévision de prestation pour la période donnée.\n\n"
                        "Seules les unités d'œuvre (UO) réellement effectuées et validées par l'émission par VIV d'un Rapport de production pourront être facturées forfaitairement par le Prestataire.\n\n"
                        "Les frais de déplacement ne pourront être refacturés que sur présentation de justificatifs et sous réserve de validation par VIV. Ils devront faire l'objet d'une facture dédiée.\n\n"
                        "Toutes vos factures devront être déposées dans notre outil de gestion BoondManager ; dans la rubrique « mes factures » (cf : Livret d'accueil). Les factures sont payables par virement bancaire à trente (30) jours à la date d'émission de la facture, le dix (10) du mois suivant.",
                        style: pw.TextStyle(fontSize: 7.5, fontStyle: pw.FontStyle.italic),
                      ),
                      pw.SizedBox(height: 36),

                      // 8. SIGNATURES (Tableau 2x2 centré sans bordure)
                      pw.Table(
                        border: null,
                        columnWidths: {
                          0: const pw.FlexColumnWidth(1),
                          1: const pw.FlexColumnWidth(1),
                        },
                        children: [
                          pw.TableRow(
                            children: [
                              pw.Container(
                                alignment: pw.Alignment.center,
                                child: pw.Text(
                                  "Le Prestataire :",
                                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                                ),
                              ),
                              pw.Container(
                                alignment: pw.Alignment.center,
                                child: pw.Text(
                                  "VIV :",
                                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                                ),
                              ),
                            ],
                          ),
                          pw.TableRow(
                            children: [
                              pw.Container(
                                alignment: pw.Alignment.center,
                                padding: const pw.EdgeInsets.only(top: 8),
                                child: pw.Text(
                                  "Valant Acceptation de cette commande",
                                  style: pw.TextStyle(fontStyle: pw.FontStyle.italic, fontSize: 9),
                                ),
                              ),
                              pw.Container(
                                alignment: pw.Alignment.center,
                                padding: const pw.EdgeInsets.only(top: 8),
                                child: pw.Container(
                                  width: 140,
                                  height: 50,
                                  decoration: pw.BoxDecoration(
                                    border: pw.Border.all(color: PdfColor.fromHex('#EF4444'), width: 1.5),
                                  ),
                                  alignment: pw.Alignment.center,
                                  child: pw.Text(
                                    "[ Tampon de l'entreprise ]\n[ Confidentiel ]",
                                    textAlign: pw.TextAlign.center,
                                    style: pw.TextStyle(
                                      color: PdfColor.fromHex('#EF4444'),
                                      fontSize: 8,
                                      fontWeight: pw.FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      pw.Spacer(),

                      // 9. PIED DE PAGE (Ligne séparatrice retirée, Infos légales de VIV avec lien email et badge EcoVadis réel)
                      pw.SizedBox(height: 4),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          // Informations Légales
                          pw.Expanded(
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.center,
                              children: [
                                pw.Text(
                                  "VIV",
                                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
                                ),
                                pw.Text(
                                  "Siège Social : 14 rue de Mantes - Immeuble Le Charlebourg - 92700 COLOMBES",
                                  style: pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
                                ),
                                pw.Text(
                                  "SAS au capital de 100 000 euros - RCS NANTERRE - SIREN : 811.694.215 - TVA FR89811694215 - NAF : 7410Z",
                                  style: pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
                                ),
                                pw.SizedBox(height: 2),
                                pw.Row(
                                  mainAxisAlignment: pw.MainAxisAlignment.center,
                                  children: [
                                    pw.Text(
                                      "Tél : +33 (0)1 42 42 46 93 - Email : ",
                                      style: pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
                                    ),
                                    pw.UrlLink(
                                      destination: "mailto:fournisseurs@viv-prod.com",
                                      child: pw.Text(
                                        "fournisseurs@viv-prod.com",
                                        style: pw.TextStyle(
                                          fontSize: 7.5,
                                          color: PdfColors.blue,
                                          decoration: pw.TextDecoration.underline,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // Badge EcoVadis réel
                          if (ecovadisImage != null)
                            pw.Image(ecovadisImage, height: 63, fit: pw.BoxFit.contain)
                          else
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                              decoration: pw.BoxDecoration(
                                border: pw.Border.all(color: PdfColor.fromHex('#D97706'), width: 1.5),
                                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                              ),
                              child: pw.Column(
                                mainAxisSize: pw.MainAxisSize.min,
                                children: [
                                  pw.Text(
                                    "GOLD",
                                    style: pw.TextStyle(
                                      color: PdfColor.fromHex('#D97706'),
                                      fontSize: 10,
                                      fontWeight: pw.FontWeight.bold,
                                    ),
                                  ),
                                  pw.Text(
                                    "ecovadis",
                                    style: pw.TextStyle(
                                      fontSize: 12,
                                      fontWeight: pw.FontWeight.bold,
                                    ),
                                  ),
                                  pw.Text(
                                    "Sustainability\nRating",
                                    textAlign: pw.TextAlign.center,
                                    style: pw.TextStyle(
                                      fontSize: 7,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  // --- COMPOSANTS DE TABLEAU DE HAUTE QUALITÉ ---

  static pw.Widget _buildTableHeaderCell(String text) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      color: PdfColors.grey100,
      alignment: pw.Alignment.center,
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
          fontWeight: pw.FontWeight.bold,
          fontSize: 8.5,
        ),
      ),
    );
  }

  static pw.Widget _buildTableCell(
    String text, {
    String? subtitle,
    bool alignCenter = false,
    bool alignRight = false,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      alignment: alignCenter
          ? pw.Alignment.center
          : (alignRight ? pw.Alignment.centerRight : pw.Alignment.centerLeft),
      child: subtitle != null
          ? pw.RichText(
              textAlign: alignCenter ? pw.TextAlign.center : pw.TextAlign.left,
              text: pw.TextSpan(
                children: [
                  pw.TextSpan(
                    text: text,
                    style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
                  ),
                  pw.TextSpan(
                    text: '   $subtitle',
                    style: pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600, fontWeight: pw.FontWeight.normal),
                  ),
                ],
              ),
            )
          : pw.Text(
              text,
              textAlign: alignCenter ? pw.TextAlign.center : pw.TextAlign.left,
              style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
            ),
    );
  }

  static Future<pw.ImageProvider?> _loadRobustImage(String assetPath) async {
    try {
      Uint8List bytes;
      try {
        // Tenter de charger depuis le bundle d'assets
        final ByteData data = await rootBundle.load(assetPath);
        bytes = data.buffer.asUint8List();
      } catch (_) {
        // Si non trouvé (ex: fichier physique copié mais pas encore packagé), charger en direct du disque local
        final file = File('d:/VIV/Projets/AutomatisationAdmin/dev/opsis_app/$assetPath');
        if (file.existsSync()) {
          bytes = await file.readAsBytes();
        } else {
          final altFile = File(assetPath);
          if (altFile.existsSync()) {
            bytes = await altFile.readAsBytes();
          } else {
            rethrow;
          }
        }
      }
      
      // Décoder en pur CPU (Dart) avec le package image
      final img.Image? decoded = img.decodePng(bytes);
      if (decoded == null) return null;
      
      // Forcer la conversion en RGBA 8 bits
      final img.Image rgbaImage = decoded.convert(numChannels: 4);
      final Uint8List rgbaBytes = rgbaImage.toUint8List();
      
      // Créer le RawImage synchrone pour le PDF
      return pw.RawImage(
        bytes: rgbaBytes,
        width: rgbaImage.width,
        height: rgbaImage.height,
      );
    } catch (e) {
      return null;
    }
  }
}
