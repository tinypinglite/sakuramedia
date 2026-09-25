import 'package:sakuramedia/features/downloads/data/download_request_dto.dart';
import 'package:sakuramedia/features/downloads/presentation/providers/download_task_center_state.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// 下载任务列表加载态占位行：真实 [DownloadTaskDto] + [BoneMock] 文案，
/// 封面为 `null` 不触发网络请求，供 `AppSkeletonizer` 渲染与真实卡片同形的骨架。
List<DownloadTaskRowState> downloadTaskPlaceholders({int count = 3}) {
  return List<DownloadTaskRowState>.generate(
    count,
    (index) => DownloadTaskRowState(
      task: DownloadTaskDto(
        id: -1 - index,
        clientId: 1,
        movieNumber: 'ABC-${(index + 1).toString().padLeft(3, '0')}',
        name: BoneMock.words(3),
        remoteId: 'download-placeholder-${index + 1}',
        state: 'downloading',
        progress: 0.4,
        importStatus: '',
        importStatusLabel: '',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        movieTitle: BoneMock.words(3),
      ),
    ),
    growable: false,
  );
}
