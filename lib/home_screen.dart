import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'game_language.dart';
import 'game_screen.dart';
import 'inference_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = Localizations.localeOf(context).languageCode;
    final language = GameLanguage.fromCode(locale);
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          color: Color(0xff08212b),
          image: DecorationImage(
            image: AssetImage('assets/workshop_background.jpg'),
            fit: BoxFit.fill,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  children: [
                    const Icon(
                      Icons.auto_awesome,
                      size: 34,
                      color: Color(0xffffd990),
                    ),
                    const SizedBox(height: 12),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        gameText(context, '워드링크', 'WORDLINK'),
                        style: const TextStyle(
                          color: Color(0xffffefd4),
                          fontSize: 52,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.5,
                          shadows: [
                            Shadow(
                              color: Color(0xffc98d48),
                              offset: Offset(0, 3),
                            ),
                            Shadow(color: Color(0x604bf4cb), blurRadius: 24),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      gameText(
                        context,
                        '카드를 합쳐 새 단어를 발견하세요.',
                        'Combine cards to discover new words.',
                      ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xffc5dedb),
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 36),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xeb315659), Color(0xfa16333e)],
                        ),
                        borderRadius: BorderRadius.circular(23),
                        border: Border.all(color: const Color(0xff659b8f)),
                        boxShadow: const [
                          BoxShadow(color: Color(0x3441bf9e), blurRadius: 24),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            gameText(context, '게임 언어', 'Game language'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xffffe1a7),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SegmentedButton<GameLanguage>(
                            expandedInsets: EdgeInsets.zero,
                            segments: [
                              for (final option in GameLanguage.values)
                                ButtonSegment(
                                  value: option,
                                  label: Text(option.label),
                                ),
                            ],
                            selected: {language},
                            showSelectedIcon: false,
                            onSelectionChanged:
                                (choice) => ref
                                    .read(languageProvider.notifier)
                                    .select(choice.single),
                          ),
                          const SizedBox(height: 18),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 54),
                              backgroundColor: const Color(0xffa1f3cf),
                              foregroundColor: colors.onPrimary,
                              textStyle: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            icon: const Icon(Icons.play_arrow_rounded),
                            onPressed:
                                () => Navigator.of(context).push<void>(
                                  MaterialPageRoute(
                                    builder: (_) => const InferenceScreen(),
                                  ),
                                ),
                            label: Text(
                              gameText(
                                context,
                                '단어 추리 시작',
                                'Play word inference',
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed:
                                () => Navigator.of(context).push<void>(
                                  MaterialPageRoute(
                                    builder: (_) => const GameScreen(),
                                  ),
                                ),
                            child: Text(
                              gameText(context, '기존 카드 캠페인', 'Card campaign'),
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
      ),
    );
  }
}
