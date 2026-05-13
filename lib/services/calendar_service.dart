import 'package:intl/intl.dart';

class CalendarService {
  /// Calcule le nombre de jours ouvrés entre deux dates (inclusives)
  /// en excluant les week-ends et une liste optionnelle de jours fériés (format YYYY-MM-DD)
  static int calculateWorkingDays({
    required DateTime start,
    required DateTime end,
    List<String> holidays = const [],
  }) {
    if (start.isAfter(end)) return 0;

    int workingDays = 0;
    DateTime current = DateTime(start.year, start.month, start.day);
    final normalizedEnd = DateTime(end.year, end.month, end.day);
    final formatter = DateFormat('yyyy-MM-dd');

    while (current.isBefore(normalizedEnd) || current.isAtSameMomentAs(normalizedEnd)) {
      // Vérifier si c'est un week-end (Samedi = 6, Dimanche = 7)
      if (current.weekday != DateTime.saturday && current.weekday != DateTime.sunday) {
        // Vérifier si c'est un jour férié
        final dateStr = formatter.format(current);
        if (!holidays.contains(dateStr)) {
          workingDays++;
        }
      }
      current = current.add(const Duration(days: 1));
    }

    return workingDays;
  }

  /// Retourne l'intersection entre une période de prestation et un mois donné
  /// Retourne un Map avec 'start' et 'end' ou null si aucune intersection
  static Map<String, DateTime>? getIntersection({
    required DateTime prestationStart,
    DateTime? prestationEnd,
    required int month,
    required int year,
  }) {
    final monthStart = DateTime(year, month, 1);
    final nextMonth = month == 12 ? DateTime(year + 1, 1, 1) : DateTime(year, month + 1, 1);
    final monthEnd = nextMonth.subtract(const Duration(days: 1));

    // Si la prestation finit avant le début du mois ou commence après la fin du mois
    if ((prestationEnd != null && prestationEnd.isBefore(monthStart)) || prestationStart.isAfter(monthEnd)) {
      return null;
    }

    final intersectionStart = prestationStart.isBefore(monthStart) ? monthStart : prestationStart;
    final intersectionEnd = (prestationEnd == null || prestationEnd.isAfter(monthEnd)) ? monthEnd : prestationEnd;

    return {
      'start': intersectionStart,
      'end': intersectionEnd,
    };
  }
}
