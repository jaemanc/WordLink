import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wordlink/local_knowledge_service.dart';
import 'package:wordlink/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('all modes clear at par with their fixed card counts', () async {
    final service = await LocalKnowledgeService.load(rootBundle.loadString);
    expect(service.stages.map((stage) => stage.difficulty.cardsRequired), [
      4,
      8,
      16,
    ]);

    expect(service.stages.map((stage) => stage.parSteps), [10, 15, 20]);
    for (final stage in service.stages) {
      final start = {for (final item in stage.initialWords) item.word: item};
      final queue = [(start, 0)];
      final seen = {CombinationRule.key(start.keys)};
      int? shortest;

      for (var head = 0; head < queue.length && shortest == null; head++) {
        final (inventory, moves) = queue[head];
        for (final key in stage.rules.keys) {
          final words = key.split('|');
          if (!words.every(inventory.containsKey)) continue;

          final ingredients =
              words.reversed.map((word) => inventory[word]!).toList();
          final outcome = service.craft(stage, ingredients);
          expect(outcome.ingredients, ingredients);
          final result = outcome.result!;
          if (outcome.isTargetReached) shortest = moves + 1;
          if (inventory.containsKey(result.word)) continue;

          final next = {...inventory, result.word: result};
          if (seen.add(CombinationRule.key(next.keys))) {
            queue.add((next, moves + 1));
          }
        }
      }
      expect(shortest, stage.parSteps, reason: stage.difficulty.name);
      expect(service.proximity(stage.targetWord, stage.targetWord), 100);

      expect(
        () => service.craft(stage, stage.initialWords.skip(1).toList()),
        throwsArgumentError,
      );
      expect(
        () => service.craft(
          stage,
          List.filled(stage.difficulty.cardsRequired, stage.initialWords.first),
        ),
        throwsArgumentError,
      );
    }

    final easy = service.stages.first;
    final dough = service.craft(easy, easy.initialWords);
    expect(dough.result?.word, '반죽');
    expect(dough.result?.attribute, WordAttribute.material);
    expect(dough.hint, contains('밀 → 반죽'));
    expect(dough.proximity, 38);
    expect(
      service.craft(easy, [...easy.initialWords.take(3), dough.result!]).result,
      isNull,
    );
  });
}
