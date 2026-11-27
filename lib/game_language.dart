import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models.dart';

enum GameLanguage {
  korean('ko', '한국어'),
  english('en', 'English');

  const GameLanguage(this.code, this.label);

  final String code;
  final String label;

  static GameLanguage fromCode(String? code) => code == 'ko' ? korean : english;
}

final languageProvider = AsyncNotifierProvider<LanguageSettings, GameLanguage>(
  LanguageSettings.new,
);

class LanguageSettings extends AsyncNotifier<GameLanguage> {
  static const _channel = MethodChannel('wordlink/settings');

  @override
  Future<GameLanguage> build() async {
    final device =
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    try {
      final saved = await _channel.invokeMethod<String>('getLanguage');
      return GameLanguage.fromCode(saved ?? device);
    } on MissingPluginException {
      return GameLanguage.fromCode(device);
    }
  }

  Future<void> select(GameLanguage language) async {
    state = AsyncData(language);
    try {
      await _channel.invokeMethod<void>('setLanguage', language.code);
    } on MissingPluginException {
      // Widget tests and non-mobile runners still switch language in memory.
    }
  }
}

String gameText(BuildContext context, String korean, String english) =>
    Localizations.localeOf(context).languageCode == 'ko' ? korean : english;

String gameWord(BuildContext context, WordItem item) =>
    gameText(context, item.koreanLabel ?? item.label, item.label);
