/// 失败/跳过条目原因（`failed_files[].reason`）到中文文案的映射。
///
/// 镜像后端 `src/common/media_import_status.py` 的 `FAILURE_REASON_DESCRIPTIONS`。
/// 后端新增 reason 时同步补一行；未知 code 回落原值，保持「未知取值回退原值」的约定。
const Map<String, String> _kFailureReasonDescriptions = {
  'movie_number_not_found': '未识别番号：无法从文件名/路径解析出影片番号',
  'metadata_fetch_failed': '元数据抓取失败：从站点获取影片信息失败',
  'image_download_failed': '图片下载失败：影片封面/海报下载失败',
  'metadata_upsert_failed': '元数据入库失败：影片信息写入数据库失败',
  'media_import_failed': '文件导入失败：单个媒体文件搬运/落库异常',
  'multi_part_merge_failed': '多分段合并失败：多个分段文件合并为同一影片时出错',
  'file_too_small': '文件过小：低于最小体积阈值，按样本/残片跳过',
  'merge_subtitle_skipped_multiple_sidecars': '字幕未合并：多分段合并时发现多个外挂字幕，未自动合并',
  'source_delete_failed': '源文件删除失败：媒体已入库，但清理源文件失败（仅告警）',
  'import_job_crashed': '导入流程崩溃：导入过程整体异常中断',
  'import_job_bootstrap_failed': '作业启动失败：导入作业入队/引导阶段失败',
  'import_job_interrupted': '导入进程中断：作业未正常结束（孤儿恢复判失败）',
  'retry_sources_missing': '源文件缺失：待重导的源文件均已不存在',
  'already_indexed_path': '已在库中：该文件路径已登记，跳过重复导入',
  'duplicate_fingerprint': '内容重复：库中已存在相同内容的文件，跳过导入',
};

/// 返回失败/跳过原因的中文说明；未知 code 回落原值，空串落「未知原因」。
String describeFailureReason(String code) =>
    _kFailureReasonDescriptions[code] ?? (code.isEmpty ? '未知原因' : code);
