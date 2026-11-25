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

  int get cardsRequired => stage.difficulty.cardsRequired;
  bool get canCraft => !cleared && selected.length == cardsRequired;
  int get moves => history.length;
  CraftOutcome? get latest => history.isEmpty ? null : history.last;
  CraftOutcome? get lastHintedCraft {
    for (final outcome in history.reversed) {
      if (outcome.hint != null) return outcome;
    }
    return null;
  }

  bool get cleared => latest?.isTargetReached ?? false;
  int get stars =>
      !cleared
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
      if (selected.length == game.cardsRequired) return;
      selected.add(item);
    }
    state = GameState(
      game.stage,
      inventory: game.inventory,
      selected: List.unmodifiable(selected),
      history: game.history,
    );
  }

  void toggleBatchSelection() {
    final game = state;
    if (game == null || game.cleared) return;
    final previous = (game.lastHintedCraft ?? game.latest)?.ingredients;
    state = GameState(
      game.stage,
      inventory: game.inventory,
      selected:
          game.selected.isNotEmpty
              ? const []
              : previous ??
                  (game.inventory.length == game.cardsRequired
                      ? game.inventory
                      : const []),
      history: game.history,
    );
  }

  void craft() {
    final game = state;
    if (game == null || !game.canCraft) return;
    final knowledge = ref.read(knowledgeProvider).requireValue;
    final outcome = knowledge.craft(game.stage, game.selected);
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
