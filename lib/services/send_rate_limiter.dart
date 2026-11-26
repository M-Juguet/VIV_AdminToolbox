/// Plafond d'envois sur une fenêtre glissante, pour rester sous le quota horaire de la boîte d'envoi.
///
/// Constat du 25/11/2026 sur la boîte OVH `fournisseurs@` : chaque lot s'est arrêté à 101 e-mails, les suivants
/// étant perdus sans aucune erreur SMTP. Le plafond est réglable dans l'app (70 par défaut) pour garder de la marge.
/// Les envois faits par d'autres outils sur la même boîte (RP de n8n, autres postes) ne sont pas comptés ici.
class SendRateLimiter {
  /// Nombre maximal d'envois sur la fenêtre. Modifiable entre deux lots (réglage de l'app), sans perdre l'historique.
  int limit;
  final Duration window;

  /// Délai ajouté à l'expiration d'un envoi, pour ne pas reprendre pile à la limite de la fenêtre du serveur.
  final Duration margin;

  final List<DateTime> _attempts = [];

  SendRateLimiter({
    this.limit = 90,
    this.window = const Duration(hours: 1),
    this.margin = const Duration(minutes: 2),
  }) : assert(limit > 0);

  /// Reprend les envois déjà faits (par exemple depuis l'historique local), pour qu'un redémarrage de l'app
  /// ne remette pas le compteur à zéro.
  void seed(Iterable<DateTime> pastAttempts) => _attempts.addAll(pastAttempts);

  /// Enregistre une tentative d'envoi. Toute tentative compte, réussie ou non, par prudence.
  void record(DateTime at) => _attempts.add(at);

  /// Nombre d'envois comptés dans la fenêtre qui se termine à [now].
  int countInWindow(DateTime now) {
    _purge(now);
    return _attempts.length;
  }

  /// Durée à attendre avant de pouvoir envoyer à [now] sans dépasser le plafond (zéro si l'envoi est possible).
  Duration waitBeforeNext(DateTime now) {
    _purge(now);
    if (limit <= 0) throw StateError('Plafond d\'envoi invalide : $limit');
    if (_attempts.length < limit) return Duration.zero;
    _attempts.sort();
    // Pour repasser sous le plafond, il faut que les envois les plus anciens sortent de la fenêtre,
    // jusqu'à celui de rang (nombre - plafond).
    final blocking = _attempts[_attempts.length - limit];
    final resumeAt = blocking.add(window).add(margin);
    final wait = resumeAt.difference(now);
    return wait.isNegative ? Duration.zero : wait;
  }

  void _purge(DateTime now) {
    final start = now.subtract(window);
    _attempts.removeWhere((t) => !t.isAfter(start) || t.isAfter(now.add(const Duration(minutes: 1))));
  }
}
