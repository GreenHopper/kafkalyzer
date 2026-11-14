import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/src/features/search/domain/filter_terms.dart';

void main() {
  test('splitFilterTerms splits on comma, trims, and drops empties', () {
    expect(splitFilterTerms(' a , ,b '), ['a', 'b']);
    expect(splitFilterTerms(''), isEmpty);
    expect(splitFilterTerms(' , , '), isEmpty);
    expect(splitFilterTerms('order-4711'), ['order-4711']);
  });
}
