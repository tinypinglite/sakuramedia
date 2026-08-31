import 'package:flutter/material.dart';
import 'package:sakuramedia/features/media/presentation/pages/shared/media_management_content.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';

/// 「媒体管理」移动端壳：三 tab 布局与全部编排逻辑在 [MediaManagementContent]，
/// 壳只注入 Key 前缀、根 Key、移动端布局开关与跳影片详情的导航回调。
class MobileMediaManagementPage extends StatelessWidget {
  const MobileMediaManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MediaManagementContent(
      keyPrefix: 'mobile-media-management',
      rootKey: const Key('mobile-media-management-page'),
      mobile: true,
      onOpenMovieDetail: (context, movieNumber) =>
          context.pushMobileMovieDetail(movieNumber: movieNumber),
    );
  }
}
