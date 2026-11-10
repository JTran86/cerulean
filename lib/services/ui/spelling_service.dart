import 'dart:io';

import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:bluebubbles/utils/spelling/emoji_suggester.dart';
import 'package:bluebubbles/utils/spelling/local_speller.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart';

/// Owns the local spell checker: loads the bundled dictionary once and remembers the words the user teaches it
/// (for example by pressing Backspace right after an autocorrect). Nothing is sent over the network.
class SpellingService {
  SpellingService._();

  static const String _tag = 'SpellingService';

  static LocalSpeller? _speller;
  static EmojiSuggester? _emoji;
  static Future<void>? _loading;

  /// The checker, or null until [ensureLoaded] has finished.
  static LocalSpeller? get speller => _speller;

  /// Emoji suggestions for a word (iOS QuickType-style), or null until loaded.
  static EmojiSuggester? get emoji => _emoji;

  static Future<void> ensureLoaded() => _loading ??= _load();

  static String get _learnedPath => join(FilesystemSvc.appDocDir.path, 'learned_words.txt');

  static Future<void> _load() async {
    try {
      final dictionary = await rootBundle.loadString('assets/dictionaries/en_80k.txt');
      final texting = await rootBundle.loadString('assets/dictionaries/texting_words.txt');
      final speller = LocalSpeller(dictionary, extraWords: texting);
      final learned = File(_learnedPath);
      if (await learned.exists()) {
        for (final word in await learned.readAsLines()) {
          speller.ignore(word);
        }
      }
      _emoji = EmojiSuggester(await rootBundle.loadString('assets/dictionaries/emoji_keywords.tsv'));
      _speller = speller;
      Logger.info('Loaded ${speller.dictionarySize} words, ${speller.ignoredWords.length} learned', tag: _tag);
    } catch (e, s) {
      _loading = null; // allow another attempt
      Logger.error('Failed to load the spelling dictionary', error: e, trace: s, tag: _tag);
    }
  }

  /// Stop flagging or autocorrecting [word] from now on, and remember that across restarts.
  static void learn(String word) {
    final speller = _speller;
    if (speller == null) return;
    speller.ignore(word);
    File(_learnedPath).writeAsString('${word.toLowerCase()}\n', mode: FileMode.append).catchError((Object e) {
      Logger.warn('Could not save learned word', error: e, tag: _tag);
      return File(_learnedPath);
    });
  }
}
