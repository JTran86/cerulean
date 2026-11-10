import 'dart:convert';

/// The word being typed (or just finished) at the caret, as a half-open range into the text.
class WordRange {
  const WordRange(this.start, this.end, this.word);

  final int start;
  final int end;
  final String word;
}

/// Finds the word the caret is touching: either the caret is at the end of a word, or it sits right after the single
/// space that follows a word (so a suggestion stays available until the next letter is typed). Returns null otherwise.
WordRange? wordRangeAtCaret(String text, int caret) {
  if (caret <= 0 || caret > text.length) return null;
  var end = caret;
  if (text[caret - 1] == ' ') {
    if (caret < 2 || text[caret - 2] == ' ') return null;
    end = caret - 1;
  }
  final letters = RegExp(r"[A-Za-z']");
  var start = end;
  while (start > 0 && letters.hasMatch(text[start - 1])) {
    start--;
  }
  if (start == end) return null;
  // Not the middle of a longer token (handles, tags, paths, shortcodes, numbers).
  if (start > 0 && '@#/:_.\\0123456789'.contains(text[start - 1])) return null;
  // The caret must not be inside a word that continues after it.
  if (end == caret && caret < text.length && letters.hasMatch(text[caret])) return null;
  return WordRange(start, end, text.substring(start, end));
}

/// iOS QuickType-style emoji suggestions: type a word like "pizza" or "happy" and get 🍕 or 😊 offered in its place.
/// Entirely local: it works from a bundled keyword list (one emoji per line: `emoji<TAB>label<TAB>tag,tag,...`).
///
/// Plain Dart (no Flutter imports) so it can be exercised from the command line.
class EmojiSuggester {
  EmojiSuggester(String keywordTsv) {
    var index = 0;
    for (final line in const LineSplitter().convert(keywordTsv)) {
      final parts = line.split('\t');
      if (parts.length < 3) continue;
      final emoji = parts[0];
      final label = parts[1];
      _emoji.add(emoji);
      if (!label.contains(' ')) _add(label, index, 100); // "pizza" -> 🍕
      for (final w in label.split(RegExp(r'[\s\-:,]+'))) {
        _add(w, index, 70); // a word in the emoji's own name beats a loose keyword
      }
      for (final tag in parts[2].split(',')) {
        _add(tag, index, 60);
      }
      index++;
    }
  }

  final List<String> _emoji = [];
  final Map<String, Map<int, int>> _index = {};

  void _add(String word, int emojiIndex, int weight) {
    final w = word.trim().toLowerCase();
    if (w.length < 2) return;
    final entry = _index.putIfAbsent(w, () => {});
    if ((entry[emojiIndex] ?? 0) < weight) entry[emojiIndex] = weight;
  }

  int get size => _emoji.length;

  /// Words that name lots of emoji without meaning any one of them.
  static const Set<String> _generic = {
    'face', 'faces', 'hand', 'hands', 'man', 'men', 'woman', 'women', 'person', 'people', 'boy', 'girl', 'red',
    'blue', 'green', 'yellow', 'black', 'white', 'orange', 'purple', 'brown', 'big', 'small', 'sign', 'symbol',
    'mark', 'button', 'square', 'circle', 'arrow', 'flag', 'new', 'old', 'open', 'close', 'closed', 'head', 'eyes',
    'eye', 'mouth', 'body', 'thing', 'things', 'time', 'day', 'night', 'year', 'part', 'one', 'two', 'three', 'four',
    'five', 'six', 'seven', 'the', 'and', 'for', 'you', 'are', 'was', 'with', 'that', 'this', 'have', 'not', 'but',
    'all', 'can', 'her', 'his', 'out', 'get', 'got', 'just', 'like', 'its', 'they', 'what', 'when', 'who', 'how',
    'why', 'will', 'would', 'could', 'should', 'your', 'from', 'about', 'there', 'here', 'then', 'than', 'them',
    'been', 'being', 'more', 'some', 'any', 'now', 'too', 'very', 'also', 'only', 'even', 'much', 'many', 'because',
    'going', 'gonna', 'want', 'need', 'think', 'know', 'see', 'say', 'said', 'make', 'take', 'come', 'back', 'still',
    'well', 'really', 'right', 'left', 'down', 'up', 'over', 'under', 'off', 'into', 'such', 'each', 'other', 'next',
    'last', 'first', 'good', 'bad',
  };

  /// Texting shorthand and everyday feelings that the keyword data doesn't link the way a person would.
  static const Map<String, List<String>> _aliases = {
    'happy': ['😊', '😀', '😄'],
    'sad': ['😢', '😞', '☹️'],
    'love': ['❤️', '😍', '🥰'],
    'lol': ['😂', '🤣'],
    'lmao': ['🤣', '😂'],
    'haha': ['😂', '🤣'],
    'omg': ['😱', '😮', '🤯'],
    'idk': ['🤷'],
    'thanks': ['🙏', '😊'],
    'thank': ['🙏', '😊'],
    'thx': ['🙏'],
    'ty': ['🙏'],
    'please': ['🙏', '🥺'],
    'pls': ['🙏', '🥺'],
    'yes': ['👍', '✅'],
    'yep': ['👍'],
    'yay': ['🎉', '🥳'],
    'ok': ['👌', '👍'],
    'okay': ['👌', '👍'],
    'cool': ['😎', '👍'],
    'party': ['🎉', '🥳'],
    'birthday': ['🎂', '🎉', '🥳'],
    'congrats': ['🎉', '👏'],
    'hungry': ['🍕', '😋'],
    'tired': ['😴', '🥱'],
    'sleep': ['😴', '💤'],
    'angry': ['😡', '😠'],
    'mad': ['😡', '😠'],
    'cry': ['😭', '😢'],
    'crying': ['😭', '😢'],
    'wow': ['😮', '🤩'],
    'sorry': ['🥺', '🙏'],
    'miss': ['🥺', '💔'],
    'hug': ['🤗'],
    'kiss': ['😘', '💋'],
    'fire': ['🔥'],
    'lit': ['🔥'],
    'great': ['🙌', '👏'],
    'awesome': ['🙌', '🤩'],
    'nice': ['👍', '😊'],
    'goodnight': ['😴', '🌙'],
    'bye': ['👋'],
    'hello': ['👋', '😊'],
    'hi': ['👋'],
    'hey': ['👋'],
    'smile': ['😊', '😁'],
    'laugh': ['😂', '🤣'],
    'funny': ['😂', '🤣'],
    'think': ['🤔'],
    'thinking': ['🤔'],
    'hmm': ['🤔'],
    'eyeroll': ['🙄'],
    'ugh': ['😩', '😫'],
    'bruh': ['😐', '💀'],
    'rip': ['💀', '⚰️'],
    'dead': ['💀', '😂'],
    'snow': ['❄️', '⛄'],
    'rain': ['🌧️', '☔'],
    'beach': ['🏖️', '🌊'],
    'music': ['🎵', '🎶'],
    'money': ['💰', '💵'],
    'game': ['🎮', '🕹️'],
    'phone': ['📱', '☎️'],
    'book': ['📖', '📚'],
    'gift': ['🎁'],
    'work': ['💼', '💻'],
    'school': ['🏫', '📚'],
    'food': ['🍔', '🍕'],
    'drink': ['🍹', '🥤'],
    'gym': ['🏋️', '💪'],
    'flight': ['✈️'],
    'travel': ['✈️', '🧳'],
    'sun': ['☀️', '🌞'],
  };

  /// Emoji people actually reach for first; used to break ties between equally good matches.
  static const Set<String> _popular = {
    '❤️', '😂', '🤣', '😍', '🥰', '😊', '🙏', '👍', '🔥', '🎉', '😭', '😘', '😎', '🤔', '🥺', '😅', '✨', '💯', '👏',
    '🙌', '😢', '😡', '😴', '🍕', '🎂', '🐶', '🐱', '☕', '🍺', '🚗', '🏠', '🌞', '🌈', '💀', '🤷', '👀', '😁', '😀',
  };

  static String _singular(String w) {
    if (w.length > 4 && w.endsWith('ies')) return '${w.substring(0, w.length - 3)}y';
    if (w.length > 4 && w.endsWith('es')) return w.substring(0, w.length - 2);
    if (w.length > 3 && w.endsWith('s')) return w.substring(0, w.length - 1);
    return w;
  }

  /// Up to [max] emoji for [word], best first, or an empty list when the word has no clear emoji.
  List<String> suggest(String word, {int max = 3}) {
    final w = word.toLowerCase().replaceAll('’', "'");
    if (w.length < 3 && !_aliases.containsKey(w)) return const [];
    if (RegExp(r'[^a-z+]').hasMatch(w)) return const [];

    final curated = _aliases[w];
    if (curated != null) return curated.take(max).toList();
    final out = <String>[];
    if (_generic.contains(w)) return out;

    final scores = <int, double>{};
    void collect(String key, double factor) {
      final entry = _index[key];
      if (entry == null) return;
      entry.forEach((i, weight) {
        final score = weight * factor + (_popular.contains(_emoji[i]) ? 20 : 0) - i / 4000.0;
        if ((scores[i] ?? -1e9) < score) scores[i] = score;
      });
    }

    collect(w, 1.0);
    final singular = _singular(w);
    if (singular != w) collect(singular, 0.9);

    final ranked = scores.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final floor = ranked.isEmpty ? 0.0 : ranked.first.value - 35; // drop weak runners-up
    for (final e in ranked) {
      if (e.value < floor) break;
      final emoji = _emoji[e.key];
      if (!out.contains(emoji)) out.add(emoji);
      if (out.length >= max) break;
    }
    return out;
  }
}
