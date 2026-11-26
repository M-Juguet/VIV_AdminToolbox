import 'package:flutter_test/flutter_test.dart';
import 'package:opsis_app/services/bdc_reconciliation_service.dart';

const _sender = 'fournisseurs@viv-prod.com';

PstBdcItem _copy(
  String providerId,
  String periodCode, {
  String subject = 'Votre bon de commande_Août 2026',
  String sender = _sender,
  List<String> recipients = const ['contact@presta.fr'],
  String messageClass = 'IPM.Note',
  String date = '2026-08-03 09:00:00',
  String inReplyTo = '',
  bool unsent = false,
}) {
  return PstBdcItem(
    providerId: providerId,
    bdcNumber: 'VIV-PO-CSOC$providerId-$periodCode',
    periodCode: periodCode,
    subject: subject,
    sender: sender,
    recipients: recipients,
    messageClass: messageClass,
    date: parsePstDate(date),
    folder: r'\\Fournisseurs\Boîte de réception',
    inReplyTo: inReplyTo,
    unsent: unsent,
  );
}

Map<String, dynamic> _log(
  String providerId, {
  String period = '08/2026',
  String sentTo = 'contact@presta.fr',
  String sentAt = '2026-08-03T08:59:00.000',
}) {
  return {
    'providerId': providerId,
    'period': period,
    'sentToEmail': sentTo,
    'sentAt': sentAt,
    'bdcNumber': 'VIV-PO-CSOC$providerId-2608',
  };
}

PstScanResult _scan(
  List<PstBdcItem> items, {
  String oldest = '2026-07-01 00:00:00',
  String newest = '2026-09-15 00:00:00',
  List<String> folderErrors = const [],
  int scanned = 500,
}) {
  return PstScanResult(
    scannedItems: scanned,
    scannedFolders: 5,
    deliveryReports: 0,
    oldest: parsePstDate(oldest),
    newest: parsePstDate(newest),
    bdcItems: items,
    folderErrors: folderErrors,
  );
}

BdcReconciliationReport _report(List<Map<String, dynamic>> logs, PstScanResult scan) =>
    buildReconciliationReport(period: '08/2026', pstPath: 'test.pst', logs: logs, scan: scan);

ReconciliationEntry _entry(BdcReconciliationReport r, String providerId) =>
    r.entries.firstWhere((e) => e.providerId == providerId);

void main() {
  group('Utilitaires', () {
    test('periodToCode convertit MM/AAAA en AAMM', () {
      expect(periodToCode('08/2026'), '2608');
      expect(periodToCode('12/2025'), '2512');
      expect(() => periodToCode('8/2026'), throwsArgumentError);
    });

    test('isReplyOrForward reconnaît les préfixes courants', () {
      for (final s in [
        'RE: x',
        'Re : x',
        'TR: x',
        'Fwd: x',
        'FW: x',
        'RE[2]: x',
        'AW: x',
        'Réponse automatique : x',
        'Automatic reply: x',
      ]) {
        expect(isReplyOrForward(s), isTrue, reason: s);
      }
      expect(isReplyOrForward('Votre bon de commande_Août 2026'), isFalse);
    });
  });

  group('Rapprochement prestataire + période', () {
    test('une copie valide de la période confirme le BDC', () {
      final r = _report([_log('101')], _scan([_copy('101', '2608')]));
      expect(_entry(r, '101').status, ReconciliationStatus.confirmed);
      expect(r.missingCount, 0);
    });

    test("un BDC du même prestataire mais d'un autre mois ne confirme PAS la période (bug corrigé)", () {
      final r = _report([_log('101')], _scan([_copy('101', '2607', subject: 'Votre bon de commande_Juillet 2026')]));
      expect(_entry(r, '101').status, ReconciliationStatus.missing);
      expect(r.otherPeriodItems, 1);
    });

    test('une réponse ou un transfert du fournisseur ne confirme pas', () {
      final r = _report(
        [_log('101'), _log('102')],
        _scan([
          _copy('101', '2608', subject: 'RE: Votre bon de commande_Août 2026', sender: 'contact@presta.fr'),
          _copy('102', '2608', subject: 'TR: Votre bon de commande_Août 2026'),
          _copy('103', '2608'),
        ]),
      );
      expect(_entry(r, '101').status, ReconciliationStatus.missing);
      expect(_entry(r, '102').status, ReconciliationStatus.missing);
      expect(r.ignoredRepliesOrForwards, 2);
    });

    test("un e-mail d'un autre expéditeur ne confirme pas", () {
      final r = _report([_log('101')], _scan([_copy('101', '2608', sender: 'autre@viv-prod.com'), _copy('999', '2608')]));
      expect(_entry(r, '101').status, ReconciliationStatus.missing);
      expect(r.ignoredOtherSenders, 1);
    });

    test('un avis de non-remise ne confirme pas', () {
      final r = _report([_log('101')], _scan([_copy('101', '2608', messageClass: 'REPORT.IPM.Note.NDR'), _copy('999', '2608')]));
      expect(_entry(r, '101').status, ReconciliationStatus.missing);
      expect(r.ignoredOtherClasses, 1);
    });

    test("une copie adressée à une autre adresse ne confirme pas : non vérifiable, jamais réinitialisé", () {
      final r = _report(
        [_log('101', sentTo: 'contact@presta.fr'), _log('102')],
        _scan([_copy('101', '2608', recipients: ['collegue@viv-prod.com']), _copy('102', '2608')]),
      );
      final e = _entry(r, '101');
      expect(e.status, ReconciliationStatus.unverifiable);
      expect(e.mismatchedRecipients, ['collegue@viv-prod.com']);
      expect(e.note, contains('collegue@viv-prod.com'));
      expect(r.missingProviderIds, isNot(contains('101')));
    });

    test("une copie à la bonne adresse suffit, même s'il existe aussi une copie interne", () {
      final r = _report(
        [_log('101')],
        _scan([_copy('101', '2608', recipients: ['collegue@viv-prod.com']), _copy('101', '2608')]),
      );
      expect(_entry(r, '101').status, ReconciliationStatus.confirmed);
    });

    test("une réponse sans préfixe « RE: » (en-tête In-Reply-To) ne confirme pas", () {
      final r = _report(
        [_log('101')],
        _scan([_copy('101', '2608', inReplyTo: '<abc@viv-prod.com>'), _copy('999', '2608')]),
      );
      expect(_entry(r, '101').status, ReconciliationStatus.missing);
    });

    test('un brouillon jamais envoyé ne confirme pas', () {
      final r = _report([_log('101')], _scan([_copy('101', '2608', unsent: true), _copy('999', '2608')]));
      expect(_entry(r, '101').status, ReconciliationStatus.missing);
    });

    test("une réponse automatique reprenant l'objet ne confirme pas", () {
      final r = _report(
        [_log('101')],
        _scan([
          _copy('101', '2608', subject: 'Réponse automatique : Votre bon de commande_Août 2026'),
          _copy('999', '2608'),
        ]),
      );
      expect(_entry(r, '101').status, ReconciliationStatus.missing);
    });

    test("un e-mail d'un fournisseur reprenant exactement l'objet d'origine ne confirme pas", () {
      final r = _report(
        [_log('101')],
        _scan([_copy('101', '2608', sender: 'contact@presta.fr', recipients: [_sender]), _copy('999', '2608')]),
      );
      expect(_entry(r, '101').status, ReconciliationStatus.missing);
    });

    test('signale un BDC dont l\'adresse figure dans un avis de non-remise', () {
      final scan = PstScanResult(
        scannedItems: 10,
        scannedFolders: 1,
        deliveryReports: 1,
        oldest: parsePstDate('2026-07-01 00:00:00'),
        newest: parsePstDate('2026-09-15 00:00:00'),
        bdcItems: [_copy('101', '2608'), _copy('102', '2608', recipients: ['bon@presta.fr'])],
        bouncedAddresses: {'contact@presta.fr', 'postmaster@ovh.net'},
      );
      final r = _report([_log('101'), _log('102', sentTo: 'bon@presta.fr')], scan);
      expect(_entry(r, '101').isBounced, isTrue);
      expect(_entry(r, '102').isBounced, isFalse);
      expect(r.bouncedCount, 1);
    });

    test('les journaux des autres périodes sont ignorés', () {
      final r = _report([_log('101'), _log('101', period: '07/2026')], _scan([_copy('101', '2608')]));
      expect(r.totalInDatabase, 1);
    });

    test('liste les copies de la période absentes de la base locale', () {
      final r = _report([_log('101')], _scan([_copy('101', '2608'), _copy('205', '2608')]));
      expect(r.orphans.map((o) => o.providerId), ['205']);
    });
  });

  group('Couverture du PST', () {
    test("un envoi postérieur au dernier e-mail du PST n'est pas vérifiable", () {
      final r = _report(
        [_log('101'), _log('150', sentAt: '2026-08-03T10:30:00.000')],
        _scan([_copy('101', '2608')], newest: '2026-08-03 09:00:00'),
      );
      expect(_entry(r, '150').status, ReconciliationStatus.unverifiable);
      expect(r.missingProviderIds, isEmpty);
    });

    test("un envoi antérieur au premier e-mail du PST n'est pas vérifiable", () {
      final r = _report(
        [_log('101'), _log('150', sentAt: '2026-06-20T10:00:00.000')],
        _scan([_copy('101', '2608')], oldest: '2026-07-01 00:00:00'),
      );
      expect(_entry(r, '150').status, ReconciliationStatus.unverifiable);
    });
  });

  group('Garde-fous de réinitialisation', () {
    test('autorise la réinitialisation dans le cas nominal', () {
      final r = _report([_log('101'), _log('102')], _scan([_copy('101', '2608')]));
      expect(r.missingProviderIds, {'102'});
      expect(r.canReset, isTrue);
    });

    test('bloque si aucune copie de la période n\'est trouvée', () {
      final r = _report([_log('101'), _log('102')], _scan([_copy('101', '2607')]));
      expect(r.missingCount, 2);
      expect(r.canReset, isFalse);
      expect(r.resetBlockedReason, isNotNull);
    });

    test('bloque si un dossier du PST est illisible', () {
      final r = _report([_log('101'), _log('102')], _scan([_copy('101', '2608')], folderErrors: ['Corrompu : illisible']));
      expect(r.canReset, isFalse);
    });

    test('bloque si le PST est vide', () {
      final r = _report([_log('101')], _scan([], scanned: 0));
      expect(r.canReset, isFalse);
    });
  });

  group('Lecture du résultat PowerShell', () {
    test('accepte un élément unique et des destinataires sous forme de texte', () {
      final scan = PstScanResult.fromJson({
        'scanned': 3,
        'folders': 1,
        'reports': 0,
        'oldest': '2026-08-01 08:00:00',
        'newest': '2026-08-05 08:00:00',
        'items': {
          'ProviderId': '101',
          'BdcNumber': 'VIV-PO-CSOC101-2608',
          'Period': '2608',
          'Subject': 'Votre bon de commande_Août 2026',
          'Sender': 'Fournisseurs@VIV-prod.com',
          'Recipients': 'Contact@Presta.fr',
          'MessageClass': 'IPM.Note',
          'Date': '2026-08-03 09:00:00',
          'Folder': 'Boîte de réception',
        },
        'errors': [],
        'itemErrors': 0,
        'folderErrors': [],
      });
      expect(scan.bdcItems, hasLength(1));
      expect(scan.bdcItems.first.sender, 'fournisseurs@viv-prod.com');
      expect(scan.bdcItems.first.recipients, ['contact@presta.fr']);
      expect(scan.newest, DateTime(2026, 8, 5, 8));
    });
  });
}
