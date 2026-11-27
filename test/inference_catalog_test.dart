import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wordlink/campaign_progress.dart';
import 'package:wordlink/inference_catalog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late InferenceCatalog catalog;
  setUpAll(() async => catalog = await InferenceCatalog.load());

  test(
    'board packs expose the verified minimum and rating boundaries',
    () async {
      for (var difficulty = 0; difficulty < 3; difficulty++) {
        final board = (await catalog.next(difficulty))!;
        expect(board.starters, hasLength(catalog.handSize));
        expect(board.starters, isNot(contains(board.target)));
        final minimum = board.minimumMoves;
        expect(minimum, greaterThan(0));
        expect(board.starsFor(minimum), 3);
        expect(board.starsFor(minimum + 1), 2);
        expect(board.starsFor(minimum + 2), 2);
        expect(board.starsFor(minimum + 3), 1);
        final reordered = InferenceBoard(
          board.target,
          board.starters.reversed.toList(),
          board.scores,
          minimum,
        );
        expect(
          catalog.recordKey(difficulty, reordered),
          catalog.recordKey(difficulty, board),
        );
      }
    },
  );

  test('inference records persist and keep legacy campaign progress', () async {
    const channel = MethodChannel('wordlink/settings');
    String? saved = '{"records":{"7":[3,2]},"points":5}';
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getProgress') return saved;
      if (call.method == 'setProgress') saved = call.arguments as String;
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final progress = await container.read(progressProvider.future);
    expect(progress.inferenceRecords, isEmpty);
    final notifier = container.read(progressProvider.notifier);
    expect(notifier.recordInference('board', 8, 1), isTrue);
    expect(notifier.recordInference('board', 4, 3), isTrue);
    expect(notifier.recordInference('board', 5, 2), isFalse);
    await Future<void>.delayed(Duration.zero);
    final restored = CampaignProgress.fromJson(saved!);
    expect(restored.inferenceRecords['board']!.moves, 4);
    expect(restored.inferenceRecords['board']!.stars, 3);
    expect(restored.records[7]!.moves, 3);
    expect(restored.rewardPoints, 5);
  });

  for (final (left, right, english, korean, rejected) in [
    ('Magnet', 'Needle', 'Compass', '나침반', '자석묶음'),
    ('Water', 'Fire', 'Steam', '수증기', '물불세트'),
    ('Sand', 'Fire', 'Glass', '유리', '뜨거운 모래'),
    ('Electricity', 'Light', 'Bulb', '전구', '전기빛'),
    ('Wind', 'Wheel', 'Windmill', '풍차', null),
    ('Cloud', 'Electricity', 'Lightning', '번개', null),
    ('Flower', 'String', 'Flower Necklace', '꽃목걸이', null),
    ('Wood', 'Wheel', 'Wooden Cart', '나무 수레', null),
    ('Apple', 'Grapes', 'Fruit', '과일', null),
    ('Fire', 'Wood', 'Ash', '재', null),
    ('Water', 'Light', 'Rainbow', '무지개', null),
    ('Honey', 'Vanilla', 'Honey Vanilla Latte', '허니 바닐라 라떼', null),
    ('Milk', 'Chocolate', 'Chocolate Milk', '초코 우유', null),
    ('Flower', 'Fragrance', 'Perfume', '향수', null),
    ('Wood', 'Paper', 'Book', '책', null),
    ('Cat', 'Dog', 'Pet', '반려동물', null),
    ('Car', 'Electricity', 'Electric Car', '전기차', null),
    ('Light', 'Hope', 'Beacon', '등불', null),
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
        ('Cat', 'Car'),
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
