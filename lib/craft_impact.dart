import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'game_language.dart';
import 'models.dart';

class CraftImpact extends StatelessWidget {
  const CraftImpact({
    super.key,
    required this.progress,
    required this.center,
    required this.cards,
    required this.outcome,
    this.destination,
    this.isNew = false,
    this.newBest = false,
  });

  static const collision = .34;

  final double progress;
  final Offset center;
  final List<({WordItem item, Offset from})> cards;
  final CraftOutcome? outcome;
  final Offset? destination;
  final bool isNew;
  final bool newBest;

  double get aftermath =>
      ((progress - collision) / (1 - collision)).clamp(0, 1).toDouble();

  Offset get recoil {
    final t = aftermath;
    final strength =
        outcome?.isTargetReached == true || newBest
            ? 14.0
            : outcome?.result != null
            ? 9.0
            : 3.0;
    final falloff = math.pow(1 - t, 4).toDouble() * strength;
    return Offset(math.sin(t * 37), math.sin(t * 29)) * falloff;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final result = outcome?.result;
    final hitColor =
        outcome?.isTargetReached == true || newBest
            ? const Color(0xffffc65c)
            : outcome?.isRecipeMatch == false
            ? const Color(0xffffcc86)
            : colors.primary;
    final t = aftermath;
    final transfer = Curves.easeInOut.transform(
      ((t - .34) / .66).clamp(0.0, 1.0).toDouble(),
    );
    final landing = Offset.lerp(center, destination ?? center, transfer)!;
    return ExcludeSemantics(
      child: IgnorePointer(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (progress < collision)
              for (final (index, card) in cards.indexed)
                _flyingCard(context, card, index, colors),
            if (progress >= collision && outcome != null) ...[
              Positioned.fill(
                child: CustomPaint(
                  painter: _Burst(center, t, hitColor, result != null),
                ),
              ),
              if (result != null)
                Positioned(
                  left: landing.dx,
                  top: landing.dy,
                  child: FractionalTranslation(
                    translation: const Offset(-.5, -.5),
                    child: Opacity(
                      opacity: ((1 - t) * 4).clamp(0, 1).toDouble(),
                      child: Transform.scale(
                        scale:
                            t < .23
                                ? .45 +
                                    Curves.easeOutBack.transform(t / .23) * .67
                                : 1.12 - .45 * transfer,
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 210),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: colors.surface,
                            border: Border.all(color: hitColor, width: 2),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: hitColor.withValues(alpha: .6),
                                blurRadius: 28,
                              ),
                            ],
                          ),
                          child: Text(
                            '${isNew ? gameText(context, '신규  ', 'NEW  ') : ''}${result.emoji} ${gameWord(context, result)}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: hitColor,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _flyingCard(
    BuildContext context,
    ({WordItem item, Offset from}) card,
    int index,
    ColorScheme colors,
  ) {
    final travel = progress / collision;
    final charge = -math.sin(travel * math.pi) * .13;
    final pull = Curves.easeInCubic.transform(travel) + charge;
    final point = Offset.lerp(card.from, center, pull)!;
    return Positioned(
      left: point.dx,
      top: point.dy,
      child: FractionalTranslation(
        translation: const Offset(-.5, -.5),
        child: Transform.rotate(
          angle: (index.isEven ? 1 : -1) * travel * .7,
          child: Transform.scale(
            scale: 1 - .6 * pull,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: colors.primary.withValues(alpha: .65),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                child: Text(
                  '${card.item.emoji} ${gameWord(context, card.item)}',
                  style: TextStyle(
                    color: colors.onPrimaryContainer,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Burst extends CustomPainter {
  const _Burst(this.center, this.progress, this.color, this.success);

  final Offset center;
  final double progress;
  final Color color;
  final bool success;

  @override
  void paint(Canvas canvas, Size size) {
    final fade = 1 - progress;
    final distance = Curves.easeOutCubic.transform(progress);
    final radius = (success ? 152.0 : 64.0) * (.16 + .84 * distance);
    final flash =
        Paint()
          ..shader = RadialGradient(
            colors: [
              Colors.white.withValues(
                alpha: fade * fade * (success ? .84 : .3),
              ),
              color.withValues(alpha: fade * .45),
              color.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, flash);

    final paint =
        Paint()
          ..style = PaintingStyle.stroke
          ..color = color.withValues(alpha: fade * .9)
          ..strokeWidth = 4 * fade + .5;
    canvas.drawCircle(center, radius, paint);
    if (success) {
      paint.color = color.withValues(alpha: fade * .55);
      canvas.drawCircle(center, radius * .61, paint);
    }

    paint.strokeCap = StrokeCap.round;
    for (var i = 0; i < (success ? 26 : 10); i++) {
      final direction = Offset.fromDirection(i * math.pi * .763);
      final reach = radius * (.45 + (i % 5) * .18);
      paint.color = (i % 4 == 0 ? Colors.white : color).withValues(alpha: fade);
      paint.strokeWidth = i.isEven ? 3 * fade + .5 : 1.5;
      canvas.drawLine(
        center + direction * (reach * .7),
        center + direction * (reach + 18 * fade),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_Burst old) =>
      center != old.center ||
      progress != old.progress ||
      color != old.color ||
      success != old.success;
}
