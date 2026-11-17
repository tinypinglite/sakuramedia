import 'package:sakuramedia/features/account/data/account_dto.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// 账号资料加载态占位：真实 DTO + [BoneMock] 用户名，
/// 供 `AppSkeletonizer` 渲染与真实资料卡同形的静态骨架。
AccountDto accountPlaceholder() {
  return AccountDto(
    username: BoneMock.words(1),
    createdAt: null,
    lastLoginAt: null,
  );
}
