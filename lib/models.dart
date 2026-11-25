enum Difficulty { easy, normal, hard }

class WordItem {
  const WordItem(this.word, this.emoji);

  factory WordItem.fromJson(Map<String, dynamic> json) =>
      WordItem(json['word'] as String, json['emoji'] as String);

  final String word;
  final String emoji;
}

class CombinationRule {
  const CombinationRule(this.result, this.note);

  factory CombinationRule.fromJson(Map<String, dynamic> json) =>
      CombinationRule(
        WordItem(json['resultWord'] as String, json['emoji'] as String),
        json['note'] as String,
      );

  final WordItem result;
  final String note;

  static String key(String left, String right) =>
      left.compareTo(right) <= 0 ? '$left|$right' : '$right|$left';
}

class Stage {
  Stage.fromJson(Map<String, dynamic> json)
    : id = json['id'] as int,
      difficulty = Difficulty.values.byName(json['difficulty'] as String),
      targetWord = json['targetWord'] as String,
      targetEmoji = json['targetEmoji'] as String,
      initialWords = List.unmodifiable(
        (json['initialWords'] as List).map(
          (item) => WordItem.fromJson(item as Map<String, dynamic>),
        ),
      ),
      parSteps = json['parSteps'] as int,
      rules = Map.unmodifiable(
        (json['rules'] as Map<String, dynamic>).map(
          (key, value) => MapEntry(
            key,
            CombinationRule.fromJson(value as Map<String, dynamic>),
          ),
        ),
      ),
      acceptedAnswers = Set.unmodifiable(
        (json['acceptedAnswers'] as List).cast<String>(),
      );

  final int id;
  final Difficulty difficulty;
  final String targetWord;
  final String targetEmoji;
  final List<WordItem> initialWords;
  final int parSteps;
  final Map<String, CombinationRule> rules;
  final Set<String> acceptedAnswers;
}

class CraftOutcome {
  const CraftOutcome({
    required this.left,
    required this.right,
    required this.result,
    required this.note,
    required this.proximity,
    required this.isTargetReached,
  });

  final WordItem left;
  final WordItem right;
  final WordItem? result;
  final String note;
  final int? proximity;
  final bool isTargetReached;

  String get equation =>
      '${left.word} + ${right.word} → ${result?.word ?? '조합 불가'}';
}
