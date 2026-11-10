import 'dart:async';
import 'dart:convert';

import 'package:bluebubbles/app/layouts/chat_creator/chat_creator.dart';
import 'package:bluebubbles/app/layouts/chat_creator/new_chat_creator.dart';
import 'package:bluebubbles/database/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:universal_io/io.dart';

import 'package:bluebubbles/helpers/backend/startup_tasks.dart';

/// Lets other programs on this machine ask the running client to do something (Linux desktop only), through a
/// Unix socket at `$XDG_RUNTIME_DIR/cerulean.sock` that only this user can reach. One command per line:
///
///     open <phone number or email>     open the conversation with that person (or start a new one)
///
/// Spotlight uses this to jump from a contact straight into their iMessage thread; `cerulean open ...` wraps it.
class ExternalCommandsService {
  ExternalCommandsService._();

  static const String _tag = 'ExternalCommands';
  static ServerSocket? _server;

  static String? get socketPath {
    final dir = Platform.environment['XDG_RUNTIME_DIR'];
    return dir == null ? null : '$dir/cerulean.sock';
  }

  static Future<void> start() async {
    if (kIsWeb || !Platform.isLinux || _server != null) return;
    final path = socketPath;
    if (path == null) return;
    try {
      final stale = File(path);
      if (stale.existsSync()) stale.deleteSync();
      _server = await ServerSocket.bind(InternetAddress(path, type: InternetAddressType.unix), 0);
      await Process.run('chmod', ['600', path]);
      _server!.listen((socket) {
        utf8.decoder.bind(socket).transform(const LineSplitter()).listen((line) async {
          try {
            await _handle(line.trim());
          } catch (e, s) {
            Logger.warn('Command failed: $line', error: e, trace: s, tag: _tag);
          }
        }, onDone: socket.destroy);
      });
      Logger.info('Listening for commands on $path', tag: _tag);
    } catch (e, s) {
      Logger.warn('Could not open the command socket', error: e, trace: s, tag: _tag);
    }
  }

  static Future<void> _handle(String line) async {
    if (line.startsWith('open ')) {
      await _openConversation(line.substring(5).trim());
    }
  }

  /// "+1 (904) 660-5984" -> "+19046605984"; emails are only lower-cased.
  static String normalizeAddress(String raw) {
    if (raw.contains('@')) return raw.toLowerCase();
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) return '+1$digits';
    return '+$digits';
  }

  static Future<void> _openConversation(String raw) async {
    if (raw.isEmpty) return;
    final address = normalizeAddress(raw);
    await StartupTasks.waitForUI();

    Chat? chat;
    for (final service in ['iMessage', 'SMS']) {
      chat = Chat.findOne(guid: '$service;-;$address');
      if (chat != null) break;
    }
    if (chat != null) {
      await IntentsSvc.openChat(chat.guid, isInitialIntent: false);
      return;
    }
    // No conversation yet: open the new-message screen with this person already picked.
    NavigationSvc.pushAndRemoveUntil(
      Get.context!,
      NewChatCreator(initialSelected: [SelectedContact(displayName: address, address: address)]),
      (route) => route.isFirst,
    );
  }
}
