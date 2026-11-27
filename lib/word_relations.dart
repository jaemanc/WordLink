import 'models.dart';

class SimilarityWeights {
  const SimilarityWeights({
    this.embedding = .32,
    this.context = .28,
    this.synonym = .20,
    this.association = .20,
    this.antonymPenalty = .20,
    this.offPathCeiling = 54,
    this.pathFloor = 57,
    this.pathCeiling = 98,
  });

  final double embedding, context, synonym, association, antonymPenalty;
  final int offPathCeiling, pathFloor, pathCeiling;
}

class WordRelations {
  static const weights = SimilarityWeights();

  static const hidden = <String, WordItem>{
    'fire|water': WordItem(
      'Steam',
      '♨️',
      WordAttribute.phenomenon,
      koreanLabel: '수증기',
    ),
    'computer|human': WordItem(
      'Programmer',
      '🧑‍💻',
      WordAttribute.component,
      koreanLabel: '프로그래머',
    ),
    'coffee|programmer': WordItem(
      'Coding',
      '⌨️',
      WordAttribute.phenomenon,
      koreanLabel: '코딩',
    ),
    'coding|computer': WordItem(
      'Software',
      '💾',
      WordAttribute.component,
      koreanLabel: '소프트웨어',
    ),
    'flour|water': WordItem(
      'Paste',
      '🥣',
      WordAttribute.material,
      koreanLabel: '풀',
    ),
    'salt|water': WordItem(
      'Brine',
      '🫙',
      WordAttribute.material,
      koreanLabel: '소금물',
    ),
    'sand|water': WordItem(
      'Wet Sand',
      '🏖️',
      WordAttribute.material,
      koreanLabel: '젖은 모래',
    ),
    'paper|water': WordItem(
      'Pulp',
      '📄',
      WordAttribute.material,
      koreanLabel: '종이 펄프',
    ),
    'fire|wood': WordItem(
      'Ash',
      '🔥',
      WordAttribute.material,
      koreanLabel: '재',
    ),
    'coil|magnet|wire': WordItem(
      'Generator',
      '⚙️',
      WordAttribute.tool,
      koreanLabel: '발전기',
    ),
    'battery|bulb|switch|wire': WordItem(
      'Circuit',
      '💡',
      WordAttribute.component,
      koreanLabel: '회로',
    ),
    'lemon|sugar|water': WordItem(
      'Lemonade',
      '🍋',
      WordAttribute.material,
      koreanLabel: '레모네이드',
    ),
    'clay|fire': WordItem(
      'Ceramic',
      '🏺',
      WordAttribute.material,
      koreanLabel: '도자기',
    ),
    'paper|string|wood': WordItem(
      'Kite',
      '🪁',
      WordAttribute.component,
      koreanLabel: '연',
    ),
    'lens|light': WordItem(
      'Focused Beam',
      '🔦',
      WordAttribute.phenomenon,
      koreanLabel: '집속 광선',
    ),
  };

  static const supplies = [
    [
      WordItem('Fire', '🔥', WordAttribute.energy, koreanLabel: '불'),
      WordItem('Water', '💧', WordAttribute.environment, koreanLabel: '물'),
    ],
    [
      WordItem('Human', '🧑', WordAttribute.component, koreanLabel: '사람'),
      WordItem('Computer', '💻', WordAttribute.tool, koreanLabel: '컴퓨터'),
    ],
    [WordItem('Coffee', '☕', WordAttribute.material, koreanLabel: '커피')],
  ];

  static const starterExtras = [
    WordItem('Water', '💧', WordAttribute.environment, koreanLabel: '물'),
    WordItem('Salt', '🧂', WordAttribute.material, koreanLabel: '소금'),
    WordItem('Flour', '🌾', WordAttribute.material, koreanLabel: '밀가루'),
    WordItem('Fire', '🔥', WordAttribute.energy, koreanLabel: '불'),
    WordItem('Paper', '📄', WordAttribute.material, koreanLabel: '종이'),
    WordItem('String', '🧵', WordAttribute.material, koreanLabel: '실'),
    WordItem('Wood', '🪵', WordAttribute.material, koreanLabel: '나무'),
    WordItem('Clay', '🏺', WordAttribute.material, koreanLabel: '점토'),
    WordItem('Sand', '🏖️', WordAttribute.environment, koreanLabel: '모래'),
    WordItem('Light', '💡', WordAttribute.energy, koreanLabel: '빛'),
    WordItem('Lens', '🔍', WordAttribute.tool, koreanLabel: '렌즈'),
    WordItem('Wire', '⚙️', WordAttribute.component, koreanLabel: '전선'),
  ];

  static const _saltCoatedAssembly = WordItem(
    'Salt-Coated Assembly',
    '🧂',
    WordAttribute.component,
    koreanLabel: '소금이 입혀진 조립체',
  );
  static const _rinsedAssembly = WordItem(
    'Rinsed Assembly',
    '💧',
    WordAttribute.component,
    koreanLabel: '씻어낸 조립체',
  );

  static const mixtures = [
    WordItem('Mixture', '🧪', WordAttribute.material, koreanLabel: '혼합물'),
    WordItem('Solution', '💧', WordAttribute.material, koreanLabel: '용액'),
    WordItem('Assembly', '⚙️', WordAttribute.component, koreanLabel: '조립체'),
    WordItem(
      'Heated Sample',
      '🌡️',
      WordAttribute.material,
      koreanLabel: '가열 시료',
    ),
    WordItem('Residue', '🪨', WordAttribute.material, koreanLabel: '잔류물'),
    _saltCoatedAssembly,
    _rinsedAssembly,
    WordItem('Compound', '⚗️', WordAttribute.material, koreanLabel: '화합물'),
    WordItem('Composite', '🧱', WordAttribute.material, koreanLabel: '복합재'),
  ];

  static final _batch = RegExp(
    r'^(?:(?:unsorted|reserve|spare) )?(?:base|sorted|measured|bench|reserve|prepared|spare|marked|fitted|selected|packed|sample|tested|workshop|checked|fresh|refined|support|finished|final) ',
  );
  static final _edition = RegExp(
    r' (?:compact|field|workshop|select|heritage|utility|premium|limited|showcase) series$',
    caseSensitive: false,
  );
  static final _style = RegExp(
    r'^(?:limited edition|classic|experimental|compact|custom|standard|deluxe|special|prototype|signature) ',
    caseSensitive: false,
  );

  static String plainTargetName(String title) =>
      title.replaceFirst(_style, '').replaceFirst(_edition, '');

  static String normalize(String word) => word.toLowerCase().trim();
  static String collectionKey(String title) =>
      normalize(plainTargetName(title));

  static String materialKey(WordItem word) =>
      normalize(word.word).replaceFirst(_batch, '');

  static String recipeKey(List<WordItem> ingredients) {
    final keys = ingredients.map(materialKey).toList()..sort();
    return keys.join('|');
  }

  static WordItem? combine(List<WordItem> ingredients) =>
      hidden[recipeKey(ingredients)];

  static WordItem fallback(List<WordItem> ingredients) {
    final names = ingredients.map(materialKey).toSet();
    final attributes = ingredients.map((item) => item.attribute).toSet();
    final hasWater = names.contains('water');
    final hasParts =
        attributes.contains(WordAttribute.component) ||
        attributes.contains(WordAttribute.tool);
    final preferred = [
      if (names.contains('salt') && names.contains('assembly'))
        _saltCoatedAssembly,
      if (hasWater && names.contains(materialKey(_saltCoatedAssembly)))
        _rinsedAssembly,
      if (hasWater && attributes.contains(WordAttribute.material)) mixtures[1],
      if (attributes.contains(WordAttribute.energy)) mixtures[3],
      if (hasParts) mixtures[2],
      ...mixtures,
    ];
    final koreanInputs = {for (final item in ingredients) item.koreanLabel};
    return preferred.firstWhere(
      (result) =>
          !names.contains(materialKey(result)) &&
          !koreanInputs.contains(result.koreanLabel),
    );
  }

  static final _contexts = _index([
    'bread|flour|water|dough|yeast|crust|loaf|oven|paste',
    'steam|fire|water|heat|kettle|boiling',
    'computer|programmer|coding|software|coffee|keyboard',
    'candle|wax|wick|fire|mould',
    'kite|paper|string|wood|bamboo|wind',
    'lens|telescope|microscope|light|mirror|focused beam',
    'radio|coil|antenna|signal|circuit|wire|battery|generator',
    'clay|ceramic|plant pot|kiln|glaze|fire',
    'water filter|desalination plant|water|brine|membrane|solution|salt',
    'lemonade|lemon|sugar|water|solution',
  ]);
  static final _synonyms = _index([
    'bread|loaf',
    'coding|programming|software development',
    'steam|water vapor',
    'salt|sodium chloride',
    'bulb|lamp',
    'mixture|blend',
    'mould|mold',
    'brine|salt solution',
  ]);
  static final _materials = _index([
    'bread|dough|flour|yeast|loaf|crust',
    'steam|water|kettle|heat',
    'candle|wick|wax',
    'kite|paper|string|bamboo',
    'ceramic|clay|kiln',
    'generator|coil|magnet|wire|circuit',
    'programmer|computer|coding|software',
    'water filter|carbon|gravel|membrane|water',
    'focused beam|lens|light|mirror|telescope|microscope',
    'brine|salt|water|solution',
  ]);
  static const _opposites = {
    'cold|hot',
    'dark|light',
    'dry|wet',
    'fresh|stale',
    'closed|open',
    'cooling|heating',
    'empty|full',
  };

  static Map<String, Set<int>> _index(List<String> groups) {
    final result = <String, Set<int>>{};
    for (final (index, group) in groups.indexed) {
      for (final key in group.split('|')) {
        (result[key] ??= {}).add(index);
      }
    }
    return result;
  }

  static Iterable<String> _terms(String value) sync* {
    final phrase = normalize(
      value,
    ).replaceFirst(_batch, '').replaceFirst(_edition, '');
    yield phrase;
    final tokens = phrase.split(' ');
    for (var index = 1; index < tokens.length; index++) {
      yield tokens.skip(index).join(' ');
    }
    yield* tokens;
  }

  static bool _related(
    Map<String, Set<int>> index,
    List<String> left,
    List<String> right,
  ) {
    final groups = {for (final term in left) ...?index[term]};
    return right.any((term) => index[term]?.any(groups.contains) ?? false);
  }

  static double semanticScore(String word, String goal, double cosine) {
    final left = _terms(word).toList();
    final right = _terms(goal).toList();
    final antonym = left.any(
      (a) => right.any(
        (b) => _opposites.contains(a.compareTo(b) <= 0 ? '$a|$b' : '$b|$a'),
      ),
    );
    return (weights.embedding * cosine +
            (_related(_contexts, left, right) ? weights.context : 0) +
            (_related(_synonyms, left, right) ? weights.synonym : 0) +
            (_related(_materials, left, right) ? weights.association : 0) -
            (antonym ? weights.antonymPenalty : 0))
        .clamp(0.0, 1.0)
        .toDouble();
  }
}
