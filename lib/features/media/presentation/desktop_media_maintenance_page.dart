import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sakuramedia/features/media/presentation/providers/invalid_media_provider.dart';
import 'package:sakuramedia/features/media/presentation/widgets/shared/invalid_media_section.dart';
import 'package:sakuramedia/features/shared/presentation/hooks/paged_scroll_hook.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_page_frame.dart';

/// 「媒体维护」（失效媒体巡检）桌面页（Riverpod）。
///
/// 本文件只承载「壳 + active 懒加载 + 滚动 loadMore」。业务展示与操作全部封装在
/// [InvalidMediaSection]（双端可复用的 ConsumerWidget）。
class DesktopMediaMaintenancePage extends HookConsumerWidget {
  const DesktopMediaMaintenancePage({super.key, this.active = true});

  /// 作为系统设置页 tab 嵌入时用于懒加载：仅在 tab 激活后才 watch provider。
  final bool active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scrollController = usePagedLoadMoreScroll(
      onReachBottom: () => unawaited(
        ref.read(invalidMediaProvider.notifier).loadMore(),
      ),
      enabled: active,
    );

    if (!active) {
      return AppPageFrame(
        title: '',
        scrollController: scrollController,
        child: const SizedBox.shrink(
          key: Key('desktop-media-maintenance-page-inactive'),
        ),
      );
    }

    return AppPageFrame(
      title: '',
      scrollController: scrollController,
      child: const Column(
        key: Key('desktop-media-maintenance-page'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [InvalidMediaSection()],
      ),
    );
  }
}
