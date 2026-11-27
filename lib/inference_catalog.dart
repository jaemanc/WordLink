import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final inferenceCatalogProvider = FutureProvider(
  (ref) => InferenceCatalog.load(),
);

class InferenceWord {
  const InferenceWord(this.english, this.korean);
  final String english;
  final String korean;

  String label(bool koreanMode) => koreanMode ? korean : english;
}

class InferenceBoard {
  const InferenceBoard(
    this.target,
    this.starters,
    this.scores,
    this.minimumMoves,
  );
  final int target;
  final List<int> starters;
  final List<int> scores;
  final int minimumMoves;

  int proximity(int word) => scores[word];

  int starsFor(int moves) =>
      moves <= minimumMoves
          ? 3
          : moves <= minimumMoves + 2
          ? 2
          : 1;
}

class InferenceCatalog {
  InferenceCatalog._(this.words, this._recipes, this._scores, this.handSize);

  final List<InferenceWord> words;
  final Map<(int, int), int> _recipes;
  final Map<int, List<int>> _scores;
  final int handSize;
  final _packs = <int, List<List<int>>>{};
  final _random = Random();

  late final _english = _wordIndex(false);
  late final _korean = _wordIndex(true);

  static Future<InferenceCatalog> load() async {
    final json =
        jsonDecode(await rootBundle.loadString('assets/inference/engine.json'))
            as Map<String, dynamic>;
    final words = [
      for (final row in (json['words'] as List).cast<List<dynamic>>())
        InferenceWord(row[0] as String, row[1] as String),
    ];
    final recipes = <(int, int), int>{};
    for (final row in (json['recipes'] as List).cast<List<dynamic>>()) {
      if (row.length != 3 ||
          row.any((id) => id is! int || id < 0 || id >= words.length)) {
        throw FormatException('Invalid inference recipe: $row');
      }
      final a = row[0] as int;
      final b = row[1] as int;
      final result = row[2] as int;
      final key = _key(a, b);
      if (a == b || result == a || result == b || recipes.containsKey(key)) {
        throw FormatException('Invalid inference recipe: $row');
      }
      recipes[key] = result;
    }
    return InferenceCatalog._(List.unmodifiable(words), recipes, {
      for (final entry in (json['scores'] as Map<String, dynamic>).entries)
        int.parse(entry.key): List<int>.unmodifiable(entry.value as List),
    }, json['handSize'] as int);
  }

  static (int, int) _key(int a, int b) => a < b ? (a, b) : (b, a);
  int? recipeResult(int a, int b) => _recipes[_key(a, b)];

  (int, int)? suggestPair(InferenceBoard board, Set<int> available) {
    (int, int)? best;
    (int, int)? answerPair;
    var bestScore = -1;
    for (final entry in _recipes.entries) {
      final (a, b) = entry.key;
      if (!available.contains(a) ||
          !available.contains(b) ||
          available.contains(entry.value)) {
        continue;
      }
      if (entry.value == board.target) {
        answerPair ??= entry.key;
        continue;
      }
      final score = board.proximity(entry.value);
      if (score > bestScore) {
        best = entry.key;
        bestScore = score;
      }
    }
    return best ?? answerPair;
  }

  static String _normalize(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  Map<String, List<int>> _wordIndex(bool korean) {
    final result = <String, List<int>>{};
    for (final (index, word) in words.indexed) {
      (result[_normalize(word.label(korean))] ??= []).add(index);
    }
    return result;
  }

  List<int> find(String word, bool korean) =>
      (korean ? _korean : _english)[_normalize(word)] ?? const [];

  String recordKey(int difficulty, InferenceBoard board) => jsonEncode([
    difficulty,
    words[board.target].english,
    board.starters.map((id) => words[id].english).toList()..sort(),
  ]);

  Future<List<List<int>>> _loadPack(int difficulty) async {
    final cached = _packs[difficulty];
    if (cached != null) return cached;
    final json =
        jsonDecode(
              await rootBundle.loadString(
                'assets/inference/level_$difficulty.json',
                cache: false,
              ),
            )
            as List;
    final pack = List<List<int>>.unmodifiable(
      json.map((row) => List<int>.unmodifiable(row as List)),
    );
    return _packs[difficulty] = pack;
  }

  Future<InferenceBoard?> next(
    int difficulty, {
    int? previousTarget,
    List<int>? requestedTargets,
  }) async {
    final pack = await _loadPack(difficulty);
    final candidates =
        pack
            .where(
              (row) =>
                  requestedTargets != null
                      ? requestedTargets.contains(row.first)
                      : row.first != previousTarget,
            )
            .toList();
    while (candidates.isNotEmpty) {
      final chosen = candidates.removeAt(_random.nextInt(candidates.length));
      if (chosen.length != handSize + 2 || chosen.last <= 0) continue;
      final target = chosen.first;
      final scores = _scores[target];
      final starters = List<int>.unmodifiable(chosen.getRange(1, handSize + 1));
      if (scores != null && _canPlay(target, starters, scores)) {
        return InferenceBoard(target, starters, scores, chosen.last);
      }
    }
    return null;
  }

  bool _canPlay(int target, List<int> starters, List<int> scores) {
    final reached = starters.toSet();
    if (starters.length != handSize ||
        reached.length != handSize ||
        reached.contains(target) ||
        starters.any(
          (word) => word < 0 || word >= scores.length || scores[word] < 10,
        )) {
      return false;
    }
    while (true) {
      final size = reached.length;
      for (final entry in _recipes.entries) {
        final (a, b) = entry.key;
        if (reached.contains(a) && reached.contains(b)) {
          reached.add(entry.value);
        }
      }
      if (reached.contains(target)) return true;
      if (reached.length == size) return false;
    }
  }
}
