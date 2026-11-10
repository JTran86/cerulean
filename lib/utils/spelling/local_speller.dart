import 'dart:convert';

/// A misspelled word found in a piece of text, with ranked replacements.
class SpellMistake {
  const SpellMistake({required this.offset, required this.length, required this.word, required this.suggestions});

  final int offset;
  final int length;
  final String word;
  final List<String> suggestions;

  int get endOffset => offset + length;
}

class _Candidate {
  const _Candidate(this.word, this.distance, this.frequency, this.score);

  final String word;
  final int distance;

  /// How common the word is.
  final int frequency;

  /// [frequency] scaled by how likely this kind of typo is (a swapped pair of letters beats a random substitution).
  final double score;
}

/// A small, fully local spell checker and autocorrector: nothing leaves the machine.
///
/// It works from a word-frequency list (one `word count` per line). Candidate corrections are every known word within
/// one edit (a deleted, swapped, replaced or inserted letter) of the misspelling, and within two edits when there is
/// nothing closer; they are ranked by distance first and how common the word is second. This is the classic
/// Norvig approach, cheap enough to run on every keystroke because each distinct word is only worked out once.
///
/// This class is plain Dart (no Flutter imports) so it can be run and checked from the command line.
class LocalSpeller {
  LocalSpeller(String frequencyDictionary, {String extraWords = ''}) {
    for (final line in const LineSplitter().convert(frequencyDictionary)) {
      final space = line.indexOf(' ');
      if (space <= 0) continue;
      _frequency[line.substring(0, space)] = int.tryParse(line.substring(space + 1).trim()) ?? 1;
    }
    for (final line in const LineSplitter().convert(extraWords)) {
      final word = line.trim().toLowerCase();
      if (word.isNotEmpty) _extra.add(word);
    }
  }

  final Map<String, int> _frequency = {};
  final Set<String> _extra = {};
  final Set<String> _ignored = {};
  final Map<String, List<_Candidate>> _candidateCache = {};

  static const String _letters = "abcdefghijklmnopqrstuvwxyz'";

  /// Common missing-apostrophe forms. iOS fixes these automatically.
  static const Map<String, String> _contractions = {
    'dont': "don't",
    'cant': "can't",
    'wont': "won't",
    'isnt': "isn't",
    'arent': "aren't",
    'wasnt': "wasn't",
    'werent': "weren't",
    'didnt': "didn't",
    'doesnt': "doesn't",
    'hasnt': "hasn't",
    'havent': "haven't",
    'hadnt': "hadn't",
    'couldnt': "couldn't",
    'wouldnt': "wouldn't",
    'shouldnt': "shouldn't",
    'im': "I'm",
    'ive': "I've",
    'youre': "you're",
    'youve': "you've",
    'theyre': "they're",
    'theyve': "they've",
    'thats': "that's",
    'whats': "what's",
    'heres': "here's",
    'theres': "there's",
    'lets': "let's",
    'thier': 'their',
    'alot': 'a lot',
  };

  int get dictionarySize => _frequency.length;

  /// Teach the checker a word (for example, after the user undoes an autocorrect of it).
  void ignore(String word) {
    final normalized = _normalize(word);
    if (normalized.isNotEmpty) _ignored.add(normalized);
  }

  Set<String> get ignoredWords => Set.unmodifiable(_ignored);

  static String _normalize(String word) {
    var w = word.toLowerCase().replaceAll('’', "'");
    while (w.startsWith("'")) {
      w = w.substring(1);
    }
    while (w.endsWith("'")) {
      w = w.substring(0, w.length - 1);
    }
    return w;
  }

  /// Whether this token is something we should leave alone entirely: numbers, acronyms, camelCase, single letters.
  static bool _skippable(String word) {
    if (word.length < 2) return true;
    if (RegExp(r'\d').hasMatch(word)) return true;
    final letters = word.replaceAll(RegExp(r"[^A-Za-z]"), '');
    if (letters.length > 1 && letters == letters.toUpperCase()) return true; // acronyms: NASA, USA
    if (RegExp(r'[a-z][A-Z]').hasMatch(word)) return true; // camelCase / iPhone-style
    return false;
  }

  bool _knownLower(String lower) => _frequency.containsKey(lower) || _extra.contains(lower) || _ignored.contains(lower);

  /// Whether [word] is a real word (a dictionary word, a texting word, or something the user taught us).
  bool isKnown(String word) {
    if (_skippable(word)) return true;
    final lower = _normalize(word);
    if (lower.isEmpty || _knownLower(lower)) return true;
    // Possessives: "dog's" is fine if "dog" is.
    if (lower.endsWith("'s") && _knownLower(lower.substring(0, lower.length - 2))) return true;
    return false;
  }

  int _score(String lower) => _frequency[lower] ?? (_extra.contains(lower) ? 1000000 : 0);

  /// Every string one edit away from [w], with a weight for how likely that kind of typo is.
  Iterable<(String, double)> _typedEdits1(String w) sync* {
    final n = w.length;
    for (var i = 0; i < n; i++) {
      // Dropping one of a doubled letter ("helllo" -> "hello") is a common slip.
      final doubled = (i > 0 && w[i] == w[i - 1]) || (i + 1 < n && w[i] == w[i + 1]);
      yield (w.substring(0, i) + w.substring(i + 1), doubled ? 20.0 : 1.0);
    }
    for (var i = 0; i < n - 1; i++) {
      if (w[i] == w[i + 1]) continue;
      // Two neighbouring letters swapped: by far the most common typing error.
      yield (w.substring(0, i) + w[i + 1] + w[i] + w.substring(i + 2), 50.0);
    }
    for (var i = 0; i < n; i++) {
      for (var j = 0; j < _letters.length; j++) {
        final c = _letters[j];
        if (c != w[i]) yield (w.substring(0, i) + c + w.substring(i + 1), 1.0);
      }
    }
    for (var i = 0; i <= n; i++) {
      for (var j = 0; j < _letters.length; j++) {
        final c = _letters[j];
        // A missing letter that doubles its neighbour ("helo" -> "hello") is a common slip too.
        final doubles = (i > 0 && w[i - 1] == c) || (i < n && w[i] == c);
        yield (w.substring(0, i) + c + w.substring(i), doubles ? 20.0 : 1.0);
      }
    }
  }

  List<_Candidate> _candidates(String lower) {
    return _candidateCache.putIfAbsent(lower, () {
      final found = <String, _Candidate>{};
      final edits1 = <String, double>{};
      for (final (e, weight) in _typedEdits1(lower)) {
        final current = edits1[e];
        if (current == null || weight > current) edits1[e] = weight;
      }
      edits1.forEach((e, weight) {
        if (_knownLower(e) && !_ignored.contains(e)) found[e] = _Candidate(e, 1, _score(e), _score(e) * weight);
      });
      if (found.isEmpty && lower.length >= 4 && lower.length <= 10) {
        for (final e1 in edits1.keys) {
          for (final (e2, _) in _typedEdits1(e1)) {
            if (!found.containsKey(e2) && _knownLower(e2) && !_ignored.contains(e2)) {
              found[e2] = _Candidate(e2, 2, _score(e2), _score(e2).toDouble());
            }
          }
        }
      }
      final list = found.values.toList()
        ..sort((a, b) {
          if (a.distance != b.distance) return a.distance.compareTo(b.distance);
          return b.score.compareTo(a.score);
        });
      return list;
    });
  }

  /// Ranked replacements for a misspelled [word], with the original's capitalization kept.
  List<String> suggest(String word, {int max = 5}) {
    final lower = _normalize(word);
    if (lower.isEmpty) return const [];
    final contraction = _contractions[lower];
    final out = <String>[if (contraction != null) _matchCase(word, contraction)];
    for (final c in _candidates(lower)) {
      final s = _matchCase(word, c.word);
      if (!out.contains(s)) out.add(s);
      if (out.length >= max) break;
    }
    return out.take(max).toList();
  }

  static String _matchCase(String original, String suggestion) {
    if (suggestion.isEmpty) return suggestion;
    final letters = original.replaceAll(RegExp(r"[^A-Za-z]"), '');
    if (letters.length > 1 && letters == letters.toUpperCase()) return suggestion.toUpperCase();
    if (original.isNotEmpty && original[0] != original[0].toLowerCase()) {
      return suggestion[0].toUpperCase() + suggestion.substring(1);
    }
    return suggestion;
  }

  /// The correction iOS-style autocorrect would apply when [word] is finished (space or punctuation typed), or null
  /// to leave the word alone. Deliberately conservative: it only acts when the fix is obvious.
  String? autocorrection(String word) {
    if (word == 'i') return 'I';
    if (_skippable(word)) return null;
    final lower = _normalize(word);
    if (_ignored.contains(lower)) return null;
    final contraction = _contractions[lower];
    if (contraction != null && !_ignored.contains(lower)) return _matchCase(word, contraction);
    if (isKnown(word)) return null;
    // A capitalised unknown word in the middle of a sentence is most likely a name; the caller passes
    // [atSentenceStart] through findMistakes, but autocorrect never rewrites capitalised words.
    if (word[0] != word[0].toLowerCase()) return null;
    final candidates = _candidates(lower);
    if (candidates.isEmpty || candidates.first.distance != 1) return null;
    final best = candidates.first;
    if (best.frequency < 20000) return null; // an uncommon target is a risky guess
    if (best.word.length < lower.length) return null; // never shorten a word ("ther" is not "the")
    if (candidates.length > 1 && candidates[1].distance == 1 && best.score < candidates[1].score * 4) {
      return null; // two plausible fixes: don't pick one for the user
    }
    return _matchCase(word, best.word);
  }

  /// All misspelled words in [text]. A word the caret is still touching at its end ([caret]) is skipped, because the
  /// user is probably mid-word.
  List<SpellMistake> findMistakes(String text, {int? caret}) {
    final result = <SpellMistake>[];
    final words = RegExp(r"[A-Za-z]+(?:['’][A-Za-z]+)*");
    for (final match in words.allMatches(text)) {
      final word = match.group(0)!;
      if (caret != null && caret == match.end && match.end == text.length) continue; // still typing it
      if (_skippable(word) || isKnown(word)) continue;

      // Leave handles, hashtags, paths, domains and words glued to digits alone.
      final before = match.start > 0 ? text[match.start - 1] : '';
      final after = match.end < text.length ? text[match.end] : '';
      if ('@#/_\\.'.contains(before) && before.isNotEmpty) continue;
      if (RegExp(r'\d').hasMatch(before) || RegExp(r'\d').hasMatch(after)) continue;
      if (text.startsWith('://', match.end)) continue; // the "https" of a link
      if (after == '/' || (after == '.' && match.end + 1 < text.length && RegExp(r'[A-Za-z]').hasMatch(text[match.end + 1]))) {
        continue;
      }

      // A capitalised word mid-sentence is almost always a name.
      final startsUpper = word[0] != word[0].toLowerCase();
      if (startsUpper && !_atSentenceStart(text, match.start)) continue;

      final suggestions = suggest(word);
      result.add(SpellMistake(offset: match.start, length: match.end - match.start, word: word, suggestions: suggestions));
    }
    return result;
  }

  static bool _atSentenceStart(String text, int index) {
    var i = index - 1;
    while (i >= 0 && (text[i] == ' ' || text[i] == '\t')) {
      i--;
    }
    return i < 0 || '.!?\n'.contains(text[i]);
  }
}
