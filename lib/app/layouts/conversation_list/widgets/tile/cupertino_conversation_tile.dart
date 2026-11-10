import 'package:bluebubbles/app/layouts/conversation_list/dialogs/conversation_peek_view.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/tile/conversation_tile.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/tile/trailing_state_mixin.dart';
import 'package:bluebubbles/app/state/chat_state_scope.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class CupertinoConversationTile extends CustomStateful<ConversationTileController> {
  const CupertinoConversationTile({super.key, required super.parentController});

  @override
  State<StatefulWidget> createState() => _CupertinoConversationTileState();
}

class _CupertinoConversationTileState extends CustomState<CupertinoConversationTile, void, ConversationTileController> {
  Offset? longPressPosition;

  @override
  void initState() {
    super.initState();
    tag = controller.chat.guid;
    // keep controller in memory since the widget is part of a list
    // (it will be disposed when scrolled out of view)
    forceDelete = false;
  }

  /// The Mac Messages sidebar row: unread dot, round avatar, bold name with the time on the right, two lines of
  /// preview, a rounded accent highlight when selected and a hairline between rows. Used on desktop only.
  Widget _macRow(BuildContext context, Widget leading) {
    final secondary = context.theme.colorScheme.outline;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        mouseCursor: MouseCursor.defer,
        borderRadius: BorderRadius.circular(10),
        hoverColor: context.theme.colorScheme.onSurface.withValues(alpha: 0.05),
        splashColor: Colors.transparent,
        onTap: () => controller.onTap(context),
        onSecondaryTapUp: (details) => controller.onSecondaryTap(Get.context!, details),
        child: Obx(() {
          final selected = controller.shouldHighlight.value;
          final onAccent = context.theme.colorScheme.onBubble(context, controller.chat.isIMessage);
          return Padding(
            padding: const EdgeInsets.fromLTRB(0, 8, 10, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                leading,
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: ChatTitle(
                              parentController: controller,
                              style: context.theme.textTheme.bodyMedium!.copyWith(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                height: 1.25,
                                color: selected ? onAccent : null,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          MacTrailing(parentController: controller),
                        ],
                      ),
                      const SizedBox(height: 1),
                      controller.subtitle ??
                          ChatSubtitle(
                            parentController: controller,
                            style: context.theme.textTheme.bodySmall!.copyWith(
                              fontSize: 12.5,
                              height: 1.25,
                              color: selected ? onAccent.withValues(alpha: 0.85) : secondary,
                            ),
                          ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mac = kIsDesktop && !NavigationSvc.isAvatarOnly(context);
    final leading = ChatLeading(
      controller: controller,
      unreadIcon: UnreadIcon(parentController: controller),
    );
    if (mac) {
      return ChatStateScope(
        chatState: controller.chatState,
        child: Obx(() {
          NavigationSvc.listener.value;
          final selected = controller.shouldHighlight.value;
          final line = context.theme.colorScheme.outline.withValues(alpha: 0.18);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  decoration: BoxDecoration(
                    color: controller.shouldPartialHighlight.value
                        ? context.theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
                        : selected
                            ? context.theme.colorScheme.bubble(context, controller.chat.isIMessage)
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: _macRow(context, leading),
                ),
                // Hairline that starts under the name, like Messages on the Mac.
                Padding(
                  padding: const EdgeInsets.only(left: 62, right: 4),
                  child: Container(height: 0.5, color: selected ? Colors.transparent : line),
                ),
              ],
            ),
          );
        }),
      );
    }
    final child = Material(
      color: Colors.transparent,
      child: InkWell(
        mouseCursor: MouseCursor.defer,
        onTap: () => controller.onTap(context),
        onSecondaryTapUp: (details) => controller.onSecondaryTap(Get.context!, details),
        onLongPress: kIsDesktop || kIsWeb
            ? null
            : () async {
                await peekChat(context, controller.chat, longPressPosition ?? Offset.zero);
              },
        onTapDown: (details) {
          longPressPosition = details.globalPosition;
        },
        child: Obx(() => ListTile(
            mouseCursor: MouseCursor.defer,
            enableFeedback: true,
            dense: SettingsSvc.settings.denseChatTiles.value,
            contentPadding: const EdgeInsets.only(left: 0),
            visualDensity: SettingsSvc.settings.denseChatTiles.value ? VisualDensity.compact : null,
            minVerticalPadding: 6,
            horizontalTitleGap: 10,
            title: Row(
              children: [
                Expanded(
                  child: ChatTitle(
                    parentController: controller,
                    style: context.theme.textTheme.bodyLarge!.copyWith(
                        fontWeight: controller.shouldHighlight.value ? FontWeight.w600 : FontWeight.w500,
                        color: controller.shouldHighlight.value
                            ? context.theme.colorScheme.onBubble(context, controller.chat.isIMessage)
                            : null),
                  ),
                ),
                const SizedBox(width: 10),
                CupertinoTrailing(parentController: controller),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(right: 20.0),
              child: controller.subtitle ??
                  ChatSubtitle(
                    parentController: controller,
                    style: context.theme.textTheme.bodyMedium!.copyWith(
                      color: controller.shouldHighlight.value
                          ? context.theme.colorScheme
                              .onBubble(context, controller.chat.isIMessage)
                              .withValues(alpha: 0.85)
                          : context.theme.colorScheme.outline,
                      height: 1.5,
                    ),
                  ),
            ),
            leading: leading)),
      ),
    );

    return ChatStateScope(
      chatState: controller.chatState,
      child: Obx(() {
        NavigationSvc.listener.value;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          decoration: BoxDecoration(
            color: controller.shouldPartialHighlight.value
                ? context.theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
                : controller.shouldHighlight.value
                    ? context.theme.colorScheme.bubble(context, controller.chat.isIMessage)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(
                controller.shouldHighlight.value || controller.shouldPartialHighlight.value ? 8 : 0),
          ),
          child: NavigationSvc.isAvatarOnly(context)
              ? InkWell(
                  mouseCursor: MouseCursor.defer,
                  onTap: () => controller.onTap(context),
                  onSecondaryTapUp: (details) => controller.onSecondaryTap(Get.context!, details),
                  onLongPress: kIsDesktop || kIsWeb
                      ? null
                      : () async {
                          await peekChat(context, controller.chat, longPressPosition ?? Offset.zero);
                        },
                  onTapDown: (details) {
                    longPressPosition = details.globalPosition;
                  },
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 10.0, horizontal: (NavigationSvc.width(context) - 100) / 2)
                        .add(const EdgeInsets.only(right: 15)),
                    child: leading,
                  ),
                )
              : child,
        );
      }),
    );
  }
}

class CupertinoTrailing extends CustomStateful<ConversationTileController> {
  const CupertinoTrailing({super.key, required super.parentController});

  @override
  State<StatefulWidget> createState() => _CupertinoTrailingState();
}

class _CupertinoTrailingState extends CustomState<CupertinoTrailing, void, ConversationTileController>
    with TrailingStateMixin<CupertinoTrailing> {
  @override
  Widget build(BuildContext context) {
    final chatState = ChatStateScope.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 15),
      child: Obx(() {
        final message = chatState.latestMessage.value;
        final indicator = computeIndicatorText(chatState.latestMessageStatus.value, controller.chat.isGroup);
        final hasError = (message?.error ?? 0) > 0;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              hasError ? "Error" : "${indicator.isNotEmpty ? "$indicator\n" : ""}${buildDate(message?.dateCreated)}",
              textAlign: TextAlign.right,
              style: context.theme.textTheme.bodySmall!
                  .copyWith(
                    color: hasError
                        ? context.theme.colorScheme.error
                        : controller.shouldHighlight.value
                            ? context.theme.colorScheme.onBubble(context, controller.chat.isIMessage)
                            : context.theme.colorScheme.outline.withValues(alpha: 0.75),
                    fontWeight: controller.shouldHighlight.value ? FontWeight.w500 : null,
                  )
                  .apply(fontSizeFactor: 1.15),
              overflow: TextOverflow.clip,
            ),
            const SizedBox(width: 8),
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(
                    CupertinoIcons.forward,
                    color: controller.shouldHighlight.value
                        ? context.theme.colorScheme.onBubble(context, controller.chat.isIMessage)
                        : context.theme.colorScheme.outline.withValues(alpha: 0.75),
                    size: 16,
                  ),
                ),
                if (chatState.muteType.value == "mute")
                  Positioned(
                    top: 22,
                    left: 0,
                    right: 0,
                    child: Icon(
                      CupertinoIcons.bell_slash_fill,
                      color: controller.shouldHighlight.value
                          ? context.theme.colorScheme.onBubble(context, controller.chat.isIMessage)
                          : context.theme.colorScheme.outline.withValues(alpha: 0.85),
                      size: 12,
                    ),
                  ),
              ],
            ),
          ],
        );
      }),
    );
  }
}

/// Time (and a muted-bell) on the right of a Mac-style row. No chevron.
class MacTrailing extends CustomStateful<ConversationTileController> {
  const MacTrailing({super.key, required super.parentController});

  @override
  State<StatefulWidget> createState() => _MacTrailingState();
}

class _MacTrailingState extends CustomState<MacTrailing, void, ConversationTileController>
    with TrailingStateMixin<MacTrailing> {
  @override
  Widget build(BuildContext context) {
    final chatState = ChatStateScope.of(context);
    return Obx(() {
      final message = chatState.latestMessage.value;
      final hasError = (message?.error ?? 0) > 0;
      final selected = controller.shouldHighlight.value;
      final color = hasError
          ? context.theme.colorScheme.error
          : selected
              ? context.theme.colorScheme.onBubble(context, controller.chat.isIMessage).withValues(alpha: 0.85)
              : context.theme.colorScheme.outline;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (chatState.muteType.value == "mute")
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(CupertinoIcons.bell_slash_fill, color: color, size: 11),
            ),
          Text(
            hasError ? "Error" : buildDate(message?.dateCreated),
            style: context.theme.textTheme.bodySmall!.copyWith(fontSize: 11.5, color: color),
            overflow: TextOverflow.clip,
            maxLines: 1,
          ),
        ],
      );
    });
  }
}

class UnreadIcon extends CustomStateful<ConversationTileController> {
  const UnreadIcon({super.key, required super.parentController});

  @override
  State<StatefulWidget> createState() => _UnreadIconState();
}

class _UnreadIconState extends CustomState<UnreadIcon, void, ConversationTileController> {
  @override
  void initState() {
    super.initState();
    tag = controller.chat.guid;
    // keep controller in memory since the widget is part of a list
    // (it will be disposed when scrolled out of view)
    forceDelete = false;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: kIsDesktop ? const EdgeInsets.only(left: 6.0, right: 4.0) : const EdgeInsets.only(left: 8.0, right: 6.0),
        child: Obx(() {
          final dot = kIsDesktop ? 9.0 : 12.0;
          final selected = controller.shouldHighlight.value;
          return (ChatsSvc.getChatState(controller.chat.guid)?.hasUnreadMessage.value ?? false)
              ? Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(35),
                    // On the blue selected row an accent dot would vanish, so it turns white there.
                    color: kIsDesktop && selected ? Colors.white : context.theme.colorScheme.primary,
                  ),
                  width: dot,
                  height: dot,
                )
              : SizedBox(width: dot);
        }));
  }
}
