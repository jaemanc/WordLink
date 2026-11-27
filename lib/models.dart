enum Difficulty {
  easy(2, 10),
  normal(3, 15),
  hard(4, 20);

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
  const WordItem(
    this.word,
    this.emoji,
    this.attribute, {
    String? label,
    this.koreanLabel,
    this.recipeSource,
    this.derivedProximity,
  }) : label = label ?? word;

  factory WordItem.fromRow(
    List<dynamic> row, {
    String? englishLabel,
    String? koreanLabel,
  }) => WordItem(
    row[0] as String,
    row[1] as String,
    WordAttribute.values.byName(row[2] as String),
    label: englishLabel ?? (row.length > 3 ? row[3] as String : null),
    koreanLabel: koreanLabel,
  );

  final String word;
  final String emoji;
  final WordAttribute attribute;
  final String label;
  final String? koreanLabel;
  final WordItem? recipeSource;
  final int? derivedProximity;

  WordItem get recipeCard => recipeSource ?? this;

  WordItem withRoute({WordItem? substitute, int? proximity}) => WordItem(
    word,
    emoji,
    attribute,
    label: label,
    koreanLabel: koreanLabel,
    recipeSource: substitute ?? recipeCard,
    derivedProximity: proximity,
  );

  WordItem replacement() => WordItem(
    word,
    emoji,
    attribute,
    label: 'Spare ${recipeCard.label}',
    koreanLabel: '예비 ${recipeCard.koreanLabel ?? recipeCard.label}',
    recipeSource: recipeCard,
  );
}

class CombinationRule {
  CombinationRule({
    required List<List<WordItem>> groups,
    required this.result,
    this.alternate,
  }) : groups = List.unmodifiable(groups.map(List<WordItem>.unmodifiable)),
       _slots = {
         for (final (index, group) in groups.indexed)
           for (final item in group) item: index,
       };

  final List<List<WordItem>> groups;
  final Map<WordItem, int> _slots;
  final WordItem result;
  final WordItem? alternate;
  List<WordItem> get ingredients => [for (final group in groups) group.first];

  int? slot(WordItem item) => _slots[item.recipeCard];

  bool matches(List<WordItem> selection) {
    final selectedSlots = selection.map(slot).toSet();
    return selection.length == groups.length &&
        selectedSlots.length == groups.length &&
        !selectedSlots.contains(null);
  }

  WordItem resultFor(List<WordItem> selection) {
    final other = alternate;
    if (other != null &&
        selection.any((item) {
          final index = slot(item)!;
          return item.recipeCard != groups[index].first;
        }))
      return other.withRoute(substitute: result);
    return result;
  }

  Iterable<WordItem> missingFrom(Iterable<WordItem> cards) sync* {
    final present = cards.map(slot).toSet();
    for (final (index, group) in groups.indexed) {
      if (!present.contains(index)) yield group.first.replacement();
    }
  }
}

class PuzzleRound {
  PuzzleRound(this.rule, List<WordItem> stock, this.number)
    : stock = List.unmodifiable(stock);

  final CombinationRule rule;
  final List<WordItem> stock;
  final int number;
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
    required this.isRecipeMatch,
    this.isHidden = false,
    this.missingAttributes = const [],
    this.lowRelevance = 0,
  });

  final List<WordItem> ingredients;
  final WordItem result;
  final int proximity;
  final bool isTargetReached;
  final bool isRecipeMatch;
  final bool isHidden;
  final List<WordAttribute> missingAttributes;
  final int lowRelevance;

  String get equation =>
      '${ingredients.map((item) => item.label).join(' + ')} → ${result.label}';
}
