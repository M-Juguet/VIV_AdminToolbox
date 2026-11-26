import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:sembast/sembast.dart';
import 'local_database_service.dart';
import 'bdc_sent_logs_service.dart';
import 'email_service.dart';

/// E-mail du PST portant un BDC en pièce jointe (`VIV-PO-CSOC<prestataire>-<AAMM>.pdf`).
class PstBdcItem {
  final String providerId;
  final String bdcNumber;

  /// Période du BDC au format AAMM, extraite du nom de la pièce jointe (ex. "2608" pour août 2026).
  final String periodCode;
  final String subject;
  final String sender;
  final List<String> recipients;
  final String messageClass;
  final DateTime? date;
  final String folder;

  /// En-tête In-Reply-To : présent sur une réponse, même si son objet n'a pas de préfixe « RE: ».
  final String inReplyTo;

  /// Brouillon jamais envoyé.
  final bool unsent;

  PstBdcItem({
    required this.providerId,
    required this.bdcNumber,
    required this.periodCode,
    required this.subject,
    required this.sender,
    required this.recipients,
    required this.messageClass,
    required this.date,
    required this.folder,
    this.inReplyTo = '',
    this.unsent = false,
  });

  factory PstBdcItem.fromJson(Map<String, dynamic> json) {
    final rawRecipients = json['Recipients'];
    final recipients = <String>[
      if (rawRecipients is List) ...rawRecipients.map((e) => e.toString()),
      if (rawRecipients is String && rawRecipients.isNotEmpty) rawRecipients,
    ];
    return PstBdcItem(
      providerId: json['ProviderId']?.toString() ?? '',
      bdcNumber: json['BdcNumber']?.toString() ?? '',
      periodCode: json['Period']?.toString() ?? '',
      subject: json['Subject']?.toString() ?? '',
      sender: (json['Sender']?.toString() ?? '').trim().toLowerCase(),
      recipients: recipients.map((r) => r.trim().toLowerCase()).where((r) => r.isNotEmpty).toList(),
      messageClass: json['MessageClass']?.toString() ?? '',
      date: parsePstDate(json['Date']?.toString()),
      folder: json['Folder']?.toString() ?? '',
      inReplyTo: json['InReplyTo']?.toString().trim() ?? '',
      unsent: json['Unsent'] == true,
    );
  }
}

/// Résultat brut de l'analyse d'un fichier PST.
class PstScanResult {
  final int scannedItems;
  final int scannedFolders;
  final int deliveryReports;
  final DateTime? oldest;
  final DateTime? newest;
  final List<PstBdcItem> bdcItems;

  /// Premières erreurs de lecture d'e-mails isolés (20 au plus), et leur nombre total.
  final List<String> errors;
  final int itemErrors;

  /// Dossiers dont le contenu n'a pas pu être parcouru : des copies de BDC ont pu être manquées.
  final List<String> folderErrors;

  /// Adresses citées dans les avis de non-remise du PST (en minuscules).
  final Set<String> bouncedAddresses;

  PstScanResult({
    required this.scannedItems,
    required this.scannedFolders,
    required this.deliveryReports,
    required this.oldest,
    required this.newest,
    required this.bdcItems,
    this.errors = const [],
    this.itemErrors = 0,
    this.folderErrors = const [],
    this.bouncedAddresses = const {},
  });

  factory PstScanResult.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final itemMaps = <Map<String, dynamic>>[
      if (rawItems is List) ...rawItems.whereType<Map>().map((e) => Map<String, dynamic>.from(e)),
      if (rawItems is Map) Map<String, dynamic>.from(rawItems),
    ];
    return PstScanResult(
      scannedItems: (json['scanned'] as num?)?.toInt() ?? 0,
      scannedFolders: (json['folders'] as num?)?.toInt() ?? 0,
      deliveryReports: (json['reports'] as num?)?.toInt() ?? 0,
      oldest: parsePstDate(json['oldest']?.toString()),
      newest: parsePstDate(json['newest']?.toString()),
      bdcItems: itemMaps.map(PstBdcItem.fromJson).toList(),
      errors: _stringList(json['errors']),
      itemErrors: (json['itemErrors'] as num?)?.toInt() ?? 0,
      folderErrors: _stringList(json['folderErrors']),
      bouncedAddresses: _stringList(json['bounced']).map((a) => a.trim().toLowerCase()).toSet(),
    );
  }

  static List<String> _stringList(dynamic raw) => [
        if (raw is List) ...raw.map((e) => e.toString()),
        if (raw is String && raw.isNotEmpty) raw,
      ];
}

DateTime? parsePstDate(String? value) {
  if (value == null || value.isEmpty) return null;
  return DateTime.tryParse(value.replaceFirst(' ', 'T'));
}

/// État d'un BDC de la base locale après croisement avec le PST.
enum ReconciliationStatus {
  /// La copie cachée envoyée par la boîte fournisseurs est présente dans le PST.
  confirmed,

  /// Le PST couvre la date d'envoi mais ne contient pas la copie : le BDC n'est pas parti.
  missing,

  /// Le PST ne couvre pas la date d'envoi : impossible de conclure, le BDC n'est pas réinitialisé.
  unverifiable,
}

class ReconciliationEntry {
  final String providerId;
  final String? bdcNumber;
  final String? consultantName;
  final String? clientName;
  final String? sentToEmail;
  final double? uoCount;
  final double? totalHt;
  final DateTime? sentAt;
  final ReconciliationStatus status;
  final DateTime? copyDate;

  /// Destinataires de la copie trouvée, quand ils diffèrent de l'adresse enregistrée en base.
  final List<String> mismatchedRecipients;

  /// L'adresse enregistrée figure dans un avis de non-remise du PST : le fournisseur n'a pas reçu le BDC,
  /// et le renvoyer à la même adresse échouera. L'adresse est à corriger dans Boond.
  final bool isBounced;

  /// Explication d'un statut « non vérifiable ».
  final String? note;

  ReconciliationEntry({
    required this.providerId,
    this.bdcNumber,
    this.consultantName,
    this.clientName,
    this.sentToEmail,
    this.uoCount,
    this.totalHt,
    this.sentAt,
    required this.status,
    this.copyDate,
    this.mismatchedRecipients = const [],
    this.isBounced = false,
    this.note,
  });

  bool get isConfirmedInPst => status == ReconciliationStatus.confirmed;
  bool get hasRecipientMismatch => mismatchedRecipients.isNotEmpty;
}

/// Copie de BDC de la période trouvée dans le PST sans enregistrement correspondant en base locale
/// (envoi fait depuis un autre poste, ou base effacée).
class OrphanCopy {
  final String providerId;
  final String bdcNumber;
  final DateTime? date;
  final List<String> recipients;

  OrphanCopy({
    required this.providerId,
    required this.bdcNumber,
    required this.date,
    required this.recipients,
  });
}

class BdcReconciliationReport {
  final String period;
  final String periodCode;
  final String pstPath;
  final String expectedSender;
  final PstScanResult scan;
  final List<ReconciliationEntry> entries;
  final List<OrphanCopy> orphans;

  /// Copies valides (expéditeur fournisseurs, hors réponses et transferts) trouvées pour la période.
  final int validCopiesForPeriod;
  final int ignoredRepliesOrForwards;
  final int ignoredOtherSenders;
  final int ignoredOtherClasses;
  final int otherPeriodItems;

  /// Raison pour laquelle la réinitialisation est interdite, ou null si elle est autorisée.
  final String? resetBlockedReason;

  BdcReconciliationReport({
    required this.period,
    required this.periodCode,
    required this.pstPath,
    required this.expectedSender,
    required this.scan,
    required this.entries,
    required this.orphans,
    required this.validCopiesForPeriod,
    required this.ignoredRepliesOrForwards,
    required this.ignoredOtherSenders,
    required this.ignoredOtherClasses,
    required this.otherPeriodItems,
    required this.resetBlockedReason,
  });

  int get totalInDatabase => entries.length;
  int get confirmedCount => _count(ReconciliationStatus.confirmed);
  int get missingCount => _count(ReconciliationStatus.missing);
  int get unverifiableCount => _count(ReconciliationStatus.unverifiable);
  int get recipientMismatchCount => entries.where((e) => e.hasRecipientMismatch).length;
  int get bouncedCount => entries.where((e) => e.isBounced).length;
  bool get canReset => resetBlockedReason == null && missingCount > 0;

  Set<String> get confirmedProviderIds => _ids(ReconciliationStatus.confirmed);
  Set<String> get missingProviderIds => _ids(ReconciliationStatus.missing);

  int _count(ReconciliationStatus s) => entries.where((e) => e.status == s).length;
  Set<String> _ids(ReconciliationStatus s) =>
      entries.where((e) => e.status == s).map((e) => e.providerId).toSet();
}

final RegExp _replyOrForwardPrefix = RegExp(
  r'^\s*((re|tr|fw|fwd|aw|wg|ref|réf|rv)\s*(\[\d+\])?|réponse automatique|automatic reply|auto[- ]?reply|out of office)\s*:',
  caseSensitive: false,
);

bool isReplyOrForward(String subject) => _replyOrForwardPrefix.hasMatch(subject);

/// Convertit une période "MM/AAAA" en code AAMM utilisé dans le nom des BDC (ex. "08/2026" -> "2608").
String periodToCode(String period) {
  final parts = period.split('/');
  if (parts.length != 2 || parts[0].length != 2 || parts[1].length != 4) {
    throw ArgumentError('Période invalide : $period (format attendu MM/AAAA)');
  }
  return '${parts[1].substring(2)}${parts[0]}';
}

/// Croise les journaux d'envoi d'une période avec le résultat d'analyse d'un PST.
///
/// Un BDC n'est confirmé que par la copie cachée d'origine, c'est-à-dire un e-mail qui remplit **toutes** ces
/// conditions : pièce jointe du même prestataire et de la **même période** ; message standard et réellement envoyé
/// (ni avis de non-remise, ni brouillon) ; ni réponse, ni transfert, ni réponse automatique (préfixe d'objet ou
/// en-tête In-Reply-To) ; expéditeur [expectedSender] ; adressé à l'adresse enregistrée en base.
/// Un BDC n'est déclaré manquant que si le PST couvre sa date d'envoi. Tout cas douteux est « non vérifiable »
/// et n'est jamais réinitialisé automatiquement.
BdcReconciliationReport buildReconciliationReport({
  required String period,
  required String pstPath,
  required List<Map<String, dynamic>> logs,
  required PstScanResult scan,
  String expectedSender = EmailService.defaultSenderEmail,
}) {
  final code = periodToCode(period);
  final sender = expectedSender.trim().toLowerCase();

  final validCopies = <String, List<PstBdcItem>>{};
  var ignoredReplies = 0;
  var ignoredSenders = 0;
  var ignoredClasses = 0;
  var otherPeriods = 0;

  for (final item in scan.bdcItems) {
    if (item.periodCode != code) {
      otherPeriods++;
    } else if (!item.messageClass.toUpperCase().startsWith('IPM.NOTE') || item.unsent) {
      ignoredClasses++;
    } else if (isReplyOrForward(item.subject) || item.inReplyTo.isNotEmpty) {
      ignoredReplies++;
    } else if (item.sender != sender) {
      ignoredSenders++;
    } else {
      validCopies.putIfAbsent(item.providerId, () => []).add(item);
    }
  }

  final periodLogs = logs.where((l) => l['period'] == period).toList();
  final entries = <ReconciliationEntry>[];

  for (final log in periodLogs) {
    final providerId = log['providerId']?.toString() ?? '';
    final sentTo = (log['sentToEmail']?.toString() ?? '').trim().toLowerCase();
    final sentAt = DateTime.tryParse(log['sentAt']?.toString() ?? '');
    final copies = validCopies[providerId] ?? const <PstBdcItem>[];

    ReconciliationStatus status;
    DateTime? copyDate;
    String? note;
    var mismatched = <String>[];

    DateTime? latest(List<PstBdcItem> items) => items
        .map((c) => c.date)
        .whereType<DateTime>()
        .fold<DateTime?>(null, (a, b) => a == null || b.isAfter(a) ? b : a);

    final matching = copies.where((c) => sentTo.isEmpty || c.recipients.contains(sentTo)).toList();
    if (matching.isNotEmpty) {
      status = ReconciliationStatus.confirmed;
      copyDate = latest(matching);
    } else if (copies.isNotEmpty) {
      // Une copie existe, mais pas à l'adresse enregistrée : on ne peut pas affirmer que le fournisseur l'a reçue.
      status = ReconciliationStatus.unverifiable;
      copyDate = latest(copies);
      mismatched = copies.expand((c) => c.recipients).toSet().toList();
      note = mismatched.isEmpty
          ? "Copie trouvée, mais ses destinataires n'ont pas pu être lus."
          : "Copie trouvée, mais adressée à : ${mismatched.join(', ')}.";
    } else if (_isCoveredByScan(sentAt, scan)) {
      status = ReconciliationStatus.missing;
    } else {
      status = ReconciliationStatus.unverifiable;
      note = "L'envoi est en dehors des dates couvertes par le PST.";
    }

    entries.add(ReconciliationEntry(
      providerId: providerId,
      bdcNumber: log['bdcNumber']?.toString(),
      consultantName: log['consultantName']?.toString(),
      clientName: log['clientName']?.toString(),
      sentToEmail: log['sentToEmail']?.toString(),
      uoCount: (log['uoCount'] as num?)?.toDouble(),
      totalHt: (log['totalHt'] as num?)?.toDouble(),
      sentAt: sentAt,
      status: status,
      copyDate: copyDate,
      mismatchedRecipients: mismatched,
      isBounced: sentTo.isNotEmpty && scan.bouncedAddresses.contains(sentTo),
      note: note,
    ));
  }

  final loggedIds = periodLogs.map((l) => l['providerId']?.toString() ?? '').toSet();
  final orphans = validCopies.entries
      .where((e) => !loggedIds.contains(e.key))
      .map((e) => OrphanCopy(
            providerId: e.key,
            bdcNumber: e.value.first.bdcNumber,
            date: e.value.first.date,
            recipients: e.value.first.recipients,
          ))
      .toList()
    ..sort((a, b) => a.providerId.compareTo(b.providerId));

  String? blocked;
  if (scan.scannedItems == 0) {
    blocked = "Le PST n'a renvoyé aucun e-mail : l'analyse n'a pas pu lire son contenu.";
  } else if (scan.folderErrors.isNotEmpty) {
    blocked = "${scan.folderErrors.length} dossier(s) du PST n'ont pas pu être parcourus : "
        "des copies de BDC ont pu échapper à l'analyse.";
  } else if (periodLogs.isNotEmpty && validCopies.isEmpty) {
    blocked = "Aucune copie de BDC envoyée par $expectedSender pour la période $period n'a été trouvée dans le PST. "
        "Vérifiez que l'export provient bien de cette boîte et couvre les dates d'envoi.";
  }

  return BdcReconciliationReport(
    period: period,
    periodCode: code,
    pstPath: pstPath,
    expectedSender: expectedSender,
    scan: scan,
    entries: entries,
    orphans: orphans,
    validCopiesForPeriod: validCopies.values.fold(0, (sum, l) => sum + l.length),
    ignoredRepliesOrForwards: ignoredReplies,
    ignoredOtherSenders: ignoredSenders,
    ignoredOtherClasses: ignoredClasses,
    otherPeriodItems: otherPeriods,
    resetBlockedReason: blocked,
  );
}

/// Le PST couvre l'envoi s'il contient des e-mails antérieurs (à un jour près) et postérieurs à la date d'envoi.
bool _isCoveredByScan(DateTime? sentAt, PstScanResult scan) {
  if (sentAt == null || scan.oldest == null || scan.newest == null) return false;
  final startsBefore = !scan.oldest!.isAfter(sentAt.add(const Duration(days: 1)));
  final endsAfter = !scan.newest!.isBefore(sentAt);
  return startsBefore && endsAfter;
}

/// Encode un script pour `powershell.exe -EncodedCommand` (UTF-16LE puis base64).
String encodePowerShellCommand(String script) {
  final bytes = BytesBuilder();
  for (final unit in script.codeUnits) {
    bytes.addByte(unit & 0xFF);
    bytes.addByte(unit >> 8);
  }
  return base64Encode(bytes.takeBytes());
}

/// Script d'analyse du PST via Outlook (COM). Le chemin du PST est transmis par la variable
/// d'environnement BDC_PST_PATH. Codes de sortie : 2 = Outlook indisponible, 3 = PST non ouvert,
/// 4 = erreur pendant l'analyse.
const String _pstScanScript = r'''
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$pstPath = $env:BDC_PST_PATH

try {
    $outlook = New-Object -ComObject Outlook.Application
} catch {
    [Console]::Error.WriteLine("OUTLOOK_UNAVAILABLE: " + $_.Exception.Message)
    exit 2
}

$ns = $outlook.GetNamespace('MAPI')
try {
    $ns.AddStore($pstPath)
} catch {
    [Console]::Error.WriteLine("PST_NOT_OPENED: " + $_.Exception.Message)
    exit 3
}

$store = $null
foreach ($s in $ns.Stores) {
    try { if ($s.FilePath -and ($s.FilePath -ieq $pstPath)) { $store = $s; break } } catch {}
}
if (-not $store) {
    [Console]::Error.WriteLine("PST_NOT_OPENED: magasin introuvable apres ouverture")
    exit 3
}

$script:scanned = 0
$script:folders = 0
$script:reports = 0
$script:oldest = $null
$script:newest = $null
$script:items = New-Object System.Collections.ArrayList
$script:errors = New-Object System.Collections.ArrayList
$script:folderErrors = New-Object System.Collections.ArrayList
$script:itemErrors = 0
$script:bounced = New-Object 'System.Collections.Generic.HashSet[string]'
$bdcRegex = New-Object System.Text.RegularExpressions.Regex('VIV-PO-CSOC(\d+)-(\d{4})\.pdf$', 'IgnoreCase')
$emailRegex = New-Object System.Text.RegularExpressions.Regex('[\w.+-]+@[\w-]+(\.[\w-]+)+')
$bounceSubjectRegex = '^\s*(undeliverable|undelivered|non remis|returned mail|delivery status notification|mail delivery (failed|failure)|failure notice|échec de (la )?remise)'

function Get-ItemDate($item) {
    foreach ($prop in @('ReceivedTime', 'SentOn', 'CreationTime')) {
        try {
            $d = $item.$prop
            if ($d -and $d.Year -gt 1990 -and $d.Year -lt 4000) { return $d }
        } catch {}
    }
    return $null
}

function Get-SmtpAddress($entry, $fallback) {
    try {
        if ($entry -and $entry.Type -eq 'EX') {
            $user = $entry.GetExchangeUser()
            if ($user -and $user.PrimarySmtpAddress) { return [string]$user.PrimarySmtpAddress }
        }
    } catch {}
    return [string]$fallback
}

function Scan-Folder($folder) {
    $script:folders++
    $folderPath = ''
    try { $folderPath = [string]$folder.FolderPath } catch {}
    try { Scan-Items $folder $folderPath } catch {
        [void]$script:folderErrors.Add($folderPath + ' : ' + $_.Exception.Message)
    }
    try {
        # PowerShell renvoie $null au lieu de lever une erreur quand une propriété est illisible.
        $subFolders = $folder.Folders
        if ($null -eq $subFolders) { throw 'liste des sous-dossiers illisible' }
        foreach ($sub in $subFolders) { Scan-Folder $sub }
    } catch {
        [void]$script:folderErrors.Add($folderPath + ' (sous-dossiers) : ' + $_.Exception.Message)
    }
}

function Scan-Items($folder, $folderPath) {
    $folderItems = $folder.Items
    if ($null -eq $folderItems) { throw 'contenu du dossier illisible' }
    foreach ($item in $folderItems) {
        try {
            $script:scanned++
            $class = [string]$item.MessageClass
            $date = Get-ItemDate $item
            if ($date) {
                if (-not $script:oldest -or $date -lt $script:oldest) { $script:oldest = $date }
                if (-not $script:newest -or $date -gt $script:newest) { $script:newest = $date }
            }
            $subject = ''
            try { $subject = [string]$item.Subject } catch {}
            # Avis de non-remise : classe REPORT.*, ou message ordinaire envoyé par un serveur (MAILER-DAEMON…)
            if ($class -like 'REPORT.*' -or $subject -match $bounceSubjectRegex) {
                $script:reports++
                # Relever les adresses citées pour signaler les BDC rejetés ; ce message ne confirme jamais rien
                try {
                    foreach ($mm in $emailRegex.Matches([string]$item.Body)) {
                        [void]$script:bounced.Add($mm.Value.ToLower())
                    }
                } catch {}
                continue
            }

            $attachments = $null
            try { $attachments = $item.Attachments } catch {}
            if (-not $attachments -or $attachments.Count -eq 0) { continue }

            foreach ($att in $attachments) {
                $m = $bdcRegex.Match([string]$att.FileName)
                if (-not $m.Success) { continue }

                $sender = ''
                try {
                    $sender = [string]$item.SenderEmailAddress
                    if ($item.SenderEmailType -eq 'EX') { $sender = Get-SmtpAddress $item.Sender $sender }
                } catch {}

                $recipients = New-Object System.Collections.ArrayList
                try {
                    foreach ($r in $item.Recipients) {
                        $address = Get-SmtpAddress $r.AddressEntry $r.Address
                        if ($address) { [void]$recipients.Add($address) }
                    }
                } catch {}

                # Une réponse sans préfixe « RE: » se reconnaît à son en-tête In-Reply-To
                $inReplyTo = ''
                try {
                    $headers = [string]$item.PropertyAccessor.GetProperty('http://schemas.microsoft.com/mapi/proptag/0x007D001F')
                    $hm = [regex]::Match($headers, '(?im)^In-Reply-To:[ \t]*(\S.*)$')
                    if ($hm.Success) { $inReplyTo = $hm.Groups[1].Value.Trim() }
                } catch {}

                # Brouillon jamais envoyé : seulement si Outlook l'indique explicitement (propriété illisible = envoyé)
                $unsent = $false
                try { if ($item.Sent -eq $false) { $unsent = $true } } catch {}

                [void]$script:items.Add([ordered]@{
                    ProviderId   = $m.Groups[1].Value
                    BdcNumber    = 'VIV-PO-CSOC' + $m.Groups[1].Value + '-' + $m.Groups[2].Value
                    Period       = $m.Groups[2].Value
                    Subject      = $subject
                    Sender       = $sender
                    Recipients   = @($recipients)
                    MessageClass = $class
                    Date         = if ($date) { $date.ToString('yyyy-MM-dd HH:mm:ss') } else { '' }
                    Folder       = $folderPath
                    InReplyTo    = $inReplyTo
                    Unsent       = $unsent
                })
                break
            }
        } catch {
            $script:itemErrors++
            if ($script:errors.Count -lt 20) { [void]$script:errors.Add($folderPath + ' : ' + $_.Exception.Message) }
        }
    }
}

$root = $null
try {
    $root = $store.GetRootFolder()
    Scan-Folder $root
} catch {
    [Console]::Error.WriteLine("SCAN_FAILED: " + $_.Exception.Message)
    exit 4
} finally {
    try { if ($root) { $ns.RemoveStore($root) } } catch {}
}

$result = [ordered]@{
    scanned = $script:scanned
    folders = $script:folders
    reports = $script:reports
    oldest  = if ($script:oldest) { $script:oldest.ToString('yyyy-MM-dd HH:mm:ss') } else { '' }
    newest  = if ($script:newest) { $script:newest.ToString('yyyy-MM-dd HH:mm:ss') } else { '' }
    items   = @($script:items)
    errors  = @($script:errors)
    itemErrors   = $script:itemErrors
    folderErrors = @($script:folderErrors)
    bounced      = @($script:bounced)
}
ConvertTo-Json -InputObject $result -Depth 6 -Compress
''';

class BdcReconciliationService {
  final LocalDatabaseService _dbService = LocalDatabaseService();
  final _store = stringMapStoreFactory.store('bdc_sent_logs');

  /// Analyse un fichier PST via Outlook et renvoie les e-mails portant un BDC, avec la couverture du fichier.
  Future<PstScanResult> scanPstFile(String pstPath) async {
    if (!File(pstPath).existsSync()) {
      throw 'Le fichier PST spécifié n\'existe pas : $pstPath';
    }

    final ProcessResult result;
    try {
      // Script transmis encodé (UTF-16LE en base64) : aucun risque que les guillemets soient altérés
      // par la ligne de commande Windows.
      result = await Process.run(
        'powershell.exe',
        ['-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-EncodedCommand', encodePowerShellCommand(_pstScanScript)],
        environment: {'BDC_PST_PATH': File(pstPath).absolute.path},
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );
    } catch (e) {
      throw 'Impossible de lancer PowerShell pour analyser le PST : $e';
    }

    // Retirer le bruit technique éventuel de PowerShell (flux sérialisés en CLIXML).
    final stderr = (result.stderr as String)
        .split(RegExp(r'\r?\n'))
        .where((l) => !l.startsWith('#< CLIXML') && !l.startsWith('<Objs'))
        .join('\n')
        .trim();
    switch (result.exitCode) {
      case 0:
        break;
      case 2:
        throw 'Outlook est introuvable ou ne répond pas. L\'analyse nécessite Outlook classique '
            '(le « nouvel Outlook » ne permet pas l\'automatisation). Détail : $stderr';
      case 3:
        throw 'Outlook n\'a pas pu ouvrir le fichier PST. Vérifiez qu\'il n\'est pas déjà ouvert '
            'ailleurs ou corrompu. Détail : $stderr';
      default:
        throw 'L\'analyse du PST a échoué (code ${result.exitCode}). Détail : $stderr';
    }

    final raw = (result.stdout as String).trim();
    final jsonStart = raw.indexOf('{');
    if (jsonStart < 0) {
      throw 'Réponse inattendue de l\'analyse du PST : ${raw.isEmpty ? '(vide)' : raw}';
    }

    try {
      final decoded = jsonDecode(raw.substring(jsonStart));
      return PstScanResult.fromJson(Map<String, dynamic>.from(decoded as Map));
    } catch (e) {
      debugPrint('Erreur de décodage du PST : $e');
      throw 'Réponse illisible de l\'analyse du PST : $e';
    }
  }

  /// Analyse le PST puis croise le résultat avec la base locale pour la période.
  Future<BdcReconciliationReport> reconcileWithDatabase({
    required String pstPath,
    required String period, // ex: "09/2026"
  }) async {
    final scan = await scanPstFile(pstPath);
    return reconcileWithScan(scan: scan, pstPath: pstPath, period: period);
  }

  /// Croise une analyse PST déjà faite avec l'état actuel de la base locale (sans relire le PST).
  Future<BdcReconciliationReport> reconcileWithScan({
    required PstScanResult scan,
    required String pstPath,
    required String period,
  }) async {
    final logs = await BdcSentLogsService().getAllSentLogs();
    return buildReconciliationReport(
      period: period,
      pstPath: pstPath,
      logs: logs,
      scan: scan,
    );
  }

  /// Supprime de Sembast uniquement les enregistrements déclarés manquants (et leur PDF archivé).
  Future<int> deleteMissingLogs({
    required String period,
    required Set<String> missingProviderIds,
  }) async {
    final db = await _dbService.database;
    int deletedCount = 0;

    for (var pId in missingProviderIds) {
      final id = '${pId}_${period.replaceAll('/', '_')}';
      final record = _store.record(id);
      final exists = await record.exists(db);
      if (exists) {
        final val = await record.get(db);
        final pdfPath = val?['pdfPath'] as String?;
        if (pdfPath != null) {
          final f = File(pdfPath);
          if (f.existsSync()) {
            try {
              f.deleteSync();
            } catch (_) {}
          }
        }
        await record.delete(db);
        deletedCount++;
      }
    }

    return deletedCount;
  }
}
