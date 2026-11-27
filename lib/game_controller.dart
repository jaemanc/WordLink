import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'campaign_progress.dart';
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
    this.newDiscovery = false,
    this.latestReward = 0,
  });

  final Stage stage;
  final List<PuzzleRound> rounds;
  final List<WordItem> inventory;
  final List<WordItem> selected;
  final List<CraftOutcome> history;
  final int completedRounds;
  final bool newDiscovery;
  final int latestReward;

  int get currentProximity => latest?.proximity ?? 0;
  int get bestProximity => history.fold(
    0,
    (best, result) => result.proximity > best ? result.proximity : best,
  );
  int get previousProximity => moves < 2 ? 0 : history[moves - 2].proximity;
  int get proximityDelta => currentProximity - previousProximity;
  bool get newProximityRecord =>
      currentProximity > 0 &&
      history
          .take(moves - 1)
          .every((entry) => entry.proximity < currentProximity);

  int get cardsRequired => stage.difficulty.cardsRequired;
  static const selectionLimit = 4;
  bool get canCraft =>
      !cleared && selected.length >= 2 && selected.length <= selectionLimit;
  int get moves => history.length;
  CraftOutcome? get latest => history.isEmpty ? null : history.last;
  bool get cleared => completedRounds == stage.parSteps;

  int get stars => cleared ? awardStars(moves, stage.parSteps) : 0;
  static int awardStars(int attempts, int par) =>
      attempts <= par
          ? 3
          : attempts <= par + 2
          ? 2
          : 1;
}

class GameController extends AsyncNotifier<GameState> {
  @override
  Future<GameState> build() async {
    final knowledge = await ref.watch(knowledgeProvider.future);
    final stage = knowledge.stages.first;
    final rounds = await knowledge.loadRounds(stage);
    await ref.read(progressProvider.future);
    if (ref.mounted)
      ref.read(progressProvider.notifier).collect(rounds.first.stock);
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
      if (ref.mounted)
        ref.read(progressProvider.notifier).collect(rounds.first.stock);
      return GameState(stage, rounds: rounds, inventory: rounds.first.stock);
    });
    if (ref.mounted) state = next;
  }

  void toggle(WordItem item) {
    final game = state.asData?.value;
    if (game == null || game.cleared || !game.inventory.contains(item)) return;
    final selected = [...game.selected];
    if (!selected.remove(item)) {
      if (selected.length == GameState.selectionLimit) return;
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
        newDiscovery: game.newDiscovery,
        latestReward: game.latestReward,
      ),
    );
  }

  void craft() {
    final game = state.asData?.value;
    if (game == null || !game.canCraft) return;
    final knowledge = ref.read(knowledgeProvider).requireValue;
    final round = game.rounds[game.completedRounds];
    final outcome = knowledge.craft(game.stage, round, game.selected);
    final completed = game.completedRounds + (outcome.isRecipeMatch ? 1 : 0);
    final remaining = game.inventory.where(
      (item) => !game.selected.contains(item),
    );
    final inventory = [
      outcome.result,
      ...remaining,
      if (!outcome.isRecipeMatch)
        ...round.rule.missingFrom([outcome.result, ...remaining]),
    ];
    final fresh =
        outcome.isRecipeMatch && !outcome.isTargetReached
            ? game.rounds[completed].stock
            : const <WordItem>[];
    inventory.insertAll(1, fresh);
    final discovery = ref
        .read(progressProvider.notifier)
        .record(
          game.stage,
          outcome,
          game.moves + 1,
          GameState.awardStars(game.moves + 1, game.stage.parSteps),
          newCards: fresh,
        );
    state = AsyncData(
      GameState(
        game.stage,
        rounds: game.rounds,
        inventory: List.unmodifiable(inventory),
        history: List.unmodifiable([...game.history, outcome]),
        completedRounds: completed,
        newDiscovery: discovery.isNew,
        latestReward: discovery.reward,
      ),
    );
  }
}
