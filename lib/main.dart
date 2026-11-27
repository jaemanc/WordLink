import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'home_screen.dart';
import 'game_language.dart';

void main() => runApp(const ProviderScope(child: WordLinkApp()));

class WordLinkApp extends ConsumerWidget {
  const WordLinkApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language =
        ref.watch(languageProvider).asData?.value ??
        GameLanguage.fromCode(
          WidgetsBinding.instance.platformDispatcher.locale.languageCode,
        );
    return MaterialApp(
      title: 'WordLink',
      locale: Locale(language.code),
      supportedLocales: const [Locale('ko'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff95efca),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xff08212b),
      ),
      home: const HomeScreen(),
    );
  }
}
