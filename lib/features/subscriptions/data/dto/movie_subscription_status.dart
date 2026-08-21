/// 订阅影片的「资源查询状态」与列表排序维度。
///
/// 状态由后端 `MovieSubscriptionService._status_expression()` 的**单个** SQL CASE
/// 判定，筛选 / 计数 / 列表展示共用它——所以七项严格互斥，
/// `/movie-subscriptions/status-counts` 各项之和恒等于 `total`。前端不要自行推导
/// 状态（例如「有 media 就算已入库」），一律以后端下发的 `status` 为准。
library;

/// 七个互斥状态；[unknown] 只用于兜底后端将来新增的取值。
///
/// 枚举顺序即后端 CASE 分支顺序（也就是判定优先级），不要按 UI 展示顺序重排——
/// tab 的展示顺序在 presentation 层单独定义。
enum MovieSubscriptionStatus {
  /// 已入库：存在本地 `Media`。订阅不会因为下到了而自动解除。
  imported,

  /// 下载中：有活跃下载任务（failed / abandoned / 死种任务不算）**且其导入还在途**
  /// （后端 `import_status=pending/running`）。
  ///
  /// 含"下完了正等自动导入"——那是秒级过渡态，用户对它的动作和真下载中一样（等着）。
  /// 一部片同时有导入失败任务和仍在下载的任务时也算这一档：还有希望，不该报失败。
  downloading,

  /// 未入库操作桶：有活跃下载任务，但**没有一个的导入还在途**——这一趟导入已经跑完，库里却
  /// 没有 `Media`。
  ///
  /// 后端按「导入在不在途」切，**不是**按「`import_status` 是不是 failed」切，所以这一档
  /// 除了真的导入报错，也包含"跑完了零产出"（整包只有小于阈值的样本文件时，扫描记 skipped、
  /// 任务落 `import_status=completed`，却一个 Media 都没产出）。
  ///
  /// **与 [failed] 不是一回事**：那个是索引器查询出错、压根还没找到资源。两者线上值都带
  /// "failed"，文案上必须分别念作「导入失败」与「查询出错」。
  ///
  /// 这类影片重下没有意义（该修的是导入），后端也不会重新给它查资源。行内文案由最新
  /// 列表项的导入状态与错误字段负责呈现「导入失败」或「未产出媒体」的细节。
  importFailed,

  /// 已放弃：老片本轮没找到次数达到上限（默认 3），不再自动查，需要用户手动重置。
  exhausted,

  /// 查询出错：索引器调用失败，**不计入本轮没找到次数**，下一轮会重试。
  failed,

  /// 缺资源：查过但一直没找到可用资源，仍在继续查。
  missing,

  /// 待查：订阅后还没查过资源。
  pending,

  /// 后端新增了本端未识别的取值。
  unknown,
}

extension MovieSubscriptionStatusX on MovieSubscriptionStatus {
  /// 下发给 `GET /movie-subscriptions?status=` 的值；[unknown] 无对应线上值。
  String? get apiValue => switch (this) {
    MovieSubscriptionStatus.imported => 'imported',
    MovieSubscriptionStatus.downloading => 'downloading',
    MovieSubscriptionStatus.importFailed => 'import_failed',
    MovieSubscriptionStatus.exhausted => 'exhausted',
    MovieSubscriptionStatus.failed => 'failed',
    MovieSubscriptionStatus.missing => 'missing',
    MovieSubscriptionStatus.pending => 'pending',
    MovieSubscriptionStatus.unknown => null,
  };

  String get label => switch (this) {
    MovieSubscriptionStatus.imported => '已入库',
    MovieSubscriptionStatus.downloading => '下载中',
    MovieSubscriptionStatus.importFailed => '导入失败',
    MovieSubscriptionStatus.exhausted => '已放弃',
    MovieSubscriptionStatus.failed => '查询出错',
    MovieSubscriptionStatus.missing => '缺资源',
    MovieSubscriptionStatus.pending => '待查',
    MovieSubscriptionStatus.unknown => '未知状态',
  };

  static MovieSubscriptionStatus fromWire(dynamic value) => switch (value) {
    'imported' => MovieSubscriptionStatus.imported,
    'downloading' => MovieSubscriptionStatus.downloading,
    'import_failed' => MovieSubscriptionStatus.importFailed,
    'exhausted' => MovieSubscriptionStatus.exhausted,
    'failed' => MovieSubscriptionStatus.failed,
    'missing' => MovieSubscriptionStatus.missing,
    'pending' => MovieSubscriptionStatus.pending,
    _ => MovieSubscriptionStatus.unknown,
  };
}

/// `GET /movie-subscriptions?sort=` 的可选值。空值统一由后端排到最后。
enum MovieSubscriptionSort {
  subscribedAtDesc,
  subscribedAtAsc,
  releaseDateDesc,
  releaseDateAsc,
  lastSearchedAtDesc,
  lastSearchedAtAsc,
  attemptCountDesc,
}

extension MovieSubscriptionSortX on MovieSubscriptionSort {
  String get apiValue => switch (this) {
    MovieSubscriptionSort.subscribedAtDesc => 'subscribed_at:desc',
    MovieSubscriptionSort.subscribedAtAsc => 'subscribed_at:asc',
    MovieSubscriptionSort.releaseDateDesc => 'release_date:desc',
    MovieSubscriptionSort.releaseDateAsc => 'release_date:asc',
    MovieSubscriptionSort.lastSearchedAtDesc => 'last_searched_at:desc',
    MovieSubscriptionSort.lastSearchedAtAsc => 'last_searched_at:asc',
    MovieSubscriptionSort.attemptCountDesc => 'attempt_count:desc',
  };

  String get label => switch (this) {
    MovieSubscriptionSort.subscribedAtDesc => '订阅时间 · 新到旧',
    MovieSubscriptionSort.subscribedAtAsc => '订阅时间 · 旧到新',
    MovieSubscriptionSort.releaseDateDesc => '发行日期 · 新到旧',
    MovieSubscriptionSort.releaseDateAsc => '发行日期 · 旧到新',
    MovieSubscriptionSort.lastSearchedAtDesc => '最近查询 · 新到旧',
    MovieSubscriptionSort.lastSearchedAtAsc => '最近查询 · 旧到新',
    MovieSubscriptionSort.attemptCountDesc => '没找到次数 · 多到少',
  };
}
