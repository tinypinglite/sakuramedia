import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/features/videos/data/persons_api.dart';
import 'package:sakuramedia/features/videos/data/videos_api.dart';
import 'package:sakuramedia/features/videos/presentation/paged_video_summary_controller.dart';
import 'package:sakuramedia/routes/app_route_paths.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/app_paged_load_more_footer.dart';
import 'package:sakuramedia/widgets/videos/video_summary_grid.dart';

/// 人物详情页：展示该人物关联的视频列表（按 person_id 过滤复用视频列表底座）。
class DesktopPersonDetailPage extends StatefulWidget {
  const DesktopPersonDetailPage({
    super.key,
    required this.personId,
    this.fallbackPath,
  });

  final int personId;
  final String? fallbackPath;

  @override
  State<DesktopPersonDetailPage> createState() =>
      _DesktopPersonDetailPageState();
}

class _DesktopPersonDetailPageState extends State<DesktopPersonDetailPage> {
  late final PagedVideoSummaryController _controller;
  String _personName = '人物详情';

  @override
  void initState() {
    super.initState();
    final videosApi = context.read<VideosApi>();
    _controller = PagedVideoSummaryController(
      fetchPage: (page, pageSize) => videosApi.getVideos(
        personIds: <int>[widget.personId],
        page: page,
        pageSize: pageSize,
      ),
    );
    _controller.attachScrollListener();
    _controller.initialize();
    _loadPersonName();
  }

  Future<void> _loadPersonName() async {
    try {
      final person =
          await context.read<PersonsApi>().getPerson(personId: widget.personId);
      if (mounted) {
        setState(() => _personName = person.name);
      }
    } catch (_) {
      // 头部名称获取失败不阻塞视频列表展示。
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.appColors.surfaceElevated,
      child: SingleChildScrollView(
        controller: _controller.scrollController,
        padding: EdgeInsets.all(context.appSpacing.lg),
        child: Column(
          key: const Key('person-detail-page'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _personName,
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s20,
                weight: AppTextWeight.semibold,
                tone: AppTextTone.primary,
              ),
            ),
            SizedBox(height: context.appSpacing.lg),
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final showFooter = _controller.items.isNotEmpty &&
                    (_controller.isLoadingMore ||
                        _controller.loadMoreErrorMessage != null);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    VideoSummaryGrid(
                      items: _controller.items,
                      isLoading: _controller.isInitialLoading,
                      errorMessage: _controller.initialErrorMessage,
                      onVideoTap: (video) =>
                          context.go('$desktopVideosPath/${video.id}'),
                      emptyMessage: '该人物暂无关联视频',
                    ),
                    if (showFooter) ...[
                      SizedBox(height: context.appSpacing.md),
                      AppPagedLoadMoreFooter(
                        isLoading: _controller.isLoadingMore,
                        errorMessage: _controller.loadMoreErrorMessage,
                        onRetry: _controller.loadMore,
                      ),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
