import 'package:flutter_test/flutter_test.dart';
import 'package:opsis_app/services/send_rate_limiter.dart';

void main() {
  final t0 = DateTime(2026, 11, 26, 10, 0, 0);

  SendRateLimiter limiter() => SendRateLimiter(limit: 90, window: const Duration(hours: 1), margin: Duration.zero);

  test('autorise les 90 premiers envois sans attente', () {
    final l = limiter();
    for (var i = 0; i < 90; i++) {
      final now = t0.add(Duration(seconds: 6 * i));
      expect(l.waitBeforeNext(now), Duration.zero, reason: 'envoi n° ${i + 1}');
      l.record(now);
    }
  });

  test('bloque le 91e envoi jusqu\'à ce que le plus ancien sorte de la fenêtre', () {
    final l = limiter();
    for (var i = 0; i < 90; i++) {
      l.record(t0.add(Duration(seconds: 6 * i)));
    }
    final now = t0.add(const Duration(minutes: 10));
    expect(l.waitBeforeNext(now), const Duration(minutes: 50));
    expect(l.waitBeforeNext(t0.add(const Duration(hours: 1, seconds: 1))), Duration.zero);
  });

  test('après l\'attente, la cadence reprend au rythme des envois expirés', () {
    final l = limiter();
    for (var i = 0; i < 90; i++) {
      l.record(t0.add(Duration(seconds: 6 * i)));
    }
    final resume = t0.add(const Duration(hours: 1, seconds: 1));
    l.record(resume);
    // Le 2e envoi de la reprise doit attendre que le 2e envoi d'origine (t0 + 6 s) expire
    expect(l.waitBeforeNext(resume), const Duration(seconds: 5));
  });

  test('applique la marge de sécurité', () {
    final l = SendRateLimiter(limit: 2, margin: const Duration(minutes: 2));
    l.record(t0);
    l.record(t0.add(const Duration(minutes: 1)));
    expect(l.waitBeforeNext(t0.add(const Duration(minutes: 5))), const Duration(minutes: 57));
  });

  test("tient compte des envois déjà faits avant l'ouverture de l'app", () {
    final l = limiter()..seed(List.generate(80, (i) => t0.add(Duration(seconds: 10 * i))));
    final now = t0.add(const Duration(minutes: 20));
    expect(l.countInWindow(now), 80);
    for (var i = 0; i < 10; i++) {
      expect(l.waitBeforeNext(now), Duration.zero);
      l.record(now);
    }
    expect(l.waitBeforeNext(now), greaterThan(Duration.zero));
  });

  test("ignore les envois anciens de plus d'une heure", () {
    final l = limiter()..seed(List.generate(200, (_) => t0.subtract(const Duration(hours: 2))));
    expect(l.countInWindow(t0), 0);
    expect(l.waitBeforeNext(t0), Duration.zero);
  });

  test('scénario du 15/10 : 223 BDC, jamais plus de 90 sur une heure glissante', () {
    final l = SendRateLimiter();
    var now = t0;
    final sent = <DateTime>[];
    for (var i = 0; i < 223; i++) {
      now = now.add(l.waitBeforeNext(now));
      l.record(now);
      sent.add(now);
      now = now.add(const Duration(seconds: 6));
    }
    for (final s in sent) {
      final inWindow = sent.where((x) => !x.isBefore(s) && x.isBefore(s.add(const Duration(hours: 1)))).length;
      expect(inWindow, lessThanOrEqualTo(90));
    }
    // 223 BDC partent en trois vagues, sur un peu plus de deux heures
    expect(sent.last.difference(sent.first), lessThan(const Duration(hours: 2, minutes: 30)));
  });
}
