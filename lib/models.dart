enum Difficulty {
  easy(4, 10),
  normal(8, 15),
  hard(16, 20);

  const Difficulty(this.cardsRequired, this.parSteps);

  final int cardsRequired;
  final int parSteps;
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

  factory WordItem.fromRow(List<dynamic> row) => WordItem(
    row[0] as String,
    row[1] as String,
    WordAttribute.values.byName(row[2] as String),
  );

  final String word;
  final String emoji;
  final WordAttribute attribute;
}

class CombinationRule {
  CombinationRule({required List<WordItem> ingredients, required this.result})
    : ingredients = List.unmodifiable(ingredients),
      _ingredientSet = ingredients.toSet();

  final List<WordItem> ingredients;
  final Set<WordItem> _ingredientSet;
  final WordItem result;

  bool matches(List<WordItem> selection) =>
      selection.length == ingredients.length &&
      selection.toSet().length == ingredients.length &&
      selection.every(_ingredientSet.contains);
}

class PuzzleRound {
  PuzzleRound(this.rule, List<WordItem> stock)
    : stock = List.unmodifiable(stock);

  final CombinationRule rule;
  final List<WordItem> stock;
}

class Stage {
  const Stage(this.id, this.difficulty, this.target, this.pack, this.position);

  final int id;
  final Difficulty difficulty;
  final WordItem target;
  final int pack;
  final int position;

  int get parSteps => difficulty.parSteps;
  String get targetWord => target.word;
  String get targetEmoji => target.emoji;
}

class CraftOutcome {
  const CraftOutcome({
    required this.ingredients,
    required this.result,
    required this.proximity,
    required this.isTargetReached,
  });

  final List<WordItem> ingredients;
  final WordItem? result;
  final int? proximity;
  final bool isTargetReached;

  String get equation =>
      '${ingredients.map((item) => item.word).join(' + ')} → ${result?.word ?? '조합 불가'}';
}
