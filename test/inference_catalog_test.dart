import 'package:flutter_test/flutter_test.dart';
import 'package:wordlink/inference_catalog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late InferenceCatalog catalog;
  setUpAll(() async => catalog = await InferenceCatalog.load());

  for (final (left, right, english, korean, rejected) in [
    ('Magnet', 'Needle', 'Compass', '나침반', '자석묶음'),
    ('Water', 'Fire', 'Steam', '수증기', '물불세트'),
    ('Sand', 'Fire', 'Glass', '유리', '뜨거운 모래'),
    ('Electricity', 'Light', 'Bulb', '전구', '전기빛'),
    ('Wind', 'Wheel', 'Windmill', '풍차', null),
    ('Cloud', 'Electricity', 'Lightning', '번개', null),
    ('Seed', 'Soil', 'Plant', '식물', null),
  ]) {
    test('$left + $right returns $english in either order', () {
      final a = catalog.find(left, false).single;
      final b = catalog.find(right, false).single;
      final result = catalog.recipeResult(a, b);
      expect(result, catalog.find(english, false).single);
      expect(catalog.recipeResult(b, a), result);
      expect(catalog.words[result!].korean, korean);
      if (rejected != null) {
        expect(catalog.find(rejected, true), isEmpty);
      }
    });
  }

  test(
    'unrelated pairs and pairs with only a physical grouping yield nothing',
    () {
      for (final (left, right) in [
        ('Wood', 'Paper'),
        ('Keyboard', 'Salt'),
        ('Vinegar', 'Brush'),
      ]) {
        final a = catalog.find(left, false).single;
        final b = catalog.find(right, false).single;
        expect(catalog.recipeResult(a, b), isNull);
        expect(catalog.recipeResult(b, a), isNull);
      }
    },
  );
}
