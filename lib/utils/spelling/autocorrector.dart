import 'package:bluebubbles/utils/spelling/local_speller.dart';

/// What the last autocorrect changed, so Backspace can undo it.
class _Autocorrection {
  const _Autocorrection({required this.start, required this.original, required this.corrected, required this.boundary});

  final int start;
  final String original;
  final String corrected;
  final String boundary;
}

/// iOS-style autocorrect, driven by one text change at a time.
///
/// When a space or punctuation mark is typed straight after a misspelled word, the word is replaced by its obvious
/// correction. Pressing Backspace immediately afterwards restores exactly what was typed and teaches the checker to
/// leave that word alone ([onUndo]).
///
/// Plain Dart (no Flutter imports) so it can be exercised from the command line.
class Autocorrector {
  Autocorrector({this.onUndo});

  /// Called with the original word when the user undoes an autocorrect of it.
  final void Function(String word)? onUndo;

  _Autocorrection? _last;

  static const String _boundaries = ' \n.,!?;';
  static final RegExp _trailingWord = RegExp(r"[A-Za-z]+(?:['’][A-Za-z]+)*$");

  /// Applies autocorrect to one edit. [oldText] is the text before the edit, [newText] and [newOffset] the text and
  /// caret after it. Returns the (possibly corrected) text and caret to use.
  (String, int) apply(LocalSpeller? speller, String oldText, String newText, int newOffset) {
    final undo = _last;
    _last = null;
    if (speller == null) return (newText, newOffset);

    // Backspace right after an autocorrect: put back what the user typed.
    if (undo != null) {
      final boundaryIndex = undo.start + undo.corrected.length;
      if (oldText.length == newText.length + 1 &&
          boundaryIndex < oldText.length &&
          oldText[boundaryIndex] == undo.boundary &&
          newOffset == boundaryIndex &&
          oldText.replaceRange(boundaryIndex, boundaryIndex + 1, '') == newText) {
        onUndo?.call(undo.original);
        return (newText.replaceRange(undo.start, boundaryIndex, undo.original), undo.start + undo.original.length);
      }
    }

    // A single character was typed at the caret, and it ends a word.
    if (newText.length != oldText.length + 1 || newOffset < 1 || newOffset > newText.length) return (newText, newOffset);
    if (newText.replaceRange(newOffset - 1, newOffset, '') != oldText) return (newText, newOffset);
    final typed = newText[newOffset - 1];
    if (!_boundaries.contains(typed)) return (newText, newOffset);

    final before = newText.substring(0, newOffset - 1);
    final match = _trailingWord.firstMatch(before);
    if (match == null) return (newText, newOffset);
    final word = match.group(0)!;
    final start = match.start;
    // Leave handles, hashtags, links, paths and words glued to numbers alone.
    final glue = start > 0 ? before[start - 1] : '';
    if (glue.isNotEmpty && '@#/_\\.-0123456789'.contains(glue)) return (newText, newOffset);

    final correction = speller.autocorrection(word);
    if (correction == null || correction == word) return (newText, newOffset);

    _last = _Autocorrection(start: start, original: word, corrected: correction, boundary: typed);
    final fixed = before.replaceRange(start, before.length, correction) + typed + newText.substring(newOffset);
    return (fixed, newOffset + correction.length - word.length);
  }
}
