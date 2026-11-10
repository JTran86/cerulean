import 'dart:ui';

import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/layouts/conversation_list/pages/conversation_list.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/header/header_widgets.dart';
import 'package:bluebubbles/app/layouts/conversation_list/pages/search/search_view.dart';
import 'package:bluebubbles/app/wrappers/fade_on_scroll.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class CupertinoHeader extends StatelessWidget {
  const CupertinoHeader({super.key, required this.controller});

  final ConversationListController controller;

  @override
  Widget build(BuildContext context) {
    final double topMargin = context.orientation == Orientation.landscape && context.isPhone
        ? 20
        : kIsDesktop
            ? 12
            : kIsWeb
                ? 40
                : kToolbarHeight + 30;

    return SliverToBoxAdapter(
      child: FadeOnScroll(
        scrollController: controller.iosScrollController,
        zeroOpacityOffset: topMargin + 15,
        child: Container(
          margin: EdgeInsets.only(
            top: topMargin,
            left: kIsDesktop ? 12 : 20,
            right: kIsDesktop ? 12 : 20,
            bottom: kIsDesktop ? 8 : 5,
          ),
          child: Obx(() {
            NavigationSvc.listener.value;
            // Desktop: the Messages-for-Mac header, a search field with the filter and compose buttons beside it.
            if (kIsDesktop && !NavigationSvc.isAvatarOnly(context)) {
              return _MacHeaderRow(controller: controller);
            }
            return Row(
              mainAxisAlignment:
                  NavigationSvc.isAvatarOnly(context) ? MainAxisAlignment.center : MainAxisAlignment.spaceBetween,
              children: <Widget>[
                if (!NavigationSvc.isAvatarOnly(context))
                  Expanded(
                    child: HeaderText(controller: controller),
                  ),
                if (NavigationSvc.isAvatarOnly(context))
                  Material(
                    color: Colors.transparent,
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: OverflowMenu(extraItems: true, controller: controller),
                  ),
                if (!NavigationSvc.isAvatarOnly(context))
                  Row(
                    mainAxisSize: MainAxisSize.max,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const SyncIndicator(size: 16),
                      const SizedBox(width: 10.0),
                      ClipOval(
                        child: Material(
                          color: context.theme.colorScheme.surfaceContainerHighest,
                          child: SizedBox(
                            width: 30,
                            height: 30,
                            child: InkWell(
                              child: Icon(CupertinoIcons.search,
                                  color: context.theme.colorScheme.onSurfaceVariant, size: 18),
                              onTap: () {
                                NavigationSvc.pushLeft(context, const SearchView());
                              },
                            ),
                          ),
                        ),
                      ),
                      const CupertinoChatListFilterButton(),
                      const SizedBox(width: 10.0),
                      if (SettingsSvc.settings.moveChatCreatorToHeader.value)
                        ClipOval(
                          child: Material(
                            color: context.theme.colorScheme.surfaceContainerHighest,
                            child: InkWell(
                              child: SizedBox(
                                width: 30,
                                height: 30,
                                child: Icon(
                                  CupertinoIcons.pencil,
                                  color: context.theme.colorScheme.onSurfaceVariant,
                                  size: 20,
                                ),
                              ),
                              onTap: () => controller.openNewChatCreator(context),
                            ),
                          ),
                        ),
                      if (SettingsSvc.settings.moveChatCreatorToHeader.value &&
                          SettingsSvc.settings.cameraFAB.value &&
                          !kIsWeb &&
                          !kIsDesktop)
                        const SizedBox(width: 10.0),
                      if (SettingsSvc.settings.moveChatCreatorToHeader.value &&
                          SettingsSvc.settings.cameraFAB.value &&
                          !kIsWeb &&
                          !kIsDesktop)
                        ClipOval(
                          child: Material(
                            color: context.theme.colorScheme.surfaceContainerHighest,
                            child: InkWell(
                                child: SizedBox(
                                  width: 30,
                                  height: 30,
                                  child: Icon(CupertinoIcons.camera,
                                      color: context.theme.colorScheme.onSurfaceVariant, size: 20),
                                ),
                                onTap: () => controller.openCamera(context)),
                          ),
                        ),
                      if (SettingsSvc.settings.moveChatCreatorToHeader.value) const SizedBox(width: 10.0),
                      const Material(
                        color: Colors.transparent,
                        shape: CircleBorder(),
                        clipBehavior: Clip.antiAlias,
                        child: OverflowMenu(),
                      ),
                    ],
                  ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

/// Search field, filter and compose, in the style of the Messages sidebar on the Mac.
class _MacHeaderRow extends StatelessWidget {
  const _MacHeaderRow({required this.controller});

  final ConversationListController controller;

  @override
  Widget build(BuildContext context) {
    final fill = context.theme.colorScheme.onSurface.withValues(alpha: 0.09);
    final muted = context.theme.colorScheme.outline;
    return Row(
      children: [
        Expanded(
          child: Material(
            color: fill,
            borderRadius: BorderRadius.circular(9),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => NavigationSvc.pushLeft(context, const SearchView()),
              child: SizedBox(
                height: 30,
                child: Row(
                  children: [
                    const SizedBox(width: 9),
                    Icon(CupertinoIcons.search, size: 14, color: muted),
                    const SizedBox(width: 6),
                    Text("Search", style: context.theme.textTheme.bodyMedium!.copyWith(fontSize: 13.5, color: muted)),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        const SyncIndicator(size: 14),
        const CupertinoChatListFilterButton(),
        const SizedBox(width: 4),
        Tooltip(
          message: "New message",
          child: InkResponse(
            radius: 18,
            onTap: () => controller.openNewChatCreator(context),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(CupertinoIcons.pencil, size: 19, color: context.theme.colorScheme.onSurface),
            ),
          ),
        ),
        const Material(
          color: Colors.transparent,
          shape: CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: OverflowMenu(),
        ),
      ],
    );
  }
}

class CupertinoMiniHeader extends StatelessWidget {
  const CupertinoMiniHeader({super.key, required this.controller});

  final ConversationListController controller;

  @override
  Widget build(BuildContext context) {
    final double topMargin = context.orientation == Orientation.landscape && context.isPhone
        ? 20
        : kIsDesktop || kIsWeb
            ? 60
            : kToolbarHeight + 30;

    return IgnorePointer(
      child: FadeOnScroll(
        scrollController: controller.iosScrollController,
        fullOpacityOffset: topMargin + 15,
        child: ClipRect(
          child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Obx(() {
                NavigationSvc.listener.value;
                return Container(
                  width: NavigationSvc.width(context),
                  height: (topMargin - 20).clamp(kIsDesktop ? 65 : 40, double.infinity),
                  color: context.theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: kIsDesktop ? 10 : 5),
                    child: Text(
                      controller.showArchivedChats
                          ? "Archive"
                          : controller.showUnknownSenders
                              ? "Unknown Senders"
                              : "Messages",
                      style: context.textTheme.titleMedium!.copyWith(color: context.theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                );
              })),
        ),
      ),
    );
  }
}
