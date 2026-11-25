import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'local_knowledge_service.dart';
import 'models.dart';

final knowledgeProvider = FutureProvider(
  (ref) => LocalKnowledgeService.load(rootBundle.loadString),
);

final gameProvider = NotifierProvider<GameController, GameState?>(
  GameController.new,
);

class GameState {
  GameState(
    this.stage, {
    required this.inventory,
    this.selected = const [],
    this.history = const [],
  });

  final Stage stage;
  final List<WordItem> inventory;
  final List<WordItem> selected;
  final List<CraftOutcome> history;

  int get moves => history.length;
  CraftOutcome? get latest => history.isEmpty ? null : history.last;
  bool get cleared => latest?.isTargetReached ?? false;
  int get stars => !cleared
      ? 0
      : moves <= stage.parSteps
      ? 3
      : moves <= stage.parSteps + 2
      ? 2
      : 1;
}

class GameController extends Notifier<GameState?> {
  @override
  GameState? build() {
    final knowledge = ref.watch(knowledgeProvider).asData?.value;
    if (knowledge == null) return null;
    final stage = knowledge.stages.first;
    return GameState(stage, inventory: stage.initialWords);
  }

  void start(Stage stage) {
    state = GameState(stage, inventory: stage.initialWords);
  }

  void toggle(WordItem item) {
    final game = state;
    if (game == null || game.cleared || !game.inventory.contains(item)) return;
    final selected = [...game.selected];
    if (!selected.remove(item)) {
      if (selected.length == 2) return;
      selected.add(item);
    }
    state = GameState(
      game.stage,
      inventory: game.inventory,
      selected: List.unmodifiable(selected),
      history: game.history,
    );
  }

  void craft() {
    final game = state;
    if (game == null || game.cleared || game.selected.length != 2) return;
    final knowledge = ref.read(knowledgeProvider).requireValue;
    final outcome = knowledge.craft(
      game.stage,
      game.selected[0],
      game.selected[1],
    );
    final result = outcome.result;
    state = GameState(
      game.stage,
      inventory:
          result != null &&
              !game.inventory.any((item) => item.word == result.word)
          ? List.unmodifiable([...game.inventory, result])
          : game.inventory,
      history: List.unmodifiable([...game.history, outcome]),
    );
  }
}
