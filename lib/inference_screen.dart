import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'campaign_progress.dart';
import 'craft_impact.dart';
import 'game_language.dart';
import 'inference_catalog.dart';
import 'models.dart';

class InferenceScreen extends ConsumerStatefulWidget {
  const InferenceScreen({super.key});

  @override
  ConsumerState<InferenceScreen> createState() => _InferenceScreenState();
}

enum _WordSort { proximity, recent, name }

class _InferenceScreenState extends ConsumerState<InferenceScreen>
    with SingleTickerProviderStateMixin {
  late final _selectionImpact = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );
  final _scroll = ScrollController();
  int _moves = 0;
  bool _newRecord = false;
  String? _stageKey;
  final _discovered = <int, int>{};
  final _craftDepth = <int, int>{};
  _WordSort _sort = _WordSort.proximity;
  int? _impactWord;

  InferenceBoard? _board;
  Difficulty _difficulty = Difficulty.easy;
  final _available = <int>{};
  final _tray = <int>[];
  final _selection = <int>[];
  final _history = <({List<int> inputs, int result})>[];
  String? _message;
  int? _recipeClue;
  bool _loading = true;
  bool _failedToLoad = false;
  bool _solved = false;

  bool get _exhausted => !_solved && _moves >= (_board?.maximumMoves ?? 1);
  bool get _finished => _solved || _exhausted;

  bool get _korean => Localizations.localeOf(context).languageCode == 'ko';
  String _tr(String korean, String english) =>
      gameText(context, korean, english);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _start(Difficulty.easy),
    );
  }

  @override
  void dispose() {
    _selectionImpact.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _start(Difficulty difficulty, {String? target}) async {
    if (!mounted) return;
    final korean = _korean;
    setState(() {
      _loading = true;
      _failedToLoad = false;
      _message = null;
      _recipeClue = null;
    });
    try {
      final catalog = await ref.read(inferenceCatalogProvider.future);
      final board = await catalog.next(
        difficulty.index,
        previousTarget: _difficulty == difficulty ? _board?.target : null,
        requestedTargets: target == null ? null : catalog.find(target, korean),
      );
      if (!mounted) return;
      await ref.read(progressProvider.future);
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (board == null) {
          _message = _tr(
            '이 난이도에서 조합할 수 있는 정답 목록에 없어요.',
            'That word has no verified puzzle at this difficulty.',
          );
          return;
        }
        _difficulty = difficulty;
        _board = board;
        _stageKey = catalog.recordKey(difficulty.index, board);
        _resetRun(board);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failedToLoad = true;
      });
    }
  }

  void _resetRun(InferenceBoard board) {
    _moves = 0;
    _newRecord = false;
    _message = null;
    _recipeClue = null;
    _selection.clear();
    _history.clear();
    _discovered.clear();
    _craftDepth.clear();
    _impactWord = null;
    _available
      ..clear()
      ..addAll(board.starters);
    _tray
      ..clear()
      ..addAll(board.starters);
    _solved = false;
  }

  void _toggle(int word) {
    if (_finished || _loading) return;
    final selecting = !_selection.contains(word);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    setState(() {
      _message = null;
      if (!selecting) {
        _selection.remove(word);
        if (_impactWord == word) _impactWord = null;
        return;
      }
      if (_selection.length == 2) _selection.removeLast();
      _selection.add(word);
      _impactWord = reduceMotion ? null : word;
    });
    if (selecting) {
      if (!reduceMotion) _selectionImpact.forward(from: 0);
      unawaited(HapticFeedback.heavyImpact());
      unawaited(playImpactSound(cleared: false));
    }
  }

  String _sortLabel(_WordSort sort) => switch (sort) {
    _WordSort.proximity => _tr('유사도순', 'Similarity'),
    _WordSort.recent => _tr('최근 발견순', 'Recently found'),
    _WordSort.name => _tr('이름 순', 'Name'),
  };

  void _sortWords(
    List<int> words,
    InferenceCatalog catalog,
    InferenceBoard board,
  ) {
    final korean = _korean;
    words.sort((a, b) {
      final order = switch (_sort) {
        _WordSort.proximity => _score(board, b).compareTo(_score(board, a)),
        _WordSort.recent => (_discovered[b] ?? 0).compareTo(
          _discovered[a] ?? 0,
        ),
        _WordSort.name => 0,
      };
      if (order != 0) return order;
      final nameOrder = catalog.words[a]
          .label(korean)
          .toLowerCase()
          .compareTo(catalog.words[b].label(korean).toLowerCase());
      return nameOrder == 0 ? a.compareTo(b) : nameOrder;
    });
  }

  Widget _withSelectionImpact(Widget card, Color color) => AnimatedBuilder(
    animation: _selectionImpact,
    child: card,
    builder: (context, child) {
      final progress = _selectionImpact.value;
      if (progress >= 1) return child!;
      final recoil = 1 - Curves.easeOutCubic.transform(progress);
      return Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          Transform.scale(scale: 1 + .12 * recoil, child: child),
          IgnorePointer(
            child: CustomPaint(
              painter: ImpactBurstPainter(null, progress, color, false),
            ),
          ),
        ],
      );
    },
  );

  InferenceWord _word(InferenceCatalog catalog, int id) => catalog.words[id];

  int _score(InferenceBoard board, int id) => board.proximity(id);

  void _bringToTray(int limit, Iterable<int> words) {
    for (final word in words) {
      _tray.remove(word);
      _tray.insert(0, word);
    }
    if (_tray.length > limit) _tray.removeRange(limit, _tray.length);
  }

  void _combine(InferenceCatalog catalog) {
    if (_selection.length != 2 || _finished || _loading) return;
    final a = _selection[0];
    final b = _selection[1];
    final result = catalog.recipeResult(a, b);
    if (result == null) {
      setState(() {
        _moves++;
        if (_exhausted) {
          _selection.clear();
          _impactWord = null;
          _recipeClue = null;
          _message = null;
          return;
        }
        _message = _tr(
          '두 단어를 함께 설명하는 결과를 찾지 못했어요. 한 장을 바꿔 보세요.',
          'No known result connects both words. Try swapping one card.',
        );
      });
      HapticFeedback.lightImpact();
      if (_exhausted) {
        unawaited(_showFailure());
      } else if (_moves == _board!.minimumMoves + 1) {
        _scrollToSummary();
      }
      return;
    }
    _record(result, List.unmodifiable(_selection), handSize: catalog.handSize);
  }

  void _suggest(InferenceCatalog catalog, InferenceBoard board) {
    final pair = catalog.suggestPair(board, _available);
    if (pair == null) return;
    setState(() {
      _message = null;
      _recipeClue = pair.$1;
    });
  }

  void _record(int result, List<int> inputs, {int? handSize}) {
    final board = _board!;
    setState(() {
      _message = null;
      _recipeClue = null;
      _selection.clear();
      _impactWord = null;
      _history.add((inputs: inputs, result: result));
      if (handSize != null) {
        _moves++;
        if (_available.add(result)) {
          _discovered[result] = _history.length;
          _craftDepth[result] =
              1 +
              math.max(
                _craftDepth[inputs[0]] ?? 0,
                _craftDepth[inputs[1]] ?? 0,
              );
        }
        _bringToTray(handSize, [result]);
      }
      _solved = result == board.target;
      if (_solved) {
        _newRecord = ref
            .read(progressProvider.notifier)
            .recordInference(_stageKey!, _moves, board.starsFor(_moves));
      }
    });
    if (_solved) {
      HapticFeedback.heavyImpact();
    } else {
      HapticFeedback.selectionClick();
    }
    if (_solved || _moves == board.minimumMoves + 1) _scrollToSummary();
    if (_exhausted) unawaited(_showFailure());
  }

  int _bestSimilarity(InferenceBoard board) => _history.fold(
    0,
    (best, entry) => math.max(best, _score(board, entry.result)),
  );

  void _retry(InferenceBoard board) {
    setState(() => _resetRun(board));
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  Future<void> _showFailure() async {
    final board = _board!;
    final best = _bestSimilarity(board);
    final retry = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder:
          (dialogContext) => AlertDialog(
            icon: Icon(
              Icons.bolt_outlined,
              color: Theme.of(dialogContext).colorScheme.error,
            ),
            title: Text(_tr('조합 횟수를 모두 사용했어요', 'No combinations left')),
            content: Text(
              _tr('최고 유사도 $best%', 'Best similarity $best%'),
              textAlign: TextAlign.center,
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(_tr('재도전하기!', 'Try again!')),
              ),
            ],
          ),
    );
    if (retry == true && mounted && identical(_board, board) && _exhausted) {
      _retry(board);
    }
  }

  String? _categoryLabel(String? category) => switch (category) {
    'nature' => _tr('자연 현상', 'Natural phenomena'),
    'food' => _tr('음식·음료', 'Food & drinks'),
    'art' => _tr('미술·공예', 'Arts & crafts'),
    'plants' => _tr('식물·꽃', 'Plants & flowers'),
    'tools' => _tr('도구·기구', 'Tools & instruments'),
    'electricity' => _tr('전기·전자', 'Electricity & electronics'),
    'materials' => _tr('재료', 'Materials'),
    'transport' => _tr('이동 수단', 'Transportation'),
    'everyday' => _tr('생활용품', 'Everyday items'),
    _ => null,
  };

  void _scrollToSummary() {
    if (!_scroll.hasClients) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _scroll.jumpTo(0);
    } else {
      unawaited(
        _scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        ),
      );
    }
  }

  Future<String?> _askForWord({required bool setTarget}) {
    var text = '';
    return showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              setTarget
                  ? _tr('친구에게 낼 정답', 'Set a word for a friend')
                  : _tr('정답 추측', 'Guess the answer'),
            ),
            content: TextField(
              autofocus: true,
              autocorrect: false,
              onChanged: (value) => text = value,
              onSubmitted: (value) {
                if (value.trim().isNotEmpty) {
                  Navigator.of(context).pop(value.trim());
                }
              },
              decoration: InputDecoration(
                hintText: _tr('단어 입력', 'Enter a word'),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(_tr('취소', 'Cancel')),
              ),
              FilledButton(
                onPressed: () {
                  if (text.trim().isNotEmpty) {
                    Navigator.of(context).pop(text.trim());
                  }
                },
                child: Text(_tr('확인', 'Submit')),
              ),
            ],
          ),
    );
  }

  Future<void> _guess(InferenceCatalog catalog) async {
    final typed = await _askForWord(setTarget: false);
    if (!mounted || typed == null || _finished || _loading) return;
    final matches = catalog.find(typed, _korean);
    if (matches.isEmpty) {
      setState(
        () =>
            _message = _tr(
              '오프라인 사전에 없는 단어예요.',
              'That word is outside the offline dictionary.',
            ),
      );
      return;
    }
    final target = _board!.target;
    _record(matches.contains(target) ? target : matches.first, const []);
  }

  ({Color surface, Color accent}) _cardColors(
    int word,
  ) => switch (_craftDepth[word] ?? 0) {
    0 => (surface: const Color(0xff24484e), accent: const Color(0xff9ac6c7)),
    1 => (surface: const Color(0xff234b37), accent: const Color(0xff8ce8ac)),
    2 => (surface: const Color(0xff253e60), accent: const Color(0xff9ecbff)),
    3 => (surface: const Color(0xff49325d), accent: const Color(0xffe0b6ff)),
    _ => (surface: const Color(0xff554125), accent: const Color(0xffffd580)),
  };

  String _cardDetail(InferenceBoard board, int word) {
    final depth = _craftDepth[word];
    final level = depth == null ? _tr('기본', 'Base') : 'Lv.$depth';
    return '$level · ${_score(board, word)}%';
  }

  Future<void> _openReserve(
    InferenceCatalog catalog,
    InferenceBoard board,
  ) async {
    final reserves = _available.where((id) => !_tray.contains(id)).toList();
    _sortWords(reserves, catalog, board);
    final chosen = await showModalBottomSheet<int>(
      context: context,
      useSafeArea: true,
      builder:
          (context) => ListView.builder(
            itemCount: reserves.length,
            itemBuilder: (context, index) {
              final id = reserves[index];
              return ListTile(
                title: Text(_word(catalog, id).label(_korean)),
                tileColor: _cardColors(id).surface,
                trailing: Text(
                  _cardDetail(board, id),
                  style: TextStyle(color: _cardColors(id).accent),
                ),
                onTap: () => Navigator.of(context).pop(id),
              );
            },
          ),
    );
    if (mounted && chosen != null) {
      setState(() => _bringToTray(catalog.handSize, [chosen]));
    }
  }

  String _level(Difficulty value) => switch (value) {
    Difficulty.easy => _tr('쉬움', 'Easy'),
    Difficulty.normal => _tr('보통', 'Normal'),
    Difficulty.hard => _tr('어려움', 'Hard'),
  };

  Widget _stars(int count) => Semantics(
    label: _tr('별 3개 중 $count개', '$count of 3 stars'),
    child: ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var index = 0; index < 3; index++)
            Icon(
              index < count ? Icons.star_rounded : Icons.star_outline_rounded,
              color: const Color(0xffffd580),
            ),
        ],
      ),
    ),
  );

  Widget _runSummary(
    InferenceBoard board,
    StageRecord? record,
    int best,
    String? category,
  ) {
    final stars = board.starsFor(_moves);
    final nearLimit = board.maximumMoves - _moves <= 2;
    final errorColor = Theme.of(context).colorScheme.error;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Column(
      children: [
        Text(
          _tr(
            '최소 조합 ${board.minimumMoves}회',
            'Minimum ${board.minimumMoves} combinations',
          ),
          textAlign: TextAlign.center,
        ),
        Text(
          _tr(
            '조합 $_moves / ${board.maximumMoves}회',
            'Combinations $_moves / ${board.maximumMoves}',
          ),
          style: TextStyle(
            color: nearLimit ? errorColor : null,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        if (!_solved && _moves > board.minimumMoves && category != null)
          Text(
            _tr('범주 힌트 · $category', 'Category hint · $category'),
            textAlign: TextAlign.center,
          ),
        if (_exhausted)
          Text(_tr('최고 유사도 $best%', 'Best similarity $best%'))
        else if (_solved)
          TweenAnimationBuilder<double>(
            tween: Tween(begin: reduceMotion ? 1 : .45, end: 1),
            duration:
                reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 450),
            curve: Curves.easeOutBack,
            builder:
                (context, scale, child) =>
                    Transform.scale(scale: scale, child: child),
            child: Column(
              children: [
                _stars(stars),
                if (_newRecord)
                  Text(
                    _tr('신기록!', 'New record!'),
                    style: const TextStyle(
                      color: Color(0xffffd580),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          )
        else
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(child: Text(_tr('예상 별점', 'Projected'))),
              const SizedBox(width: 6),
              _stars(stars),
            ],
          ),
        if (record != null)
          Text(
            _tr(
              '최고 기록 ${record.moves}회 · 별 ${record.stars}개',
              'Best ${record.moves} attempts · ${record.stars} stars',
            ),
            textAlign: TextAlign.center,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(inferenceCatalogProvider).asData?.value;
    final board = _board;
    final record =
        ref.watch(progressProvider).asData?.value.inferenceRecords[_stageKey];
    final words = [..._tray];
    if (catalog != null && board != null) _sortWords(words, catalog, board);
    final last = _history.lastOrNull;
    final score =
        last == null || board == null ? 0 : _score(board, last.result);
    final best = board == null ? 0 : _bestSimilarity(board);
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/workshop_background.jpg'),
          fit: BoxFit.fill,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: Text(_tr('단어 추리', 'Word Inference')),
          actions: [
            IconButton(
              tooltip: _tr('새 문제', 'New puzzle'),
              onPressed: _loading ? null : () => _start(_difficulty),
              icon: const Icon(Icons.shuffle_rounded),
            ),
          ],
        ),
        bottomNavigationBar:
            catalog == null || board == null || _loading
                ? null
                : SafeArea(
                  minimum: const EdgeInsets.fromLTRB(14, 4, 14, 10),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 10,
                    children: [
                      if (_finished) ...[
                        OutlinedButton(
                          onPressed: () => _retry(board),
                          child: Text(
                            _solved && board.starsFor(_moves) < 3
                                ? _tr('별 3개 재도전', 'Retry for 3 stars')
                                : _tr('재도전', 'Retry'),
                          ),
                        ),
                        if (_solved)
                          FilledButton(
                            onPressed: () => _start(_difficulty),
                            child: Text(_tr('다음 문제', 'Next puzzle')),
                          ),
                      ] else ...[
                        OutlinedButton(
                          onPressed: () => _guess(catalog),
                          child: Text(_tr('정답 입력', 'Guess answer')),
                        ),
                        FilledButton.icon(
                          onPressed:
                              _selection.length != 2
                                  ? null
                                  : () => _combine(catalog),
                          icon: const Icon(Icons.bolt),
                          label: Text(_tr('조합하기', 'Combine')),
                        ),
                      ],
                    ],
                  ),
                ),
        body: SafeArea(
          child:
              _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _failedToLoad || catalog == null || board == null
                  ? Center(
                    child: TextButton(
                      onPressed: () {
                        ref.invalidate(inferenceCatalogProvider);
                        _start(_difficulty);
                      },
                      child: Text(_tr('문제를 다시 불러오기', 'Reload puzzles')),
                    ),
                  )
                  : Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 570),
                      child: CustomScrollView(
                        controller: _scroll,
                        slivers: [
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            sliver: SliverList.list(
                              children: [
                                Wrap(
                                  alignment: WrapAlignment.center,
                                  spacing: 6,
                                  children: [
                                    for (final level in Difficulty.values)
                                      ChoiceChip(
                                        label: Text(_level(level)),
                                        selected: _difficulty == level,
                                        onSelected: (selected) {
                                          if (selected) _start(level);
                                        },
                                      ),
                                  ],
                                ),
                                Card(
                                  color: const Color(0xe0244f55),
                                  child: Padding(
                                    padding: const EdgeInsets.all(15),
                                    child: Column(
                                      children: [
                                        Text(_tr('숨은 정답', 'Hidden word')),
                                        const SizedBox(height: 4),
                                        Text(
                                          _solved
                                              ? catalog.words[board.target]
                                                  .label(_korean)
                                              : '???',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 31,
                                            fontWeight: FontWeight.w900,
                                            color:
                                                _solved
                                                    ? const Color(0xffffd580)
                                                    : colors.primary,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        _runSummary(
                                          board,
                                          record,
                                          best,
                                          _categoryLabel(
                                            catalog.answerCategory(board),
                                          ),
                                        ),
                                        if (!_exhausted) ...[
                                          const SizedBox(height: 6),
                                          Text(
                                            _tr(
                                              '현재 $score% · 최고 $best%',
                                              'Current $score% · Best $best%',
                                            ),
                                          ),
                                          const SizedBox(height: 5),
                                          TweenAnimationBuilder<double>(
                                            tween: Tween(
                                              begin: 0,
                                              end: score / 100,
                                            ),
                                            duration: const Duration(
                                              milliseconds: 250,
                                            ),
                                            builder:
                                                (context, value, _) =>
                                                    LinearProgressIndicator(
                                                      value: value,
                                                    ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                                Align(
                                  alignment: Alignment.center,
                                  child: TextButton.icon(
                                    icon: const Icon(Icons.group_outlined),
                                    onPressed: () async {
                                      final answer = await _askForWord(
                                        setTarget: true,
                                      );
                                      if (mounted && answer != null) {
                                        await _start(
                                          _difficulty,
                                          target: answer,
                                        );
                                      }
                                    },
                                    label: Text(
                                      _tr(
                                        '친구 문제 출제',
                                        'Set a word for a friend',
                                      ),
                                    ),
                                  ),
                                ),
                                if (_selection.isNotEmpty)
                                  Wrap(
                                    alignment: WrapAlignment.center,
                                    spacing: 6,
                                    children: [
                                      for (final word in _selection)
                                        InputChip(
                                          backgroundColor:
                                              _cardColors(word).surface,
                                          side: BorderSide(
                                            color: _cardColors(word).accent,
                                          ),
                                          label: Text(
                                            _word(catalog, word).label(_korean),
                                          ),
                                          onDeleted: () => _toggle(word),
                                        ),
                                    ],
                                  ),
                                if (!_finished)
                                  Center(
                                    child: TextButton.icon(
                                      onPressed: () => _suggest(catalog, board),
                                      icon: const Icon(Icons.lightbulb_outline),
                                      label: Text(
                                        _tr('레시피 힌트 보기', 'Show a recipe hint'),
                                      ),
                                    ),
                                  ),
                                if (_recipeClue case final id?)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Text(
                                      _tr(
                                        '${_word(catalog, id).label(_korean)}에 ???를 더하면 어떻게 될까요?',
                                        'Try combining ${_word(catalog, id).label(_korean)} + ???',
                                      ),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Color(0xffc5dedb),
                                      ),
                                    ),
                                  ),
                                if (last != null)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    child: Text(
                                      _entry(catalog, board, last),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Color(0xffffd580),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                if (_message != null)
                                  Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Text(
                                      _message!,
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        _tr(
                                          '보유 단어 ${words.length}',
                                          'Words ${words.length}',
                                        ),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    PopupMenuButton<_WordSort>(
                                      tooltip: _tr('보유 단어 정렬', 'Sort words'),
                                      initialValue: _sort,
                                      onSelected:
                                          (sort) =>
                                              setState(() => _sort = sort),
                                      itemBuilder:
                                          (context) => [
                                            for (final sort in _WordSort.values)
                                              CheckedPopupMenuItem(
                                                value: sort,
                                                checked: sort == _sort,
                                                child: Text(_sortLabel(sort)),
                                              ),
                                          ],
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                          horizontal: 4,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.sort, size: 18),
                                            const SizedBox(width: 6),
                                            Text(_sortLabel(_sort)),
                                            const Icon(Icons.arrow_drop_down),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (_available.length > words.length)
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: TextButton.icon(
                                      icon: const Icon(
                                        Icons.inventory_2_outlined,
                                        size: 18,
                                      ),
                                      label: Text(
                                        _tr(
                                          '보관 카드 ${_available.length - words.length}',
                                          'Reserve ${_available.length - words.length}',
                                        ),
                                      ),
                                      onPressed:
                                          () => _openReserve(catalog, board),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            sliver: SliverGrid.builder(
                              itemCount: words.length,
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 4,
                                    crossAxisSpacing: 6,
                                    mainAxisSpacing: 6,
                                    mainAxisExtent:
                                        60 +
                                        MediaQuery.textScalerOf(
                                          context,
                                        ).scale(12),
                                  ),
                              itemBuilder: (context, index) {
                                final word = words[index];
                                final selected = _selection.contains(word);
                                final palette = _cardColors(word);
                                final card = Material(
                                  color:
                                      selected
                                          ? Color.alphaBlend(
                                            palette.accent.withValues(
                                              alpha: .17,
                                            ),
                                            palette.surface,
                                          )
                                          : palette.surface,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(
                                      color:
                                          selected
                                              ? palette.accent
                                              : palette.accent.withValues(
                                                alpha: .55,
                                              ),
                                      width: selected ? 2 : 1,
                                    ),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: InkWell(
                                    onTap:
                                        _finished ? null : () => _toggle(word),
                                    child: Padding(
                                      padding: const EdgeInsets.all(5),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Flexible(
                                            child: Text(
                                              _word(
                                                catalog,
                                                word,
                                              ).label(_korean),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            _cardDetail(board, word),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: palette.accent,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                                return KeyedSubtree(
                                  key: ValueKey(word),
                                  child:
                                      _impactWord == word && selected
                                          ? _withSelectionImpact(
                                            card,
                                            palette.accent,
                                          )
                                          : card,
                                );
                              },
                            ),
                          ),
                          if (_history.isNotEmpty)
                            SliverPadding(
                              padding: const EdgeInsets.all(14),
                              sliver: SliverList.list(
                                children: [
                                  Text(
                                    _tr('기록', 'History'),
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                  for (final entry in _history.reversed)
                                    ListTile(
                                      dense: true,
                                      title: Text(
                                        _entry(catalog, board, entry),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
        ),
      ),
    );
  }

  String _entry(
    InferenceCatalog catalog,
    InferenceBoard board,
    ({List<int> inputs, int result}) entry,
  ) {
    String word(int id) => _word(catalog, id).label(_korean);
    final inputs = entry.inputs.map(word).join(' + ');
    return '${inputs.isEmpty ? '' : '$inputs → '}${word(entry.result)} · ${_score(board, entry.result)}%';
  }
}
