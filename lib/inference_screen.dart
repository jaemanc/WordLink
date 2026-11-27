import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'game_language.dart';
import 'inference_catalog.dart';
import 'models.dart';

class InferenceScreen extends ConsumerStatefulWidget {
  const InferenceScreen({super.key});

  @override
  ConsumerState<InferenceScreen> createState() => _InferenceScreenState();
}

class _InferenceScreenState extends ConsumerState<InferenceScreen> {
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
        _selection.clear();
        _history.clear();
        _available
          ..clear()
          ..addAll(board.starters);
        _tray
          ..clear()
          ..addAll(board.starters);
        _solved = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failedToLoad = true;
      });
    }
  }

  void _toggle(int word) {
    if (_solved || _loading) return;
    setState(() {
      _message = null;
      if (_selection.remove(word)) return;
      if (_selection.length == 2) _selection.removeLast();
      _selection.add(word);
    });
  }

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
    if (_selection.length != 2 || _solved || _loading) return;
    final a = _selection[0];
    final b = _selection[1];
    final result = catalog.recipeResult(a, b);
    if (result == null) {
      setState(() {
        _message = _tr(
          '두 단어를 함께 설명하는 결과를 찾지 못했어요. 한 장을 바꿔 보세요.',
          'No known result connects both words. Try swapping one card.',
        );
      });
      HapticFeedback.lightImpact();
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
      _history.add((inputs: inputs, result: result));
      if (handSize != null) {
        _available.add(result);
        _bringToTray(handSize, [result]);
      }
      _solved = result == board.target;
    });
    if (_solved) {
      HapticFeedback.heavyImpact();
    } else {
      HapticFeedback.selectionClick();
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
    if (!mounted || typed == null || _solved || _loading) return;
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

  Future<void> _openReserve(
    InferenceCatalog catalog,
    InferenceBoard board,
  ) async {
    final reserves = _available.where((id) => !_tray.contains(id)).toList();
    reserves.sort(
      (a, b) => _word(
        catalog,
        a,
      ).label(_korean).compareTo(_word(catalog, b).label(_korean)),
    );
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
                trailing: Text('${_score(board, id)}%'),
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

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(inferenceCatalogProvider).asData?.value;
    final board = _board;
    final words = [..._tray];
    if (catalog != null) {
      words.sort(
        (a, b) => _word(catalog, a)
            .label(_korean)
            .toLowerCase()
            .compareTo(_word(catalog, b).label(_korean).toLowerCase()),
      );
    }
    final last = _history.lastOrNull;
    final score =
        last == null || board == null ? 0 : _score(board, last.result);
    final best =
        board == null
            ? 0
            : _history.fold<int>(
              0,
              (best, entry) =>
                  _score(board, entry.result) > best
                      ? _score(board, entry.result)
                      : best,
            );
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
                      OutlinedButton(
                        onPressed: _solved ? null : () => _guess(catalog),
                        child: Text(_tr('정답 입력', 'Guess answer')),
                      ),
                      FilledButton.icon(
                        onPressed:
                            _selection.length != 2 || _solved
                                ? null
                                : () => _combine(catalog),
                        icon: const Icon(Icons.bolt),
                        label: Text(_tr('조합하기', 'Combine')),
                      ),
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
                                          label: Text(
                                            _word(catalog, word).label(_korean),
                                          ),
                                          onDeleted: () => _toggle(word),
                                        ),
                                    ],
                                  ),
                                if (!_solved)
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
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 9,
                                  ),
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
                                return Material(
                                  color:
                                      selected
                                          ? colors.primaryContainer
                                          : const Color(0xff24484e),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(
                                      color:
                                          selected
                                              ? colors.primary
                                              : const Color(0xff527d7b),
                                    ),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: InkWell(
                                    onTap: _solved ? null : () => _toggle(word),
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
                                            '${_score(board, word)}%',
                                            style: TextStyle(
                                              color: colors.primary,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
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
