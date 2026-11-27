import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'models.dart';
import 'word_relations.dart';

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
      readAsset('assets/word_labels_ko.json'),
    ]);
    final service = await compute(_decode, assets);
    service._readAsset = readAsset;
    return service;
  }

  static LocalKnowledgeService _decode(List<String> assets) {
    final catalog = jsonDecode(assets[0]) as Map<String, dynamic>;
    final korean =
        (jsonDecode(assets[2]) as Map<String, dynamic>).cast<String, String>();
    final rows = (catalog['stages'] as List).cast<List<dynamic>>();
    final targetIds = {for (final row in rows) row[1] as int};
    final words = [
      for (final (index, raw) in (catalog['words'] as List).indexed)
        _readWord(raw as List, korean, targetIds.contains(index)),
    ];
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

    final stages = [
      for (final (index, row) in rows.indexed)
        _readStage(index + 1, row, words),
    ];
    if (stages.isEmpty) throw const FormatException('Empty campaign.');
    return LocalKnowledgeService._(List.unmodifiable(stages), words, vectors);
  }

  static WordItem _readWord(
    List<dynamic> row,
    Map<String, String> korean,
    bool isTarget,
  ) {
    final word = row.first as String;
    final label = korean[word];
    if (label == null) throw FormatException('Missing Korean label: $word');
    return WordItem.fromRow(
      row,
      englishLabel: isTarget ? WordRelations.plainTargetName(word) : null,
      koreanLabel: isTarget ? label.split(' (').first : label,
    );
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
      if (fresh.length <
              stage.difficulty.cardsRequired - (carry == null ? 0 : 1) ||
          !stock.every(seen.add) ||
          !seen.add(result) ||
          (result == stage.target) != (index == rows.length - 1)) {
        throw const FormatException('Invalid round inventory or answer.');
      }

      final alternative = row.length > 3 ? words[row[3] as int] : null;
      final groupCount =
          stage.difficulty.cardsRequired - (carry == null ? 0 : 1);
      final groups = <List<WordItem>>[
        if (carry != null) [carry],
        for (final card in fresh.take(groupCount)) [card],
      ];
      for (final card in fresh.skip(groupCount)) {
        final offset = carry == null ? 0 : 1;
        final compatible =
            groups
                .skip(offset)
                .where((group) => group.first.attribute == card.attribute)
                .firstOrNull;
        compatible?.add(card);
      }
      if (alternative != null &&
          groups.every((group) => group.length == 1) &&
          fresh.length > groupCount) {
        groups.last.add(fresh[groupCount]);
      }
      if (stage.pack == 0 &&
          stage.position == 0 &&
          index < WordRelations.supplies.length) {
        final names = stock.map(WordRelations.materialKey).toSet();
        stock.addAll(
          WordRelations.supplies[index].where(
            (item) => names.add(WordRelations.materialKey(item)),
          ),
        );
      }
      if (index == 0) {
        final minimum = switch (stage.difficulty) {
          Difficulty.easy => 8,
          Difficulty.normal => 12,
          Difficulty.hard => 20,
        };
        final names = stock.map(WordRelations.materialKey).toSet();
        final extras = WordRelations.starterExtras;
        for (
          var offset = 0;
          offset < extras.length && stock.length < minimum;
          offset++
        ) {
          final candidate =
              extras[(stage.pack * 3 + stage.position + offset) %
                  extras.length];
          if (names.add(WordRelations.materialKey(candidate))) {
            stock.add(candidate);
          }
        }
      }
      stock.shuffle(math.Random(result.word.hashCode ^ index));
      rounds.add(
        PuzzleRound(
          CombinationRule(
            groups: groups,
            result: result,
            alternate: alternative,
          ),
          stock,
          index + 1,
        ),
      );
      carry = result;
    }
    return List.unmodifiable(rounds);
  }

  late final List<WordItem> catalog = List.unmodifiable(
    ({
        for (final item in [
          ..._words,
          ...WordRelations.supplies.expand((row) => row),
          ...WordRelations.starterExtras,
          ...WordRelations.hidden.values,
          ...WordRelations.mixtures,
        ])
          WordRelations.collectionKey(item.label): item,
      }.values.toList()
      ..sort((a, b) => a.label.compareTo(b.label))),
  );

  double _cosine(String word, String target) {
    final left = _unitVectors[word];
    final right = _unitVectors[target];
    if (left == null || right == null) return 0;
    var dot = 0.0;
    for (var i = 0; i < left.length; i++) {
      dot += left[i] * right[i];
    }
    return dot.clamp(0.0, 1.0).toDouble();
  }

  double _semantic(String word, String target) =>
      WordRelations.semanticScore(word, target, _cosine(word, target));

  int proximity(String word, String target) =>
      _similarities.putIfAbsent((word, target), () {
        if (word == target) return 100;
        return (_semantic(word, target) * WordRelations.weights.offPathCeiling)
            .round();
      });

  int cardProximity(WordItem item, Stage stage) =>
      item.derivedProximity ?? proximity(item.word, stage.targetWord);

  CraftOutcome craft(
    Stage stage,
    PuzzleRound round,
    List<WordItem> ingredients,
  ) {
    final rule = round.rule;
    final matches = rule.matches(ingredients);
    final hidden = matches ? null : WordRelations.combine(ingredients);
    final WordItem result;
    final bool reached;
    final int score;
    if (matches) {
      final output = rule.resultFor(ingredients);
      reached = output.word == stage.targetWord;
      final weights = WordRelations.weights;
      final band = (weights.pathCeiling - weights.pathFloor) / stage.parSteps;
      final base = weights.pathFloor + (band * (round.number - 1)).floor();
      final semanticBonus =
          (math.max(0.0, band - 1) * _semantic(output.word, stage.targetWord))
              .floor();
      score = reached ? 100 : base + semanticBonus;
      result = output.withRoute(
        substitute: output.recipeSource,
        proximity: score,
      );
    } else {
      reached = false;
      final output = hidden ?? WordRelations.fallback(ingredients);
      final represented =
          ingredients
              .where((item) => rule.slot(item) != null)
              .map((item) => item.recipeCard)
              .toList()
            ..sort(
              (a, b) =>
                  rule.slot(a)!.compareTo(rule.slot(b)!) != 0
                      ? rule.slot(a)!.compareTo(rule.slot(b)!)
                      : a.word.compareTo(b.word),
            );
      score =
          proximity(
            output.word,
            stage.targetWord,
          ).clamp(0, WordRelations.weights.offPathCeiling).toInt();
      result = output.withRoute(
        substitute: represented.firstOrNull,
        proximity: score,
      );
    }
    final occupied = ingredients.map(rule.slot).toSet();
    return CraftOutcome(
      ingredients: List.unmodifiable(ingredients),
      result: result,
      proximity: score,
      isTargetReached: reached,
      isRecipeMatch: matches,
      isHidden: hidden != null,
      missingAttributes:
          matches
              ? const []
              : List.unmodifiable([
                for (final (index, group) in rule.groups.indexed)
                  if (!occupied.contains(index)) group.first.attribute,
              ]),
      lowRelevance:
          matches
              ? 0
              : ingredients.where((item) {
                return rule.slot(item) == null &&
                    cardProximity(item, stage) <
                        WordRelations.weights.offPathCeiling ~/ 2;
              }).length,
    );
  }
}
