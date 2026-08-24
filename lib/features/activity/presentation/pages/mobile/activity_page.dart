import 'package:flutter/material.dart';
import 'package:sakuramedia/features/activity/presentation/pages/desktop/activity_page.dart';

/// 移动端任务中心入口。
///
/// 任务、下载任务、轮询与手动触发均由跨端的 [DesktopActivityPage] 内容层承载；
/// 移动路由只提供子页面壳与移动端弹窗形态。
class MobileActivityPage extends StatelessWidget {
  const MobileActivityPage({super.key});

  @override
  Widget build(BuildContext context) => const DesktopActivityPage();
}
