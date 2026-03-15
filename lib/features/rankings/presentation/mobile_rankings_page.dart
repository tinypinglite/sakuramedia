import 'package:flutter/material.dart';
import 'package:sakuramedia/widgets/app_shell/app_empty_state.dart';

class MobileRankingsPage extends StatelessWidget {
  const MobileRankingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppEmptyState(
      key: Key('mobile-rankings-page'),
      message: '开发中',
    );
  }
}
