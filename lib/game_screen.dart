import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'craft_impact.dart';
import 'game_controller.dart';
import 'local_knowledge_service.dart';
import 'models.dart';

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen>
    with SingleTickerProviderStateMixin {
  late final _impact = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  );
  static const _audio = MethodChannel('wordlink/impact');
  final _effectsSurface = GlobalKey();
  final _workbench = GlobalKey();
  final _slotKeys = <WordItem, GlobalKey>{};
  Offset _impactCenter = Offset.zero;
  List<({WordItem item, Offset from})> _flyingCards = const [];
  CraftOutcome? _impactOutcome;
  bool _byProximity = false;
  WordAttribute? _attribute;
  bool _busy = false;

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
    if (outcome?.result == null) {
      HapticFeedback.lightImpact();
      SystemSound.play(SystemSoundType.click);
      return;
    }
    HapticFeedback.heavyImpact();
    unawaited(_playImpactSound(outcome!.isTargetReached));
  }

  Future<void> _playImpactSound(bool cleared) async {
    try {
      await _audio.invokeMethod<void>('play', cleared);
    } on MissingPluginException {
      await SystemSound.play(SystemSoundType.click);
    }
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

  @override
  Widget build(BuildContext context) {
    final gameLoad = ref.watch(gameProvider);
    final game = gameLoad.asData?.value;
    final motion =
        MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 220);
    final controller = ref.read(gameProvider.notifier);
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'WORDLINK',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 3),
        ),
        actions: [
          if (game != null)
            IconButton(
              tooltip: '다시 시작',
              onPressed:
                  _busy ? null : () => _startStage(controller, game.stage),
              icon: const Icon(Icons.restart_alt),
            ),
        ],
      ),
      bottomNavigationBar:
          game == null || game.cleared
              ? null
              : _craftControls(game, controller),
      body: _withImpact(
        SafeArea(
          child: gameLoad.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error:
                (error, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('로컬 게임 데이터를 불러오지 못했어요.'),
                      TextButton(
                        onPressed: () => ref.invalidate(knowledgeProvider),
                        child: const Text('다시 불러오기'),
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
    );
  }

  Widget _play(
    GameState game,
    LocalKnowledgeService service,
    GameController controller,
    Duration motion,
  ) {
    _slotKeys.removeWhere((item, _) => !game.selected.contains(item));
    final colors = Theme.of(context).colorScheme;
    final stage = game.stage;
    int score(WordItem item) => service.proximity(item.word, stage.targetWord);
    final inventory =
        game.inventory
            .where((item) => _attribute == null || item.attribute == _attribute)
            .toList();
    if (_byProximity) {
      inventory.sort((a, b) {
        final order = score(b).compareTo(score(a));
        return order == 0 ? a.word.compareTo(b.word) : order;
      });
    }
    final best = game.inventory.map(score).reduce(math.max);
    final latest = game.latest;
    final accent = latest?.result == null ? colors.error : colors.primary;
    final index = service.stages.indexOf(stage);
    final modeStages = service.stagesFor(stage.difficulty);
    final stageNumber = modeStages.indexOf(stage) + 1;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 570),
        child: ListView(
          key: PageStorageKey(stage.id),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final difficulty in Difficulty.values)
                  ChoiceChip(
                    label: Text(
                      '${difficulty.name.toUpperCase()} ${difficulty.cardsRequired}장',
                    ),
                    selected: stage.difficulty == difficulty,
                    onSelected:
                        _busy
                            ? null
                            : (selected) {
                              if (selected) {
                                _startStage(
                                  controller,
                                  service.stagesFor(difficulty).first,
                                );
                              }
                            },
                  ),
              ],
            ),
            OutlinedButton.icon(
              onPressed:
                  _busy
                      ? null
                      : () => _pickStage(modeStages, stage, controller),
              icon: const Icon(Icons.list_alt),
              label: Text('문제 $stageNumber / ${modeStages.length}'),
            ),
            const SizedBox(height: 12),
            _Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('목표 단어', style: TextStyle(color: colors.primary)),
                  Text(
                    '${stage.targetEmoji}  ${stage.targetWord}',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text('최고 근접도 $best%'),
                        Text('${game.completedRounds} / ${stage.parSteps}단계'),
                        Text('${game.moves}회 시도'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: best / 100),
                    duration: motion,
                    builder:
                        (context, progress, _) => LinearProgressIndicator(
                          value: progress,
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(8),
                          semanticsLabel: '목표 단어 근접도',
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '조합 작업대',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  AnimatedSize(
                    key: _workbench,
                    duration: motion,
                    alignment: Alignment.topCenter,
                    child:
                        game.selected.isEmpty
                            ? Text(
                              '보유 단어를 탭해 ${stage.difficulty.cardsRequired}장을 고르세요.',
                            )
                            : Opacity(
                              opacity:
                                  _busy &&
                                          _flyingCards.isNotEmpty &&
                                          _impactOutcome == null
                                      ? 0
                                      : 1,
                              child: Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  for (final item in game.selected)
                                    _slot(item, controller, motion),
                                ],
                              ),
                            ),
                  ),
                  if (latest != null) ...[
                    const SizedBox(height: 10),
                    AnimatedSwitcher(
                      duration: motion,
                      child: Column(
                        key: ValueKey(game.moves),
                        children: [
                          Text(
                            latest.result == null
                                ? '조합 불가'
                                : '${latest.result!.emoji} ${latest.result!.word}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: accent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (latest.proximity case final proximity?)
                            Text('근접도 $proximity%')
                          else
                            const Text('카드 구성을 바꿔 보세요.'),
                        ],
                      ),
                    ),
                  ],
                  if (!game.cleared)
                    ExpansionTile(
                      key: ValueKey(game.completedRounds),
                      title: const Text('이번 조합 힌트'),
                      tilePadding: EdgeInsets.zero,
                      children: [
                        Text(
                          'Use: ${game.rounds[game.completedRounds].rule.ingredients.map((item) => item.word).join(', ')}',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  if (game.cleared) ...[
                    const SizedBox(height: 12),
                    Text(
                      '스테이지 클리어  ${List.filled(game.stars, '★').join()}'
                      '${List.filled(3 - game.stars, '☆').join()}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colors.primary,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (index + 1 < service.stages.length)
                      OutlinedButton(
                        onPressed:
                            _busy
                                ? null
                                : () => _startStage(
                                  controller,
                                  service.stages[index + 1],
                                ),
                        child: const Text('다음 스테이지'),
                      ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '보유 단어 ${game.inventory.length}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: _byProximity ? '획득순으로 정렬' : '근접도순으로 정렬',
                  isSelected: _byProximity,
                  onPressed: () => setState(() => _byProximity = !_byProximity),
                  icon: const Icon(Icons.sort),
                  selectedIcon: const Icon(Icons.leaderboard_outlined),
                ),
                IconButton(
                  tooltip: '조합 기록',
                  onPressed: () => _showHistory(game.history),
                  icon: const Icon(Icons.history),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: DropdownButton<WordAttribute>(
                value: _attribute,
                hint: const Text('전체 속성'),
                onChanged:
                    (attribute) => setState(() => _attribute = attribute),
                items: [
                  const DropdownMenuItem(child: Text('전체 속성')),
                  for (final attribute in WordAttribute.values)
                    DropdownMenuItem(
                      value: attribute,
                      child: Text(attribute.label),
                    ),
                ],
              ),
            ),
            if (inventory.isEmpty) const Text('이 속성의 카드가 아직 없어요.'),
            LayoutBuilder(
              builder:
                  (context, constraints) => Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final item in inventory)
                        SizedBox(
                          width: (constraints.maxWidth - 16) / 3,
                          child: _wordCard(
                            game,
                            controller,
                            item,
                            score(item),
                            motion,
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

  void _startStage(GameController controller, Stage stage) {
    setState(() => _attribute = null);
    controller.start(stage);
  }

  Future<void> _pickStage(
    List<Stage> stages,
    Stage current,
    GameController controller,
  ) async {
    final stage = await showModalBottomSheet<Stage>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _StagePicker(stages),
    );
    if (mounted && stage != null && stage != current) {
      _startStage(controller, stage);
    }
  }

  Widget _craftControls(GameState game, GameController controller) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          children: [
            Text(
              '${game.selected.length} / ${game.cardsRequired}장',
              semanticsLabel:
                  '필요한 카드 ${game.cardsRequired}장 중 ${game.selected.length}장 선택',
            ),
            TextButton(
              onPressed:
                  _busy || game.selected.isEmpty
                      ? null
                      : controller.clearSelection,
              child: const Text('선택 해제'),
            ),
            FilledButton.icon(
              onPressed:
                  game.canCraft && !_busy ? () => _combine(controller) : null,
              icon: const Icon(Icons.bolt),
              label: const Text('조합하기'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _slot(WordItem item, GameController controller, Duration motion) {
    return TweenAnimationBuilder<double>(
      key: _slotKeys.putIfAbsent(item, GlobalKey.new),
      tween: Tween(begin: .8, end: 1),
      duration: motion,
      curve: Curves.easeOutBack,
      builder:
          (context, scale, child) =>
              Transform.scale(scale: scale, child: child),
      child: InputChip(
        label: Text('${item.emoji} ${item.word}'),
        deleteButtonTooltipMessage: '${item.word} 선택 해제',
        onDeleted:
            _busy
                ? null
                : () {
                  HapticFeedback.selectionClick();
                  controller.toggle(item);
                },
      ),
    );
  }

  Widget _wordCard(
    GameState game,
    GameController controller,
    WordItem item,
    int score,
    Duration motion,
  ) {
    final selected = game.selected.contains(item);
    final enabled =
        !_busy &&
        !game.cleared &&
        (selected || game.selected.length < game.cardsRequired);
    final colors = Theme.of(context).colorScheme;
    return AnimatedScale(
      key: ValueKey(item.word),
      duration: motion,
      curve: Curves.easeOutBack,
      scale: selected ? .93 : 1,
      child: Semantics(
        selected: selected,
        child: Material(
          color:
              selected ? colors.primaryContainer : colors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap:
                enabled
                    ? () {
                      HapticFeedback.selectionClick();
                      controller.toggle(item);
                    }
                    : null,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  Text(item.emoji, style: const TextStyle(fontSize: 25)),
                  Text(
                    item.word,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    '${item.attribute.label} · $score%',
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: colors.primary),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showHistory(List<CraftOutcome> history) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder:
          (context) => SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('조합 기록', style: Theme.of(context).textTheme.titleLarge),
                if (history.isEmpty)
                  const ListTile(title: Text('아직 시도한 조합이 없어요.')),
                for (final (index, outcome)
                    in history.indexed.toList().reversed)
                  ListTile(
                    leading: Text('${index + 1}'),
                    title: Text(outcome.equation),
                  ),
              ],
            ),
          ),
    );
  }
}

class _StagePicker extends StatefulWidget {
  const _StagePicker(this.stages);

  final List<Stage> stages;

  @override
  State<_StagePicker> createState() => _StagePickerState();
}

class _StagePickerState extends State<_StagePicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final number = int.tryParse(_query);
    final matches =
        widget.stages.indexed.where((entry) {
          final (index, stage) = entry;
          return number == null
              ? stage.targetWord.toLowerCase().contains(_query)
              : index + 1 == number;
        }).toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: FractionallySizedBox(
        heightFactor: .85,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                decoration: const InputDecoration(
                  labelText: '번호 또는 영어 목표 단어 검색',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged:
                    (value) =>
                        setState(() => _query = value.trim().toLowerCase()),
              ),
            ),
            Expanded(
              child:
                  matches.isEmpty
                      ? const Center(child: Text('검색 결과가 없어요.'))
                      : ListView.builder(
                        itemCount: matches.length,
                        itemBuilder: (context, index) {
                          final (position, stage) = matches[index];
                          return ListTile(
                            leading: Text('${position + 1}'),
                            title: Text(
                              '${stage.targetEmoji} ${stage.targetWord}',
                            ),
                            onTap: () => Navigator.pop(context, stage),
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surfaceContainer,
    borderRadius: BorderRadius.circular(18),
    child: Padding(padding: const EdgeInsets.all(16), child: child),
  );
}
