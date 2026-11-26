import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'models.dart';

class LocalKnowledgeService {
  LocalKnowledgeService._(this.stages, this._words, this._unitVectors);

  late final Future<String> Function(String) _readAsset;
  final List<WordItem> _words;
  (int, List<dynamic>)? _cachedPack;

  final List<Stage> stages;
  final Map<String, List<double>> _unitVectors;
  final _similarities = <(String, String), int>{};
  late final _byDifficulty = {
    for (final difficulty in Difficulty.values)
      difficulty: List<Stage>.unmodifiable(
        stages.where((stage) => stage.difficulty == difficulty),
      ),
  };

  List<Stage> stagesFor(Difficulty difficulty) => _byDifficulty[difficulty]!;

  static Future<LocalKnowledgeService> load(
    Future<String> Function(String) readAsset,
  ) async {
    final assets = await Future.wait([
      readAsset('assets/stages.json'),
      readAsset('assets/embeddings.json'),
    ]);
    final service = await compute(_decode, assets);
    service._readAsset = readAsset;
    return service;
  }

  static LocalKnowledgeService _decode(List<String> assets) {
    final catalog = jsonDecode(assets[0]) as Map<String, dynamic>;
    final words = (catalog['words'] as List)
        .map((row) => WordItem.fromRow(row as List))
        .toList(growable: false);
    if (words.map((item) => item.word).toSet().length != words.length) {
      throw const FormatException('Duplicate card names.');
    }

    final vectors = <String, List<double>>{};
    int? dimensions;
    for (final entry
        in (jsonDecode(assets[1]) as Map<String, dynamic>).entries) {
      final vector = (entry.value as List).map((n) => (n as num).toDouble());
      final norm = math.sqrt(vector.fold<double>(0, (sum, n) => sum + n * n));
      dimensions ??= vector.length;
      if (vector.length != dimensions || !norm.isFinite || norm == 0) {
        throw FormatException('Invalid vector: ${entry.key}');
      }
      vectors[entry.key] = vector.map((n) => n / norm).toList();
    }
    if (!words.every((item) => vectors.containsKey(item.word))) {
      throw const FormatException('A campaign card has no vector.');
    }

    final rows = catalog['stages'] as List;
    final stages = [
      for (final (index, row) in rows.indexed)
        _readStage(index + 1, row as List, words),
    ];
    if (stages.isEmpty) throw const FormatException('Empty campaign.');
    return LocalKnowledgeService._(List.unmodifiable(stages), words, vectors);
  }

  static Stage _readStage(int id, List<dynamic> row, List<WordItem> words) {
    final difficulty = Difficulty.values.byName(row[0] as String);
    final target = words[row[1] as int];
    return Stage(id, difficulty, target, row[2] as int, row[3] as int);
  }

  Future<List<PuzzleRound>> loadRounds(Stage stage) async {
    final cached = _cachedPack;
    final List<dynamic> pack;
    if (cached != null && cached.$1 == stage.pack) {
      pack = cached.$2;
    } else {
      final json = await _readAsset('assets/puzzles/${stage.pack}.json');
      pack = await compute(_decodePack, json);
      _cachedPack = (stage.pack, pack);
    }
    return _readRounds(pack[stage.position] as List, _words, stage);
  }

  static List<dynamic> _decodePack(String json) => jsonDecode(json) as List;

  static List<PuzzleRound> _readRounds(
    List<dynamic> rows,
    List<WordItem> words,
    Stage stage,
  ) {
    if (rows.length != stage.parSteps) {
      throw const FormatException('Invalid stage length.');
    }
    final rounds = <PuzzleRound>[];
    final seen = <WordItem>{};
    WordItem? carry;
    for (final (index, entry) in rows.indexed) {
      final row = entry as List;
      final result = words[row[0] as int];
      final fresh = [for (final id in row[1] as List) words[id as int]];
      final stock = [
        ...fresh,
        for (final id in row[2] as List) words[id as int],
      ];
      final ingredients = [if (carry != null) carry, ...fresh];
      if (ingredients.length != stage.difficulty.cardsRequired ||
          !stock.every(seen.add) ||
          !seen.add(result) ||
          (result == stage.target) != (index == rows.length - 1)) {
        throw const FormatException('Invalid round inventory or answer.');
      }
      // The exported rows store recipe cards first. Mix the display order deterministically.
      stock.shuffle(math.Random(result.word.hashCode ^ index));
      rounds.add(
        PuzzleRound(
          CombinationRule(ingredients: ingredients, result: result),
          stock,
        ),
      );
      carry = result;
    }
    return List.unmodifiable(rounds);
  }

  int proximity(String word, String target) =>
      _similarities.putIfAbsent((word, target), () {
        final left = _unitVectors[word];
        final right = _unitVectors[target];
        if (left == null || right == null) return 0;
        var dot = 0.0;
        for (var i = 0; i < left.length; i++) {
          dot += left[i] * right[i];
        }
        return (dot.clamp(0.0, 1.0) * 100).round();
      });

  CraftOutcome craft(
    Stage stage,
    PuzzleRound round,
    List<WordItem> ingredients,
  ) {
    final rule = round.rule;
    final result = rule.matches(ingredients) ? rule.result : null;
    return CraftOutcome(
      ingredients: List.unmodifiable(ingredients),
      result: result,
      proximity:
          result == null ? null : proximity(result.word, stage.targetWord),
      isTargetReached: result == stage.target,
    );
  }
}
