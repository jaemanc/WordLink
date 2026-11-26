import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wordlink/craft_impact.dart';
import 'package:wordlink/game_controller.dart';
import 'package:wordlink/local_knowledge_service.dart';
import 'package:wordlink/main.dart';

void main() {
  testWidgets('search, consume, and reset a Hard puzzle on mobile', (
    tester,
  ) async {
    const impactChannel = MethodChannel('wordlink/impact');
    final sounds = <MethodCall>[];
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(impactChannel, (call) async {
      sounds.add(call);
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(impactChannel, null));

    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 740);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final service = await tester.runAsync(
      () => LocalKnowledgeService.load(
        (path) => rootBundle.loadString(path, cache: false),
      ),
    );
    final container = ProviderContainer(
      overrides: [knowledgeProvider.overrideWith((ref) async => service!)],
    );
    addTearDown(container.dispose);
    Future<void> settleStage() async {
      // The asset isolate runs on real time, while widget futures need pumps.
      for (
        var attempt = 0;
        attempt < 300 && container.read(gameProvider).isLoading;
        attempt++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      expect(container.read(gameProvider).hasValue, isTrue);
      await tester.pumpAndSettle();
    }

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const WordLinkApp(),
      ),
    );
    await settleStage();

    await tester.tap(find.text('HARD 16장'));
    await settleStage();
    await tester.tap(find.text('문제 1 / 10000'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '10000');
    await tester.pumpAndSettle();
    final stage = service!.stages.last;
    await tester.tap(find.text('${stage.targetEmoji} ${stage.targetWord}'));
    await tester.pump();
    await settleStage();

    final controller = container.read(gameProvider.notifier);
    final initial = container.read(gameProvider).requireValue;
    expect(initial.stage, stage);
    final round = initial.rounds.first;
    final ingredients = round.rule.ingredients;
    final wrong = initial.inventory.firstWhere(
      (item) => !ingredients.contains(item),
    );
    for (final item in [wrong, ...ingredients.skip(1)]) {
      controller.toggle(item);
    }
    await tester.pumpAndSettle();
    await tester.tap(find.text('조합하기'));
    await tester.pumpAndSettle();
    expect(
      container.read(gameProvider).requireValue.inventory,
      initial.inventory,
    );

    controller.clearSelection();
    for (final item in ingredients) {
      controller.toggle(item);
    }
    await tester.pumpAndSettle();
    expect(find.text('16 / 16장'), findsOneWidget);
    await tester.tap(find.text('조합하기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final approach = tester.widget<CraftImpact>(find.byType(CraftImpact));
    expect(approach.cards, hasLength(16));
    expect(approach.progress, lessThan(CraftImpact.collision));
    expect(sounds, isEmpty);

    await tester.pump(const Duration(milliseconds: 90));
    await tester.pump();
    expect(sounds.single.method, 'play');
    expect(sounds.single.arguments, false);
    await tester.pumpAndSettle();
    expect(find.byType(CraftImpact), findsNothing);

    final crafted = container.read(gameProvider).requireValue;
    expect(crafted.completedRounds, 1);
    expect(crafted.inventory, contains(round.rule.result));
    expect(crafted.inventory, contains(wrong));
    expect(crafted.inventory.any(ingredients.contains), isFalse);
    expect(crafted.inventory, containsAll(initial.rounds[1].stock));

    await tester.tap(find.byTooltip('다시 시작'));
    await tester.pumpAndSettle();
    final reset = container.read(gameProvider).requireValue;
    expect(reset.stage, stage);
    expect(reset.inventory, initial.inventory);
    expect(reset.moves, 0);
    expect(reset.completedRounds, 0);
  });
}
