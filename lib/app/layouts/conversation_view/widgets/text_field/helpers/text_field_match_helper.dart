import 'package:bluebubbles/app/components/custom_text_editing_controllers.dart';
import 'package:bluebubbles/utils/emoji.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/services/ui/spelling_service.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:bluebubbles/utils/spelling/emoji_suggester.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:unicode_emojis/unicode_emojis.dart';

/// Helper class for processing emoji and mention matches in the text field
class TextFieldMatchHelper {
  /// Process emoji matches based on text input
  /// This is debounced to avoid running regex on every keystroke
  static void processEmojiMatches(
    ConversationViewController controller,
    TextEditingController textController,
    bool isSubject,
  ) {
    final newEmojiText = textController.text;

    if (!newEmojiText.contains(":")) {
      controller.emojiMatches.value = [];
      controller.emojiSelectedIndex.value = 0;
      return;
    }

    final regExp = RegExp(r"(?<=^|[^a-zA-Z\d]):[^: \n]{2,}(?:(?=[ \n]|$)|:)", multiLine: true);
    final matches = regExp.allMatches(newEmojiText);
    List<Emoji> allMatches = [];
    String emojiName = "";

    if (matches.isNotEmpty && matches.first.start < textController.selection.start) {
      RegExpMatch match = matches.lastWhere((m) => m.start < textController.selection.start);
      if (newEmojiText[match.end - 1] == ":") {
        // This will get handled by the text field controller
      } else if (match.end >= textController.selection.start) {
        emojiName = newEmojiText.substring(match.start + 1, match.end).toLowerCase();
        allMatches = limitGenerator(emojiQuery(emojiName), limit: 50).toSet().toList();
      }
      Logger.info("${allMatches.length} matches found for: $emojiName");
    }

    if (allMatches.isNotEmpty) {
      controller.mentionMatches.value = [];
      controller.mentionSelectedIndex.value = 0;
      controller.emojiMatches.value = allMatches;
      controller.emojiSelectedIndex.value = 0;
    } else {
      controller.emojiMatches.value = [];
      controller.emojiSelectedIndex.value = 0;
    }
  }

  /// iOS QuickType-style emoji suggestions for the word at the caret ("pizza" -> 🍕). Cheap enough to run on every
  /// keystroke: it is a dictionary lookup. It stays out of the way of the `:shortcode:` and `@mention` lists.
  static void processEmojiWordSuggestions(
    ConversationViewController controller,
    TextEditingController textController,
    bool isSubject,
  ) {
    final emoji = SpellingService.emoji;
    if (isSubject || emoji == null || !SettingsSvc.settings.spellcheck.value) {
      if (controller.emojiWordSuggestions.isNotEmpty) controller.emojiWordSuggestions.clear();
      return;
    }
    final selection = textController.selection;
    final range = selection.isValid && selection.isCollapsed
        ? wordRangeAtCaret(textController.text, selection.start)
        : null;
    final suggestions = range == null || controller.emojiMatches.isNotEmpty || controller.mentionMatches.isNotEmpty
        ? const <String>[]
        : emoji.suggest(range.word);
    if (suggestions.isEmpty) {
      if (controller.emojiWordSuggestions.isNotEmpty) controller.emojiWordSuggestions.clear();
    } else if (!listEquals(controller.emojiWordSuggestions, suggestions)) {
      controller.emojiWordSuggestions.value = suggestions;
    }
  }

  /// Replaces the word at the caret with [emoji] and dismisses the suggestions.
  static void applyEmojiWordSuggestion(ConversationViewController controller, String emoji) {
    final field = controller.lastFocusedTextController;
    final selection = field.selection;
    final range = selection.isValid ? wordRangeAtCaret(field.text, selection.start) : null;
    controller.emojiWordSuggestions.clear();
    if (range == null) return;
    field.value = TextEditingValue(
      text: field.text.replaceRange(range.start, range.end, emoji),
      selection: TextSelection.collapsed(offset: range.start + emoji.length),
    );
    controller.lastFocusedNode.requestFocus();
  }

  /// Process mention matches based on text input
  /// This is debounced to avoid running regex on every keystroke
  static void processMentionMatches(
    ConversationViewController controller,
    TextEditingController textController,
    bool isSubject,
  ) {
    final newEmojiText = textController.text;

    if (isSubject || !newEmojiText.contains("@")) {
      controller.mentionMatches.value = [];
      controller.mentionSelectedIndex.value = 0;
      return;
    }

    final regExp = RegExp(r"(?<=^|[^a-zA-Z\d])@(?:[^@ \n]+|$)(?=[ \n]|$)", multiLine: true);
    final matches = regExp.allMatches(newEmojiText);
    List<Mentionable> allMatches = [];
    String mentionName = "";

    if (matches.isNotEmpty && matches.first.start < textController.selection.start) {
      RegExpMatch match = matches.lastWhere((m) => m.start < textController.selection.start);
      final text = newEmojiText.substring(match.start, match.end);

      if (text.endsWith("@")) {
        allMatches = controller.mentionables;
      } else if (newEmojiText[match.end - 1] == "@") {
        mentionName = newEmojiText.substring(match.start + 1, match.end - 1).toLowerCase();
        allMatches = controller.mentionables
            .where((e) =>
                e.address.toLowerCase().startsWith(mentionName.toLowerCase()) ||
                e.displayName.toLowerCase().startsWith(mentionName.toLowerCase()))
            .toList();
        allMatches.addAll(controller.mentionables
            .where((e) =>
                !allMatches.contains(e) &&
                (e.address.toLowerCase().contains(mentionName) || e.displayName.toLowerCase().contains(mentionName)))
            .toList());
      } else if (match.end >= textController.selection.start) {
        mentionName = newEmojiText.substring(match.start + 1, match.end).toLowerCase();
        allMatches = controller.mentionables
            .where((e) =>
                e.address.toLowerCase().startsWith(mentionName.toLowerCase()) ||
                e.displayName.toLowerCase().startsWith(mentionName.toLowerCase()))
            .toList();
        allMatches.addAll(controller.mentionables
            .where((e) =>
                !allMatches.contains(e) &&
                (e.address.toLowerCase().contains(mentionName) || e.displayName.toLowerCase().contains(mentionName)))
            .toList());
      }
      Logger.info("${allMatches.length} matches found for: $mentionName");
    }

    if (allMatches.isNotEmpty) {
      controller.emojiMatches.value = [];
      controller.emojiSelectedIndex.value = 0;
      controller.mentionMatches.value = allMatches;
      controller.mentionSelectedIndex.value = 0;
    } else {
      controller.mentionMatches.value = [];
      controller.mentionSelectedIndex.value = 0;
    }
  }
}
