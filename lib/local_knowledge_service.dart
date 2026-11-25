import 'dart:convert';
import 'dart:math' as math;

import 'models.dart';

class LocalKnowledgeService {
  LocalKnowledgeService._(this.stages, this._unitVectors);

  final List<Stage> stages;
  final Map<String, List<double>> _unitVectors;
  final _similarities = <(String, String), int>{};
  final _outcomes = <(int, String, String), CraftOutcome>{};

  static Future<LocalKnowledgeService> load(
    Future<String> Function(String) readAsset,
  ) async {
    final assets = await Future.wait([
      readAsset('assets/stages.json'),
      readAsset('assets/embeddings.json'),
    ]);
    final stages = (jsonDecode(assets[0]) as List)
        .map((json) => Stage.fromJson(json as Map<String, dynamic>))
        .toList();
    if (stages.isEmpty ||
        stages.map((stage) => stage.id).toSet().length != stages.length ||
        stages.any((stage) => stage.parSteps < 1)) {
      throw const FormatException('스테이지 ID 또는 기준 횟수가 올바르지 않습니다.');
    }

    final vectors = <String, List<double>>{};
    int? dimensions;
    for (final entry
        in (jsonDecode(assets[1]) as Map<String, dynamic>).entries) {
      final vector = (entry.value as List).map((n) => (n as num).toDouble());
      final norm = math.sqrt(vector.fold<double>(0, (sum, n) => sum + n * n));
      dimensions ??= vector.length;
      if (vector.length != dimensions || !norm.isFinite || norm == 0) {
        throw FormatException('잘못된 임베딩 벡터: ${entry.key}');
      }
      vectors[entry.key] = vector.map((n) => n / norm).toList();
    }
    for (final stage in stages) {
      final words = {
        stage.targetWord,
        ...stage.acceptedAnswers,
        ...stage.initialWords.map((item) => item.word),
        ...stage.rules.values.map((rule) => rule.result.word),
      };
      if (stage.initialWords.length < 4 ||
          stage.initialWords.length > 5 ||
          stage.initialWords.map((item) => item.word).toSet().length !=
              stage.initialWords.length ||
          !words.every(vectors.containsKey)) {
        throw FormatException('스테이지 ${stage.id}의 단어 데이터가 올바르지 않습니다.');
      }
      for (final key in stage.rules.keys) {
        final pair = key.split('|');
        if (pair.length != 2 ||
            pair.first == pair.last ||
            !pair.every(words.contains) ||
            key != CombinationRule.key(pair.first, pair.last)) {
          throw FormatException('잘못된 조합 키: $key');
        }
      }
    }
    return LocalKnowledgeService._(List.unmodifiable(stages), vectors);
  }

  int proximity(String word, String target) {
    final key = word.compareTo(target) <= 0 ? (word, target) : (target, word);
    return _similarities.putIfAbsent(key, () {
      final left = _unitVectors[word];
      final right = _unitVectors[target];
      if (left == null || right == null) return 0;
      var dot = 0.0;
      for (var i = 0; i < left.length; i++) {
        dot += left[i] * right[i];
      }
      return (dot.clamp(0.0, 1.0) * 100).round();
    });
  }

  CraftOutcome craft(Stage stage, WordItem left, WordItem right) {
    final pair = CombinationRule.key(left.word, right.word);
    return _outcomes.putIfAbsent((stage.id, left.word, right.word), () {
      final rule = stage.rules[pair];
      final result = rule?.result;
      return CraftOutcome(
        left: left,
        right: right,
        result: result,
        note: rule?.note ?? '이 두 단어는 조합할 수 없어요.',
        proximity: result == null
            ? null
            : proximity(result.word, stage.targetWord),
        isTargetReached:
            result != null &&
            (result.word == stage.targetWord ||
                stage.acceptedAnswers.contains(result.word)),
      );
    });
  }
}
