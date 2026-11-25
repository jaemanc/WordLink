import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wordlink/game_controller.dart';
import 'package:wordlink/local_knowledge_service.dart';
import 'package:wordlink/main.dart';

void main() {
  testWidgets(
    'attribute filtering and Hard sixteen-card crafting work on mobile',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 740);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      final service = await tester.runAsync(
        () => LocalKnowledgeService.load(rootBundle.loadString),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [knowledgeProvider.overrideWith((ref) async => service!)],
          child: const WordLinkApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('전체 속성'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('에너지').last);
      await tester.pumpAndSettle();
      expect(find.text('불'), findsOneWidget);
      expect(find.text('밀'), findsNothing);

      await tester.tap(find.text('에너지'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('전체 속성').last);
      await tester.pumpAndSettle();
      expect(find.text('밀'), findsOneWidget);

      await tester.tap(find.text('HARD 16장'));
      await tester.pumpAndSettle();
      expect(find.text('0 / 16장'), findsOneWidget);

      await tester.tap(find.text('모두 선택'));
      await tester.pumpAndSettle();
      expect(find.text('16 / 16장'), findsOneWidget);

      await tester.tap(find.text('조합하기'));
      await tester.pumpAndSettle();
      expect(find.text('0 / 16장'), findsOneWidget);
      expect(find.text('⚛️ 이온'), findsOneWidget);
      await tester.tap(find.text('다음 조합 힌트'));
      await tester.pumpAndSettle();
      expect(find.text('빛 → 이온 (재료)'), findsOneWidget);

      await tester.tap(find.text('이전 재료 선택'));
      await tester.pumpAndSettle();
      expect(find.text('16 / 16장'), findsOneWidget);
    },
  );
}
