import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wordlink/local_knowledge_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every stage has a shortest clear at par', () async {
    final service = await LocalKnowledgeService.load(rootBundle.loadString);
    expect(service.stages.length, 3);
    for (final stage in service.stages) {
      final queue = [(stage.initialWords, 0)];
      final seen = <String>{};
      int? shortest;
      for (var head = 0; head < queue.length && shortest == null; head++) {
        final (inventory, moves) = queue[head];
        for (var i = 0; i < inventory.length; i++) {
          for (var j = i + 1; j < inventory.length; j++) {
            final outcome = service.craft(stage, inventory[i], inventory[j]);
            if (outcome.isTargetReached) shortest = moves + 1;
            final result = outcome.result;
            if (result == null ||
                inventory.any((item) => item.word == result.word)) {
              continue;
            }
            final next = [...inventory, result];
            final words = next.map((item) => item.word).toList()..sort();
            if (seen.add(words.join('|'))) queue.add((next, moves + 1));
          }
        }
      }
      expect(shortest, stage.parSteps, reason: stage.difficulty.name);
      expect(service.proximity(stage.targetWord, stage.targetWord), 100);
    }

    final easy = service.stages.first;
    final [wheat, water, fire, salt] = easy.initialWords;
    final dough = service.craft(easy, water, wheat);
    expect(dough.result?.word, '반죽');
    expect(dough.proximity, 77);
    expect(service.craft(easy, dough.result!, fire).isTargetReached, isTrue);
    expect(service.craft(easy, fire, salt).result, isNull);
  });
}
