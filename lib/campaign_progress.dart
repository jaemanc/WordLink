import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models.dart';
import 'word_relations.dart';

class StageRecord {
  const StageRecord(this.moves, this.stars);
  final int moves;
  final int stars;
}

class CampaignProgress {
  const CampaignProgress({
    this.discovered = const {},
    this.hiddenRecipes = const {},
    this.records = const {},
    this.rewardPoints = 0,
  });

  final Set<String> discovered;
  final Set<String> hiddenRecipes;
  final Map<int, StageRecord> records;
  final int rewardPoints;

  factory CampaignProgress.fromJson(String text) {
    final data = jsonDecode(text) as Map<String, dynamic>;
    final records = data['records'] as Map<String, dynamic>? ?? {};
    return CampaignProgress(
      discovered: Set.unmodifiable(
        (data['words'] as List? ?? []).cast<String>().map(
          WordRelations.collectionKey,
        ),
      ),
      hiddenRecipes: Set.unmodifiable(
        (data['hidden'] as List? ?? []).cast<String>(),
      ),
      records: Map.unmodifiable({
        for (final entry in records.entries)
          int.parse(entry.key): StageRecord(
            (entry.value as List)[0] as int,
            (entry.value as List)[1] as int,
          ),
      }),
      rewardPoints: data['points'] as int? ?? 0,
    );
  }

  String encode() => jsonEncode({
    'words': discovered.toList(),
    'hidden': hiddenRecipes.toList(),
    'records': {
      for (final entry in records.entries)
        '${entry.key}': [entry.value.moves, entry.value.stars],
    },
    'points': rewardPoints,
  });
}

final progressProvider =
    AsyncNotifierProvider<ProgressController, CampaignProgress>(
      ProgressController.new,
    );

class ProgressController extends AsyncNotifier<CampaignProgress> {
  static const _channel = MethodChannel('wordlink/settings');
  static const hiddenReward = 10;
  Future<void> _writes = Future.value();

  @override
  Future<CampaignProgress> build() async {
    try {
      final saved = await _channel.invokeMethod<String>('getProgress');
      return saved == null
          ? const CampaignProgress()
          : CampaignProgress.fromJson(saved);
    } on MissingPluginException {
      return const CampaignProgress();
    } on FormatException {
      return const CampaignProgress();
    } on TypeError {
      return const CampaignProgress();
    }
  }

  void collect(Iterable<WordItem> cards) {
    final old = state.requireValue;
    final discovered = {
      ...old.discovered,
      ...cards.map((item) => WordRelations.collectionKey(item.label)),
    };
    if (discovered.length == old.discovered.length) return;
    _save(
      CampaignProgress(
        discovered: Set.unmodifiable(discovered),
        hiddenRecipes: old.hiddenRecipes,
        records: old.records,
        rewardPoints: old.rewardPoints,
      ),
    );
  }

  ({bool isNew, int reward}) record(
    Stage stage,
    CraftOutcome outcome,
    int moves,
    int stars, {
    Iterable<WordItem> newCards = const [],
  }) {
    final old = state.requireValue;
    final name = WordRelations.collectionKey(outcome.result.label);
    final isNew = !old.discovered.contains(name);
    final discovered =
        isNew || newCards.isNotEmpty
            ? {
              ...old.discovered,
              name,
              ...newCards.map(
                (item) => WordRelations.collectionKey(item.label),
              ),
            }
            : old.discovered;
    final recipe =
        outcome.isHidden ? WordRelations.recipeKey(outcome.ingredients) : null;
    final reward =
        recipe != null && !old.hiddenRecipes.contains(recipe)
            ? hiddenReward
            : 0;
    final best = old.records[stage.id];
    final improved =
        outcome.isTargetReached && (best == null || moves < best.moves);
    if (discovered.length != old.discovered.length || reward != 0 || improved) {
      _save(
        CampaignProgress(
          discovered: Set.unmodifiable(discovered),
          hiddenRecipes:
              reward != 0
                  ? Set.unmodifiable({...old.hiddenRecipes, recipe!})
                  : old.hiddenRecipes,
          rewardPoints: old.rewardPoints + reward,
          records:
              improved
                  ? Map.unmodifiable({
                    ...old.records,
                    stage.id: StageRecord(moves, stars),
                  })
                  : old.records,
        ),
      );
    }
    return (isNew: isNew, reward: reward);
  }

  void _save(CampaignProgress next) {
    state = AsyncData(next);
    _writes = _writes.then((_) async {
      try {
        await _channel.invokeMethod<void>('setProgress', next.encode());
      } on MissingPluginException {
        // Non-mobile runners retain progress for the current session.
      }
    });
    unawaited(_writes);
  }
}
