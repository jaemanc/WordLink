import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'campaign_progress.dart';
import 'craft_impact.dart';
import 'game_controller.dart';
import 'game_language.dart';
import 'local_knowledge_service.dart';
import 'models.dart';
import 'word_relations.dart';

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen>
    with SingleTickerProviderStateMixin {
  late final _impact = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 510),
  );
  final _effectsSurface = GlobalKey();
  final _workbench = GlobalKey();
  final _inventoryGrid = GlobalKey();
  final _slotKeys = <WordItem, GlobalKey>{};
  Offset _impactCenter = Offset.zero;
  Offset? _impactDestination;
  List<({WordItem item, Offset from})> _flyingCards = const [];
  CraftOutcome? _impactOutcome;
  final _random = math.Random();
  _PuzzleCategory _category = _PuzzleCategory.all;
  bool _byProximity = false;
  bool _busy = false;
  bool _draggingCard = false;

  @override
  void dispose() {
    _impact.dispose();
    super.dispose();
  }

  Future<void> _combine(GameController controller) async {
    if (_busy) return;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion) {
      controller.craft();
      _feedback();
      return;
    }
    _captureCollision();
    setState(() => _busy = true);
    try {
      await _impact
          .animateTo(
            CraftImpact.collision,
            duration: const Duration(milliseconds: 180),
          )
          .orCancel;
      if (!mounted) return;
      controller.craft();
      _impactOutcome = ref.read(gameProvider).asData?.value.latest;
      _feedback();
      await _impact.forward().orCancel;
    } on TickerCanceled {
      return;
    } finally {
      if (mounted) {
        _impact.reset();
        setState(() {
          _busy = false;
          _flyingCards = const [];
          _impactOutcome = null;
        });
      }
    }
  }

  void _captureCollision() {
    final surface = _effectsSurface.currentContext?.findRenderObject();
    final game = ref.read(gameProvider).asData?.value;
    if (surface is! RenderBox || !surface.hasSize || game == null) return;
    final bounds = Offset.zero & surface.size;

    Offset? visibleCenter(GlobalKey? key) {
      final box = key?.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.hasSize || !box.attached) return null;
      final point = surface.globalToLocal(
        box.localToGlobal(box.size.center(Offset.zero)),
      );
      return bounds.contains(point) ? point : null;
    }

    _impactCenter = visibleCenter(_workbench) ?? bounds.center;
    final rail = visibleCenter(_inventoryGrid);
    _impactDestination =
        rail == null
            ? Offset(bounds.left + bounds.width * .23, bounds.bottom - 28)
            : rail;
    final radius = math.min(surface.size.width, surface.size.height) * .39;
    _flyingCards = [
      for (final (index, item) in game.selected.indexed)
        (
          item: item,
          from:
              visibleCenter(_slotKeys[item]) ??
              bounds.center +
                  Offset.fromDirection(
                    index * math.pi * 2 / game.selected.length,
                    radius,
                  ),
        ),
    ];
  }

  void _feedback() {
    final outcome = ref.read(gameProvider).asData?.value.latest;
    if (outcome == null) return;
    HapticFeedback.heavyImpact();
    unawaited(playImpactSound(cleared: outcome.isTargetReached));
  }

  Widget _withImpact(Widget child) => AnimatedBuilder(
    animation: _impact,
    child: child,
    builder: (context, child) {
      final effect = CraftImpact(
        progress: _impact.value,
        center: _impactCenter,
        cards: _flyingCards,
        outcome: _impactOutcome,
        destination: _impactDestination,
        isNew:
            _impactOutcome != null &&
            ref.read(gameProvider).asData?.value.newDiscovery == true,
        newBest:
            _impactOutcome != null &&
            ref.read(gameProvider).asData?.value.newProximityRecord == true,
      );
      return Stack(
        key: _effectsSurface,
        fit: StackFit.expand,
        children: [
          Transform.translate(
            offset: _busy ? effect.recoil : Offset.zero,
            child: child,
          ),
          if (_busy && _flyingCards.isNotEmpty) effect,
        ],
      );
    },
  );

  String _tr(String korean, String english) =>
      gameText(context, korean, english);

  @override
  Widget build(BuildContext context) {
    final gameLoad = ref.watch(gameProvider);
    final game = gameLoad.asData?.value;
    final controller = ref.read(gameProvider.notifier);
    final motion =
        MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 220);
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xff08212b),
        image: DecorationImage(
          image: AssetImage('assets/workshop_background.jpg'),
          fit: BoxFit.fill,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          centerTitle: true,
          backgroundColor: Colors.transparent,
          leading: IconButton(
            tooltip: _tr('홈으로', 'Back to home'),
            onPressed: _busy ? null : () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          title: Text(
            _tr('워드링크', 'WORDLINK'),
            style: const TextStyle(
              color: Color(0xffffefd4),
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
              shadows: [Shadow(color: Color(0xffc98d48), offset: Offset(0, 2))],
            ),
          ),
          actions: [
            if (game != null)
              IconButton(
                tooltip: _tr('단어 도감', 'Word collection'),
                icon: const Icon(Icons.auto_stories_outlined),
                onPressed: _busy ? null : _collection,
              ),
            if (game != null)
              IconButton(
                tooltip: _tr('랜덤 새 문제', 'Random new puzzle'),
                onPressed:
                    _busy ? null : () => _randomPuzzle(controller, game.stage),
                icon: const Icon(Icons.restart_alt),
              ),
          ],
        ),
        bottomNavigationBar:
            game == null || game.cleared ? null : _controls(game, controller),
        body: _withImpact(
          SafeArea(
            child: gameLoad.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error:
                  (_, _) => Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _tr(
                            '게임 데이터를 불러오지 못했어요.',
                            'Could not load the game data.',
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() => _category = _PuzzleCategory.all);
                            ref.invalidate(knowledgeProvider);
                          },
                          child: Text(_tr('다시 불러오기', 'Try again')),
                        ),
                      ],
                    ),
                  ),
              data:
                  (game) => _play(
                    game,
                    ref.read(knowledgeProvider).requireValue,
                    controller,
                    motion,
                  ),
            ),
          ),
        ),
      ),
    );
  }

  void _start(GameController controller, Stage stage) {
    unawaited(controller.start(stage));
  }

  void _randomPuzzle(
    GameController controller,
    Stage current, {
    Difficulty? mode,
  }) {
    final service = ref.read(knowledgeProvider).requireValue;
    final eligible =
        service
            .stagesFor(mode ?? current.difficulty)
            .where(
              (stage) =>
                  _category == _PuzzleCategory.all ||
                  _PuzzleCategory.forPack(stage.pack) == _category,
            )
            .toList();
    final differentTheme =
        eligible.where((stage) => stage.pack != current.pack).toList();
    final choices =
        differentTheme.isNotEmpty
            ? differentTheme
            : eligible.where((stage) => stage.id != current.id).toList();
    if (choices.isNotEmpty)
      _start(controller, choices[_random.nextInt(choices.length)]);
  }

  String _categoryLabel(_PuzzleCategory category) =>
      _tr(category.korean, category.english);

  Widget _play(
    GameState game,
    LocalKnowledgeService service,
    GameController controller,
    Duration motion,
  ) {
    _slotKeys.removeWhere((item, _) => !game.selected.contains(item));
    final stage = game.stage;
    final categories = {
      for (final candidate in service.stagesFor(stage.difficulty))
        _PuzzleCategory.forPack(candidate.pack),
    };
    int score(WordItem item) => service.cardProximity(item, stage);
    final best = game.bestProximity;
    final record = ref.watch(progressProvider).asData?.value.records[stage.id];
    final inventory = [...game.inventory];
    if (_byProximity) inventory.sort((a, b) => score(b).compareTo(score(a)));

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 570),
        child: CustomScrollView(
          key: PageStorageKey(stage.id),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              sliver: SliverList.list(
                children: [
                  Row(
                    children: [
                      for (final difficulty in Difficulty.values)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: ChoiceChip(
                              showCheckmark: false,
                              label: Center(
                                child: Text(
                                  switch (difficulty) {
                                    Difficulty.easy => _tr('쉬움', 'EASY'),
                                    Difficulty.normal => _tr('보통', 'NORMAL'),
                                    Difficulty.hard => _tr('어려움', 'HARD'),
                                  },
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              selected: difficulty == stage.difficulty,
                              onSelected:
                                  _busy
                                      ? null
                                      : (selected) {
                                        if (selected) {
                                          setState(
                                            () =>
                                                _category = _PuzzleCategory.all,
                                          );
                                          _randomPuzzle(
                                            controller,
                                            stage,
                                            mode: difficulty,
                                          );
                                        }
                                      },
                            ),
                          ),
                        ),
                    ],
                  ),
                  Row(
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 9),
                        child: Icon(
                          Icons.category_outlined,
                          size: 18,
                          color: Color(0xffa5ead3),
                        ),
                      ),
                      Text(_tr('카테고리', 'Category')),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButton<_PuzzleCategory>(
                          isExpanded: true,
                          value: _category,
                          onChanged:
                              _busy
                                  ? null
                                  : (category) {
                                    if (category == null ||
                                        category == _category) {
                                      return;
                                    }
                                    setState(() => _category = category);
                                    _randomPuzzle(controller, stage);
                                  },
                          items: [
                            for (final category in _PuzzleCategory.values)
                              if (category == _PuzzleCategory.all ||
                                  categories.contains(category))
                                DropdownMenuItem(
                                  value: category,
                                  child: Text(_categoryLabel(category)),
                                ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  _Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Text(
                              stage.targetEmoji,
                              style: const TextStyle(fontSize: 45),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: const Color(0xfff2c780),
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      child: Text(
                                        _tr('목표 단어', 'TARGET WORD'),
                                        style: const TextStyle(
                                          color: Color(0xff352512),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    gameWord(context, stage.target),
                                    style: const TextStyle(
                                      color: Color(0xfffff2df),
                                      fontSize: 24,
                                      height: 1.08,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 5,
                          runSpacing: 4,
                          children: [
                            _Stat(
                              Icons.near_me_outlined,
                              _tr(
                                '현재 ${game.currentProximity}%',
                                'Current ${game.currentProximity}%',
                              ),
                            ),
                            _Stat(
                              Icons.gps_fixed,
                              _tr('최고 근접도 $best%', 'Best $best%'),
                            ),
                            _Stat(
                              Icons.layers_outlined,
                              _tr(
                                '${game.completedRounds} / ${stage.parSteps}단계',
                                '${game.completedRounds} / ${stage.parSteps} steps',
                              ),
                            ),
                            if (record != null)
                              _Stat(
                                Icons.emoji_events_outlined,
                                _tr(
                                  '개인 기록 ${record.moves}회 · ${record.stars}★',
                                  'Record ${record.moves} · ${record.stars}★',
                                ),
                              ),
                            _Stat(
                              Icons.bolt,
                              _tr(
                                '${game.moves}회 시도',
                                '${game.moves} attempts',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TweenAnimationBuilder<double>(
                          tween: Tween(
                            begin: 0,
                            end: game.currentProximity / 100,
                          ),
                          duration: motion,
                          builder:
                              (context, progress, _) => LinearProgressIndicator(
                                value: progress,
                                minHeight: 7,
                                borderRadius: BorderRadius.circular(8),
                                semanticsLabel: _tr(
                                  '목표 단어 근접도',
                                  'Target proximity',
                                ),
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 13),
                  _bench(game, controller, motion),
                  if (game.cleared)
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      children: [
                        TextButton(
                          onPressed:
                              _busy ? null : () => _start(controller, stage),
                          child: Text(_tr('같은 문제 재도전', 'Retry this puzzle')),
                        ),
                        TextButton(
                          onPressed:
                              _busy
                                  ? null
                                  : () => _randomPuzzle(controller, stage),
                          child: Text(_tr('랜덤 새 문제', 'Random new puzzle')),
                        ),
                      ],
                    ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _tr(
                            '📦  보유 단어 ${game.inventory.length}',
                            '📦  Inventory ${game.inventory.length}',
                          ),
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            color: Color(0xffffecd3),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          _byProximity
                              ? Icons.leaderboard_outlined
                              : Icons.sort,
                        ),
                        tooltip:
                            _byProximity
                                ? _tr('획득순으로 정렬', 'Sort by acquisition')
                                : _tr('근접도순으로 정렬', 'Sort by proximity'),
                        onPressed:
                            () => setState(() => _byProximity = !_byProximity),
                      ),
                      IconButton(
                        tooltip: _tr('조합 기록', 'Craft history'),
                        icon: const Icon(Icons.history),
                        onPressed: () => _history(game.history),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(23, 8, 23, 0),
              sliver: SliverGrid.builder(
                itemCount: inventory.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 6,
                  mainAxisSpacing: 6,
                  mainAxisExtent: _WordTile.heightFor(context),
                ),
                itemBuilder: (context, index) {
                  final item = inventory[index];
                  return KeyedSubtree(
                    key: index == 0 ? _inventoryGrid : ObjectKey(item),
                    child: _card(game, controller, item, score(item), motion),
                  );
                },
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(15, 0, 15, 16),
              sliver: SliverList.list(
                children: [
                  if (!game.cleared)
                    Padding(
                      padding: const EdgeInsets.only(top: 9),
                      child: _Panel(
                        padding: EdgeInsets.zero,
                        child: ExpansionTile(
                          key: ValueKey(game.completedRounds),
                          leading: const Icon(
                            Icons.lightbulb_outline,
                            color: Color(0xfff2c780),
                          ),
                          title: Text(_tr('조합 단서', 'Recipe clue')),
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                              child: Text(
                                _clue(game),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _attributeLabel(WordAttribute attribute) => _tr(
    attribute.label,
    '${attribute.name[0].toUpperCase()}${attribute.name.substring(1)}',
  );

  bool _canDrop(GameState game, WordItem item) =>
      !_busy &&
      !game.cleared &&
      game.selected.length < GameState.selectionLimit &&
      game.inventory.contains(item) &&
      !game.selected.contains(item);

  void _toggle(GameController controller, WordItem item) {
    HapticFeedback.selectionClick();
    controller.toggle(item);
  }

  Widget _dropZone(
    GameState game,
    GameController controller,
    Widget Function(bool) builder,
  ) => DragTarget<WordItem>(
    hitTestBehavior: HitTestBehavior.opaque,
    onWillAcceptWithDetails: (details) => _canDrop(game, details.data),
    onAcceptWithDetails: (details) {
      final current = ref.read(gameProvider).asData?.value;
      if (current != null && _canDrop(current, details.data)) {
        _toggle(controller, details.data);
      }
    },
    builder: (context, hovering, _) => builder(hovering.isNotEmpty),
  );

  Widget _bench(GameState game, GameController controller, Duration motion) {
    final latest = game.latest;
    return _dropZone(
      game,
      controller,
      (hovering) => _Panel(
        wooden: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _tr('🥣  조합 작업대', '🥣  WORKBENCH'),
                    style: const TextStyle(
                      color: Color(0xffffe5b8),
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed:
                      _busy ||
                              _draggingCard ||
                              (game.moves == 0 && game.selected.isEmpty)
                          ? null
                          : () => _start(controller, game.stage),
                  icon: const Icon(Icons.restart_alt, size: 18),
                  label: Text(_tr('조합 리셋', 'Reset puzzle')),
                ),
              ],
            ),
            const SizedBox(height: 8),
            AnimatedSize(
              key: _workbench,
              duration: motion,
              alignment: Alignment.topCenter,
              child: Column(
                children: [
                  if (game.selected.isNotEmpty)
                    Opacity(
                      opacity:
                          _busy &&
                                  _flyingCards.isNotEmpty &&
                                  _impactOutcome == null
                              ? 0
                              : 1,
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 6,
                        runSpacing: 3,
                        children: [
                          for (final item in game.selected)
                            InputChip(
                              key: _slotKeys.putIfAbsent(item, GlobalKey.new),
                              label: Text(
                                '${item.emoji} ${gameWord(context, item)}',
                              ),
                              deleteButtonTooltipMessage: _tr(
                                '${gameWord(context, item)} 선택 해제',
                                'Remove ${gameWord(context, item)}',
                              ),
                              onDeleted:
                                  _busy
                                      ? null
                                      : () => _toggle(controller, item),
                            ),
                        ],
                      ),
                    ),
                  if (!game.cleared &&
                      game.selected.length < GameState.selectionLimit)
                    AnimatedContainer(
                      key: const ValueKey('workbench-drop-zone'),
                      duration: motion,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 11,
                      ),
                      decoration: BoxDecoration(
                        color: Color(hovering ? 0xff326c61 : 0xff244344),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Color(hovering ? 0xffb2ffda : 0xff67958d),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.add,
                            color: Color(0xffa3ffdc),
                            size: 20,
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              _tr(
                                '카드를 위로 끌어 여기에 놓기',
                                'Drag a card up and drop it here',
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            if (latest != null) ...[
              const SizedBox(height: 8),
              AnimatedSwitcher(
                duration: motion,
                child: Column(
                  key: ValueKey(game.moves),
                  children: [
                    Text(
                      '${latest.result.emoji} ${gameWord(context, latest.result)}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(
                          latest.isRecipeMatch ? 0xffa5f0d0 : 0xffffd293,
                        ),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      _tr(
                        '근접도 ${latest.proximity}% · ${_delta(game.proximityDelta)}%p',
                        '${latest.proximity}% proximity · ${_delta(game.proximityDelta)} pp',
                      ),
                    ),
                    TweenAnimationBuilder<double>(
                      tween: Tween(
                        begin: game.previousProximity / 100,
                        end: latest.proximity / 100,
                      ),
                      duration: motion,
                      builder:
                          (context, progress, _) => LinearProgressIndicator(
                            value: progress,
                            minHeight: 5,
                            borderRadius: BorderRadius.circular(8),
                            color:
                                game.newProximityRecord
                                    ? const Color(0xffffcf71)
                                    : _proximityColor(latest.proximity),
                          ),
                    ),
                    if (game.newProximityRecord)
                      Text(
                        _tr('✦ 최고 근접도 갱신', '✦ New proximity record'),
                        style: const TextStyle(
                          color: Color(0xffffcf71),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    if (game.newDiscovery || game.latestReward > 0)
                      Text(
                        [
                          if (game.newDiscovery) _tr('신규 발견', 'NEW'),
                          if (game.latestReward > 0)
                            _tr(
                              '숨겨진 조합 +${game.latestReward}점',
                              'Hidden recipe +${game.latestReward} points',
                            ),
                        ].join(' · '),
                        style: const TextStyle(
                          color: Color(0xffffdc8f),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    Text(
                      latest.isRecipeMatch
                          ? _proximityMessage(latest.proximity)
                          : _tr(
                            '보유 단어 아래 조합 단서를 확인하세요.',
                            'See the recipe clue below your inventory.',
                          ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
            if (game.cleared)
              Text(
                '${_tr('스테이지 클리어', 'Puzzle cleared')}  ${List.filled(game.stars, '★').join()}'
                '${List.filled(3 - game.stars, '☆').join()}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xffffdc8f),
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _controls(GameState game, GameController controller) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 7),
      child: Row(
        children: [
          Expanded(
            child: _dropZone(
              game,
              controller,
              (hovering) => Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color:
                      hovering
                          ? const Color(0xff275951)
                          : _draggingCard
                          ? const Color(0xff244344)
                          : null,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _draggingCard
                      ? _tr('여기 놓기', 'Drop here')
                      : '${game.selected.length} / 4',
                  textAlign: TextAlign.center,
                  semanticsLabel: _tr(
                    '최대 4장 중 ${game.selected.length}장 선택',
                    '${game.selected.length} of 4 cards selected',
                  ),
                ),
              ),
            ),
          ),
          TextButton(
            onPressed:
                _busy || game.selected.isEmpty
                    ? null
                    : controller.clearSelection,
            child: Text(_tr('선택 해제', 'Clear')),
          ),
          Expanded(
            flex: 3,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient:
                    game.canCraft && !_busy
                        ? const LinearGradient(
                          colors: [
                            Color(0xfff2e8a4),
                            Color(0xffa9ffd8),
                            Color(0xff45bca1),
                          ],
                        )
                        : null,
                boxShadow:
                    game.canCraft && !_busy
                        ? const [
                          BoxShadow(color: Color(0x557dffce), blurRadius: 18),
                        ]
                        : const [],
              ),
              child: FilledButton.icon(
                onPressed:
                    game.canCraft && !_busy ? () => _combine(controller) : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 49),
                  backgroundColor: Colors.transparent,
                  foregroundColor: const Color(0xff12302e),
                  shadowColor: Colors.transparent,
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                icon: const Icon(Icons.bolt),
                label: Text(_tr('조합하기', 'Combine')),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _card(
    GameState game,
    GameController controller,
    WordItem item,
    int score,
    Duration motion,
  ) {
    final selected = game.selected.contains(item);
    final enabled =
        !_busy && !game.cleared && (selected || _canDrop(game, item));
    final tile = _WordTile(
      item: item,
      accent: selected ? const Color(0xffffdc8f) : _proximityColor(score),
      proximity: score,
    );
    return AnimatedScale(
      key: ObjectKey(item),
      duration: motion,
      curve: Curves.easeOutBack,
      scale: selected ? .94 : 1,
      child: Opacity(
        opacity: _busy && identical(_impactOutcome?.result, item) ? 0 : 1,
        child: Semantics(
          selected: selected,
          button: true,
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: enabled ? () => _toggle(controller, item) : null,
              child: enabled && !selected ? _draggableCard(item, tile) : tile,
            ),
          ),
        ),
      ),
    );
  }

  Widget _draggableCard(WordItem item, Widget tile) {
    final preview = Material(
      color: Colors.transparent,
      child: Transform.translate(
        offset: const Offset(-50, -62),
        child: Transform.rotate(
          angle: -.16,
          child: SizedBox(
            width: 106,
            height: math.max(106.0, _WordTile.heightFor(context)),
            child: _WordTile(item: item, accent: const Color(0xffffdc8f)),
          ),
        ),
      ),
    );

    void markDragging(bool dragging) {
      if (mounted) setState(() => _draggingCard = dragging);
    }

    return LongPressDraggable<WordItem>(
      data: item,
      delay: const Duration(milliseconds: 140),
      hitTestBehavior: HitTestBehavior.opaque,
      maxSimultaneousDrags: 1,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: preview,
      onDragStarted: () => markDragging(true),
      onDragCompleted: () => markDragging(false),
      onDraggableCanceled: (_, _) => markDragging(false),
      childWhenDragging: Opacity(opacity: .35, child: tile),
      child: Stack(
        fit: StackFit.expand,
        children: [
          tile,
          Positioned(
            top: 0,
            right: 0,
            child: Draggable<WordItem>(
              data: item,
              hitTestBehavior: HitTestBehavior.opaque,
              maxSimultaneousDrags: 1,
              dragAnchorStrategy: pointerDragAnchorStrategy,
              feedback: preview,
              onDragStarted: () => markDragging(true),
              onDragCompleted: () => markDragging(false),
              onDraggableCanceled: (_, _) => markDragging(false),
              child: Semantics(
                label: _tr('작업대로 바로 끌기', 'Drag directly to workbench'),
                child: const SizedBox(
                  width: 34,
                  height: 32,
                  child: Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(
                        Icons.drag_indicator_rounded,
                        size: 16,
                        color: Color(0xff9ccbbd),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _delta(int value) => value > 0 ? '+$value' : '$value';

  Color _proximityColor(int score) => switch (score) {
    >= 100 => const Color(0xffffce75),
    >= 75 => const Color(0xff92f4af),
    >= 55 => const Color(0xff72d8c5),
    >= 25 => const Color(0xff8bb7ed),
    _ => const Color(0xff9b9aaf),
  };

  String _proximityMessage(int score) => switch (score) {
    100 => _tr('목표에 도달했어요.', 'Target reached.'),
    >= 75 => _tr('목표에 아주 가까워요.', 'Very close to the target.'),
    >= 55 => _tr('정답 경로를 따라가고 있어요.', 'You are on the recipe path.'),
    >= 25 => _tr('의미상 관련이 있어요.', 'There is a semantic connection.'),
    _ => _tr(
      '근접도가 낮아도 재료가 될 수 있어요.',
      'Low proximity cards can still be useful ingredients.',
    ),
  };

  String _clue(GameState game) {
    if (game.cleared) return _proximityMessage(100);
    final latest = game.latest;
    final round = game.rounds[game.completedRounds];
    final missing =
        latest != null && !latest.isRecipeMatch
            ? latest.missingAttributes
            : round.rule.groups.map((group) => group.first.attribute);
    final attributes = missing.map(_attributeLabel).toSet().join(' · ');
    final count = round.rule.groups.length;
    return [
      _tr('이 단계는 카드 $count장이 필요해요.', 'This step needs $count cards.'),
      if (attributes.isNotEmpty)
        _tr('살펴볼 속성 $attributes', 'Look for these attributes $attributes'),
      if (latest != null && !latest.isRecipeMatch && latest.lowRelevance > 0)
        _tr(
          '관련성이 낮은 카드 ${latest.lowRelevance}장을 바꿔 보세요.',
          'Try replacing ${latest.lowRelevance} low-relevance cards.',
        ),
    ].join(' ');
  }

  void _collection() {
    final entries = ref.read(knowledgeProvider).requireValue.catalog;
    final progress =
        ref.read(progressProvider).asData?.value ?? const CampaignProgress();
    final found =
        entries
            .where(
              (item) => progress.discovered.contains(
                WordRelations.collectionKey(item.label),
              ),
            )
            .toList();
    final remaining = entries.length - found.length;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder:
          (context) => FractionallySizedBox(
            heightFactor: .84,
            child: Column(
              children: [
                ListTile(
                  title: Text(gameText(context, '단어 도감', 'Word collection')),
                  subtitle: Text(
                    gameText(
                      context,
                      '${found.length} / ${entries.length} 발견 · ${progress.rewardPoints}점',
                      '${found.length} / ${entries.length} discovered · ${progress.rewardPoints} points',
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: found.length + remaining,
                    itemBuilder: (context, index) {
                      if (index >= found.length) {
                        return ListTile(
                          leading: const Text('?'),
                          title: Text(gameText(context, '미발견', 'Undiscovered')),
                        );
                      }
                      final card = found[index];
                      return ListTile(
                        leading: Text(card.emoji),
                        title: Text(gameWord(context, card)),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
    );
  }

  void _history(List<CraftOutcome> history) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder:
          (context) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                _tr('조합 기록', 'Craft history'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (history.isEmpty)
                ListTile(
                  title: Text(_tr('아직 시도한 조합이 없어요.', 'No attempts yet.')),
                ),
              for (final (index, outcome) in history.indexed.toList().reversed)
                ListTile(
                  leading: Text('${index + 1}'),
                  title: Text(
                    '${outcome.ingredients.map((item) => gameWord(context, item)).join(' + ')}'
                    ' → ${gameWord(context, outcome.result)}',
                  ),
                ),
            ],
          ),
    );
  }
}

enum _PuzzleCategory {
  all('전체', 'All'),
  foodAndGarden('음식과 식물', 'Food & Garden'),
  artsAndCrafts('예술과 공예', 'Arts & Crafts'),
  homeAndHobbies('생활과 취미', 'Home & Hobbies'),
  mechanisms('기계와 장치', 'Mechanisms'),
  science('과학과 연구', 'Science'),
  engineering('공학과 인프라', 'Engineering');

  const _PuzzleCategory(this.korean, this.english);

  final String korean;
  final String english;

  // Pack IDs follow the theme IDs in the bundled campaign generator.
  static _PuzzleCategory forPack(int pack) => switch (pack) {
    0 || 3 || 4 || 30 || 32 || 33 => foodAndGarden,
    2 || 5 || 6 || 9 || 13 || 16 || 31 || 34 || 35 || 36 || 39 => artsAndCrafts,
    1 || 7 || 8 || 11 || 15 || 17 => homeAndHobbies,
    10 || 12 || 14 || 19 || 37 => mechanisms,
    18 || 20 || 23 || 24 || 25 || 38 || 41 || 43 => science,
    _ => engineering,
  };
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.child,
    this.wooden = false,
    this.padding = const EdgeInsets.all(14),
  });

  final Widget child;
  final bool wooden;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final panel = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(27),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors:
              wooden
                  ? const [
                    Color(0xffedbe85),
                    Color(0xff755339),
                    Color(0xff254849),
                  ]
                  : const [
                    Color(0xc3436b6b),
                    Color(0xe01e434b),
                    Color(0xea102e37),
                  ],
        ),
        border: Border.all(color: Color(wooden ? 0xffdab382 : 0xff618e8c)),
        boxShadow: [
          const BoxShadow(
            color: Color(0x88020d13),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
          BoxShadow(
            color: Color(wooden ? 0x33ffd69a : 0x2e91ffd7),
            blurRadius: 18,
          ),
        ],
      ),
      padding: EdgeInsets.all(wooden ? 7 : 0),
      child: Material(
        color: wooden ? const Color(0xff303a37) : Colors.transparent,
        borderRadius: BorderRadius.circular(wooden ? 20 : 26),
        child: Padding(padding: padding, child: child),
      ),
    );
    if (!wooden) return panel;
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        const Padding(padding: EdgeInsets.only(top: 4), child: _BoardHandle()),
        Padding(padding: const EdgeInsets.only(top: 20), child: panel),
      ],
    );
  }
}

class _BoardHandle extends StatelessWidget {
  const _BoardHandle();

  @override
  Widget build(BuildContext context) => Container(
    width: 57,
    height: 34,
    alignment: Alignment.topCenter,
    padding: const EdgeInsets.only(top: 6),
    decoration: const BoxDecoration(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xffffd8a9), Color(0xff987052)],
      ),
    ),
    child: Container(
      width: 10,
      height: 10,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xff422c21),
        boxShadow: [BoxShadow(color: Color(0xfff3c58a), offset: Offset(0, 1))],
      ),
    ),
  );
}

class _Stat extends StatelessWidget {
  const _Stat(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0x483b736d),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0x8b608c85)),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xff95ebc7), size: 14),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    ),
  );
}

class _WordTile extends StatelessWidget {
  const _WordTile({required this.item, required this.accent, this.proximity});

  final WordItem item;
  final Color accent;
  final int? proximity;

  static double heightFor(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context);
    return math.max(
      92.0,
      18 + scale.scale(23) + 2 * scale.scale(12) + scale.scale(11) + 16,
    );
  }

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xff38696a), Color(0xff173f46)],
      ),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: accent, width: 1.3),
      boxShadow: [
        BoxShadow(color: accent.withValues(alpha: .22), blurRadius: 11),
      ],
    ),
    child: Padding(
      padding: const EdgeInsets.all(6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(item.emoji, style: const TextStyle(fontSize: 23, height: 1.1)),
          const SizedBox(height: 4),
          Flexible(
            child: Text(
              gameWord(context, item),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xfffff0db),
                height: 1.1,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (proximity case final score?)
            Text(
              '$score%',
              semanticsLabel: gameText(
                context,
                '근접도 $score%',
                '$score% proximity',
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: accent,
                height: 1.1,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    ),
  );
}
