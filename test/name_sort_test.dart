import 'package:flutter_test/flutter_test.dart';
import 'package:opsis_app/utils/name_sort.dart';

void main() {
  group('Case à cocher du fournisseur', () {
    test('tout coché : un clic décoche tout (bug de la v0.1.12)', () {
      expect(providerCheckboxTarget(true), isFalse);
    });

    test('partiel ou rien de coché : un clic coche tout', () {
      expect(providerCheckboxTarget(null), isTrue);
      expect(providerCheckboxTarget(false), isTrue);
    });

    test('deux clics successifs reviennent à l\'état de départ', () {
      var state = true;
      state = providerCheckboxTarget(state);
      state = providerCheckboxTarget(state);
      expect(state, isTrue);
    });
  });

  group('Tri par nom', () {
    final names = ['Zoé MARTIN', 'émile DURAND', 'Alice BERNARD', 'Éric Petit', 'bruno LEROY'];

    test('A → Z, insensible à la casse et aux accents', () {
      final sorted = [...names]..sort((a, b) => compareNames(a, b));
      expect(sorted, ['Alice BERNARD', 'bruno LEROY', 'émile DURAND', 'Éric Petit', 'Zoé MARTIN']);
    });

    test('Z → A', () {
      final sorted = [...names]..sort((a, b) => compareNames(a, b, ascending: false));
      expect(sorted, ['Zoé MARTIN', 'Éric Petit', 'émile DURAND', 'bruno LEROY', 'Alice BERNARD']);
    });

    test('un groupe se range par son fournisseur, ou par son premier consultant dans l\'ordre choisi', () {
      const consultants = ['Marc', 'Anne', 'Zoé'];
      expect(
          groupSortName(field: BdcSortField.provider, providerName: 'ACME', consultantNames: consultants), 'ACME');
      expect(groupSortName(field: BdcSortField.consultant, providerName: 'ACME', consultantNames: consultants),
          'Anne');
      expect(
          groupSortName(
              field: BdcSortField.consultant, providerName: 'ACME', consultantNames: consultants, ascending: false),
          'Zoé');
      expect(groupSortName(field: BdcSortField.consultant, providerName: 'ACME', consultantNames: const []), 'ACME');
    });
  });
}
