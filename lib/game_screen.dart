import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    duration: const Duration(milliseconds: 420),
  );
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
    setState(() => _busy = true);
    try {
      await _impact
          .animateTo(.28, duration: const Duration(milliseconds: 115))
          .orCancel;
      if (!mounted) return;
      controller.craft();
      _feedback();
      await _impact.forward().orCancel;
    } on TickerCanceled {
      return;
    } finally {
      if (mounted) {
        _impact.reset();
        setState(() => _busy = false);
      }
    }
  }

  void _feedback() {
    final outcome = ref.read(gameProvider)?.latest;
    if (outcome?.isTargetReached ?? false) {
      HapticFeedback.heavyImpact();
    } else if (outcome?.result != null) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.lightImpact();
    }
    SystemSound.play(SystemSoundType.click);
  }

  @override
  Widget build(BuildContext context) {
    final knowledge = ref.watch(knowledgeProvider);
    final game = ref.watch(gameProvider);
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
              onPressed: _busy ? null : () => controller.start(game.stage),
              icon: const Icon(Icons.restart_alt),
            ),
        ],
      ),
      bottomNavigationBar:
          game == null || game.cleared
              ? null
              : _craftControls(game, controller),
      body: SafeArea(
        child: knowledge.when(
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
              (service) =>
                  game == null
                      ? const SizedBox.shrink()
                      : _play(game, service, controller, motion),
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
    final hinted = game.lastHintedCraft;
    final accent = latest?.result == null ? colors.error : colors.primary;
    final index = service.stages.indexOf(stage);

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
                for (final option in service.stages)
                  ChoiceChip(
                    label: Text(
                      '${option.difficulty.name.toUpperCase()} ${option.difficulty.cardsRequired}장',
                    ),
                    selected: stage.id == option.id,
                    onSelected:
                        _busy
                            ? null
                            : (selected) {
                              if (selected) controller.start(option);
                            },
                  ),
              ],
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
                        Text('${game.moves}회 시도 · 기준 ${stage.parSteps}회'),
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
                  AnimatedBuilder(
                    animation: _impact,
                    builder: (context, _) {
                      final travel = (1 - (_impact.value / .28 - 1).abs())
                          .clamp(0.0, 1.0);
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          Transform.scale(
                            scale: 1 - travel * .13,
                            child: AnimatedSize(
                              duration: motion,
                              alignment: Alignment.topCenter,
                              child:
                                  game.selected.isEmpty
                                      ? Text(
                                        '보유 단어를 탭해 ${stage.difficulty.cardsRequired}장을 고르세요.',
                                      )
                                      : Wrap(
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
                          if (_busy && _impact.value >= .28)
                            Positioned.fill(
                              child: IgnorePointer(
                                child: CustomPaint(
                                  painter: _ImpactBurst(
                                    (_impact.value - .28) / .72,
                                    accent,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
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
                          Text(
                            [
                              latest.note,
                              if (latest.proximity != null)
                                '근접도 ${latest.proximity}%',
                            ].join(' · '),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (!game.cleared && hinted != null) ...[
                    const SizedBox(height: 8),
                    if (stage.difficulty == Difficulty.easy)
                      Text(
                        '다음 조합 · ${hinted.hint}',
                        textAlign: TextAlign.center,
                      )
                    else
                      ExpansionTile(
                        key: ValueKey(hinted.result?.word),
                        title: const Text('다음 조합 힌트'),
                        tilePadding: EdgeInsets.zero,
                        children: [
                          Text(hinted.hint!, textAlign: TextAlign.center),
                        ],
                      ),
                  ],
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
                                : () =>
                                    controller.start(service.stages[index + 1]),
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

  Widget _craftControls(GameState game, GameController controller) {
    final batchLabel =
        game.selected.isNotEmpty
            ? '선택 해제'
            : game.latest != null
            ? '이전 재료 선택'
            : '모두 선택';
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
                  _busy
                      ? null
                      : () {
                        HapticFeedback.selectionClick();
                        controller.toggleBatchSelection();
                      },
              child: Text(batchLabel),
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
      key: ValueKey(item.word),
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
                    subtitle: Text(outcome.note),
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

class _ImpactBurst extends CustomPainter {
  const _ImpactBurst(this.progress, this.color);

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final fade = 1 - progress;
    final travel = Curves.easeOutCubic.transform(progress);
    final paint =
        Paint()
          ..color = color.withValues(alpha: fade * .9)
          ..strokeWidth = 2.5 * fade + .5
          ..strokeCap = StrokeCap.round;
    canvas.drawCircle(
      center,
      16 * fade,
      Paint()..color = Colors.white.withValues(alpha: fade * .85),
    );
    for (var i = 0; i < 14; i++) {
      final direction = Offset.fromDirection(i * math.pi / 7);
      final reach = (i.isEven ? 94.0 : 62.0) * travel;
      canvas.drawLine(
        center + direction * (8 + reach * .6),
        center + direction * (18 + reach),
        paint,
      );
    }
    paint.style = PaintingStyle.stroke;
    canvas.drawCircle(center, 8 + travel * 53, paint);
  }

  @override
  bool shouldRepaint(_ImpactBurst oldDelegate) =>
      progress != oldDelegate.progress || color != oldDelegate.color;
}
