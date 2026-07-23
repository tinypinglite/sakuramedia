import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/features/media/presentation/providers/invalid_media_provider.dart';
import 'package:sakuramedia/features/media/presentation/widgets/shared/invalid_media_section.dart';
import 'package:sakuramedia/features/shared/presentation/hooks/paged_scroll_hook.dart';
import 'package:sakuramedia/widgets/base/interaction/refresh/app_page_refresh_scope.dart';

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
      onReachBottom:
          () => unawaited(ref.read(invalidMediaProvider.notifier).loadMore()),
      enabled: active,
    );

    if (!active) {
      return const SizedBox.shrink(
        key: Key('desktop-media-maintenance-page-inactive'),
      );
    }

    return AppPageRefreshScope(
      onRefresh: () => _refresh(ref),
      child: InvalidMediaSection(
        key: const Key('desktop-media-maintenance-page'),
        scrollController: scrollController,
      ),
    );
  }

  Future<void> _refresh(WidgetRef ref) async {
    final error = await ref.read(invalidMediaProvider.notifier).refresh();
    if (error != null) {
      // provider 约定：refresh 用返回值传错误文案（不抛异常），这里直接 toast。
      showToast(error);
    }
  }
}
