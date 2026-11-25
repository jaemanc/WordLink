import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'game_screen.dart';

void main() => runApp(const ProviderScope(child: WordLinkApp()));

class WordLinkApp extends StatelessWidget {
  const WordLinkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WordLink',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff95efca),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xff101816),
      ),
      home: const GameScreen(),
    );
  }
}
