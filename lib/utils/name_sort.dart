// Outils de tri des listes de l'écran BDC.

/// Critère de tri des fournisseurs dans les étapes 1 et 2.
enum BdcSortField { provider, consultant }

const Map<String, String> _accents = {
  'à': 'a', 'á': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a', 'å': 'a',
  'ç': 'c',
  'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e',
  'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i',
  'ñ': 'n',
  'ò': 'o', 'ó': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o',
  'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u',
  'ý': 'y', 'ÿ': 'y',
  'œ': 'oe', 'æ': 'ae',
};

/// Clé de tri insensible à la casse et aux accents (« Émile » se range avec les E, pas après Z).
String normalizeForSort(String value) {
  final lower = value.trim().toLowerCase();
  final buffer = StringBuffer();
  for (final char in lower.split('')) {
    buffer.write(_accents[char] ?? char);
  }
  return buffer.toString();
}

/// Compare deux noms dans l'ordre demandé (A → Z si [ascending], sinon Z → A).
int compareNames(String a, String b, {bool ascending = true}) {
  final result = normalizeForSort(a).compareTo(normalizeForSort(b));
  return ascending ? result : -result;
}

/// Nom qui représente un groupe de prestations pour le tri : le nom du fournisseur, ou le consultant qui vient
/// en premier dans l'ordre demandé.
String groupSortName({
  required BdcSortField field,
  required String providerName,
  required Iterable<String> consultantNames,
  bool ascending = true,
}) {
  if (field == BdcSortField.provider || consultantNames.isEmpty) return providerName;
  final names = consultantNames.toList()..sort((a, b) => compareNames(a, b, ascending: ascending));
  return names.first;
}

/// Case à cocher d'un fournisseur (trois états : tout coché, partiel, rien) : un clic sur « tout coché »
/// décoche tout ; dans les autres cas, il coche tout.
bool providerCheckboxTarget(bool? currentValue) => currentValue != true;
