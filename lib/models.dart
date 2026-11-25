enum Difficulty {
  easy(4),
  normal(8),
  hard(16);

  const Difficulty(this.cardsRequired);

  final int cardsRequired;
}

enum WordAttribute {
  material('재료'),
  energy('에너지'),
  tool('도구'),
  environment('환경'),
  component('부품'),
  phenomenon('현상');

  const WordAttribute(this.label);

  final String label;
}

class WordItem {
  const WordItem(this.word, this.emoji, this.attribute);

  factory WordItem.fromJson(
    Map<String, dynamic> json, {
    String wordKey = 'word',
  }) => WordItem(
    json[wordKey] as String,
    json['emoji'] as String,
    WordAttribute.values.byName(json['attribute'] as String? ?? 'material'),
  );

  final String word;
  final String emoji;
  final WordAttribute attribute;
}

class CombinationRule {
  const CombinationRule(this.result, this.note, this.hint);

  factory CombinationRule.fromJson(Map<String, dynamic> json) =>
      CombinationRule(
        WordItem.fromJson(json, wordKey: 'resultWord'),
        json['note'] as String,
        json['hint'] as String?,
      );

  final WordItem result;
  final String note;
  final String? hint;

  static String key(Iterable<String> words) =>
      (words.toList()..sort()).join('|');
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
    required this.ingredients,
    required this.result,
    required this.note,
    required this.hint,
    required this.proximity,
    required this.isTargetReached,
  });

  final List<WordItem> ingredients;
  final WordItem? result;
  final String note;
  final String? hint;
  final int? proximity;
  final bool isTargetReached;

  String get equation =>
      '${ingredients.map((item) => item.word).join(' + ')} → ${result?.word ?? '조합 불가'}';
}
