/// THIS FILE IS A PLACEHOLDER FILE SO ANDROID / DESKTOP WILL STILL COMPILE
/// THE REAL API KEY IS PLACED WITHIN /html/klipy.dart (LOCAL ONLY!!)
/// DO NOT CHECK /html/klipy.dart INTO VCS
library bluebubbles;

import 'dart:io';

const KLIPY_API_KEY = "";

/// The Klipy (GIF) API key: the build's `.env` first, otherwise the first line of `~/.config/cerulean/klipy.key`, so
/// a key can be added without rebuilding. Empty when neither exists (the GIF picker then shows nothing).
String klipyApiKey(String? fromEnv) {
  if (fromEnv != null && fromEnv.trim().isNotEmpty) return fromEnv.trim();
  try {
    final home = Platform.environment['HOME'];
    if (home == null) return '';
    final file = File('$home/.config/cerulean/klipy.key');
    return file.existsSync() ? file.readAsLinesSync().firstWhere((l) => l.trim().isNotEmpty, orElse: () => '').trim() : '';
  } catch (_) {
    return '';
  }
}
