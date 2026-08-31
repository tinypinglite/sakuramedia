import 'package:flutter/material.dart';
import 'package:sakuramedia/features/media/presentation/pages/shared/media_management_content.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';

/// 「媒体管理」桌面壳：三 tab 布局与全部编排逻辑在 [MediaManagementContent]，
/// 壳只注入 Key 前缀、根 Key 与跳影片详情的导航回调。
class DesktopMediaManagementPage extends StatelessWidget {
  const DesktopMediaManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MediaManagementContent(
      keyPrefix: 'media-management',
      rootKey: const Key('desktop-media-management-page'),
      onOpenMovieDetail: (context, movieNumber) =>
          context.pushDesktopMovieDetail(movieNumber: movieNumber),
    );
  }
}
