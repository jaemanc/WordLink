import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'local_knowledge_service.dart';
import 'models.dart';

final knowledgeProvider = FutureProvider(
  (ref) => LocalKnowledgeService.load(
    (path) => rootBundle.loadString(path, cache: false),
  ),
);

final gameProvider = AsyncNotifierProvider<GameController, GameState>(
  GameController.new,
);

class GameState {
  GameState(
    this.stage, {
    required this.rounds,
    required this.inventory,
    this.selected = const [],
    this.history = const [],
    this.completedRounds = 0,
  });

  final Stage stage;
  final List<PuzzleRound> rounds;
  final List<WordItem> inventory;
  final List<WordItem> selected;
  final List<CraftOutcome> history;
  final int completedRounds;

  int get cardsRequired => stage.difficulty.cardsRequired;
  bool get canCraft => !cleared && selected.length == cardsRequired;
  int get moves => history.length;
  CraftOutcome? get latest => history.isEmpty ? null : history.last;
  bool get cleared => completedRounds == stage.parSteps;

  int get stars =>
      !cleared
          ? 0
          : moves <= stage.parSteps
          ? 3
          : moves <= stage.parSteps + 2
          ? 2
          : 1;
}

class GameController extends AsyncNotifier<GameState> {
  @override
  Future<GameState> build() async {
    final knowledge = await ref.watch(knowledgeProvider.future);
    final stage = knowledge.stages.first;
    final rounds = await knowledge.loadRounds(stage);
    return GameState(stage, rounds: rounds, inventory: rounds.first.stock);
  }

  Future<void> start(Stage stage) async {
    final current = state.asData?.value;
    if (current == null) return;
    if (current.stage == stage) {
      state = AsyncData(
        GameState(
          stage,
          rounds: current.rounds,
          inventory: current.rounds.first.stock,
        ),
      );
      return;
    }

    final knowledge = ref.read(knowledgeProvider).requireValue;
    state = const AsyncLoading();
    final next = await AsyncValue.guard(() async {
      final rounds = await knowledge.loadRounds(stage);
      return GameState(stage, rounds: rounds, inventory: rounds.first.stock);
    });
    if (ref.mounted) state = next;
  }

  void toggle(WordItem item) {
    final game = state.asData?.value;
    if (game == null || game.cleared || !game.inventory.contains(item)) return;
    final selected = [...game.selected];
    if (!selected.remove(item)) {
      if (selected.length == game.cardsRequired) return;
      selected.add(item);
    }
    _updateSelection(game, List.unmodifiable(selected));
  }

  void clearSelection() {
    final game = state.asData?.value;
    if (game != null) _updateSelection(game, const []);
  }

  void _updateSelection(GameState game, List<WordItem> selected) {
    state = AsyncData(
      GameState(
        game.stage,
        rounds: game.rounds,
        inventory: game.inventory,
        selected: selected,
        history: game.history,
        completedRounds: game.completedRounds,
      ),
    );
  }

  void craft() {
    final game = state.asData?.value;
    if (game == null || !game.canCraft) return;
    final knowledge = ref.read(knowledgeProvider).requireValue;
    final outcome = knowledge.craft(
      game.stage,
      game.rounds[game.completedRounds],
      game.selected,
    );
    final result = outcome.result;
    final completed = game.completedRounds + (result == null ? 0 : 1);
    state = AsyncData(
      GameState(
        game.stage,
        rounds: game.rounds,
        inventory:
            result == null
                ? game.inventory
                : List.unmodifiable([
                  result,
                  if (!outcome.isTargetReached) ...game.rounds[completed].stock,
                  ...game.inventory.where(
                    (item) => !game.selected.contains(item),
                  ),
                ]),
        selected: result == null ? game.selected : const [],
        history: List.unmodifiable([...game.history, outcome]),
        completedRounds: completed,
      ),
    );
  }
}
