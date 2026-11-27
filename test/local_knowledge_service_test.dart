import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wordlink/local_knowledge_service.dart';
import 'package:wordlink/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'all 30,000 English puzzles solve through their consumable recipes',
    () async {
      final packs = <String>[];
      final service = await LocalKnowledgeService.load((path) {
        if (path.startsWith('assets/puzzles/')) packs.add(path);
        return rootBundle.loadString(path, cache: false);
      });
      expect(packs, isEmpty);
      expect(service.stages.length, 30000);
      final english = RegExp(r'^[A-Za-z][A-Za-z -]*$');
      final goals = <String>{};
      final vocabulary = <String>{};
      for (final difficulty in Difficulty.values) {
        final stages = service.stages.where(
          (stage) => stage.difficulty == difficulty,
        );
        expect(stages.length, 10000);
        final paths = <String>{};
        final steps = [10, 15, 20][difficulty.index];
        for (final stage in stages) {
          expect(stage.parSteps, steps);
          expect(goals.add(stage.targetWord), isTrue);
          expect(english.hasMatch(stage.targetWord), isTrue);
          final rounds = await service.loadRounds(stage);
          paths.add(
            rounds
                .take(steps - 1)
                .map((round) => round.rule.result.word)
                .join('|'),
          );
          final inventory = <WordItem>{};
          for (final (index, round) in rounds.indexed) {
            inventory.addAll(round.stock);
            vocabulary.addAll(round.stock.map((item) => item.word));
            expect(
              round.stock.every((item) => english.hasMatch(item.word)),
              isTrue,
            );
            final ingredients = round.rule.ingredients.reversed.toList();
            expect(ingredients.length, difficulty.cardsRequired);
            expect(ingredients.every(inventory.contains), isTrue);
            if (stage.position == 0 && index == 0) {
              final wrong = inventory.firstWhere(
                (item) => !ingredients.contains(item),
              );
              final inputs = [wrong, ...ingredients.skip(1)];
              final derived = service.craft(stage, round, inputs);
              expect(derived.isRecipeMatch, isFalse);
              expect(derived.isTargetReached, isFalse);
              expect(derived.result.sourceNouns, isNotEmpty);
              expect(
                service
                    .craft(stage, round, inputs.reversed.toList())
                    .result
                    .word,
                derived.result.word,
              );
            }
            final result = service.craft(stage, round, ingredients);
            expect(result.isRecipeMatch, isTrue);
            expect(result.isTargetReached, index == steps - 1);
            expect(result.result, round.rule.result);
            vocabulary.add(result.result.word);
            inventory.removeAll(ingredients);
            expect(inventory.add(result.result), isTrue);
          }
          expect(service.proximity(stage.targetWord, stage.targetWord), 100);
        }
        expect(paths.length, 480, reason: difficulty.name);
      }
      expect(packs.length, 45);
      expect(vocabulary.length, greaterThanOrEqualTo(500));
    },
  );
}
