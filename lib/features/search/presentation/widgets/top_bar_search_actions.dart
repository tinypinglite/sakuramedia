import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/features/image_search/presentation/image_search_file_picker.dart';
import 'package:sakuramedia/features/image_search/presentation/actions/image_search_launcher.dart';
import 'package:sakuramedia/features/image_search/presentation/providers/image_search_state.dart';
import 'package:sakuramedia/features/status/presentation/providers/server_capabilities_provider.dart';
import 'package:sakuramedia/routes/app_routes.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:sakuramedia/widgets/base/l10n/app_l10n.dart';
import 'package:sakuramedia/widgets/domain/search/catalog_search_field.dart';
import 'package:sakuramedia/widgets/shell/desktop/app_top_bar_glass_search_field.dart';

/// 桌面顶栏搜索框与图搜入口。
///
/// 搜索框固定显示；提交后跳转搜索页。输入框聚焦时按 ESC 清空并失焦，
/// 不隐藏输入框。以图搜图 / 文字搜图入口挂在输入框后缀。
class TopBarSearchActions extends ConsumerStatefulWidget {
  const TopBarSearchActions({
    super.key,
    required this.currentPath,
    this.glass = false,
  });

  final String currentPath;
  final bool glass;

  @override
  ConsumerState<TopBarSearchActions> createState() =>
      _TopBarSearchActionsState();
}

class _TopBarSearchActionsState extends ConsumerState<TopBarSearchActions> {
  static const double _fieldWidth = 300;

  /// 顶栏搜索框收紧后的垂直内边距：字段高 = max(28, 字高 14 + 2×10) = 34。
  ///
  /// 没有等于 10 的间距 token（xs=4 / md=12），收到这里的命名常量，
  /// 避免在 `EdgeInsets` 里出现裸数字（theme_source_guard 禁令）。
  static const double _compactSearchFieldVerticalPadding = 10;

  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode(debugLabel: 'topbar-search');

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _clearAndUnfocus() {
    _controller.clear();
    _focusNode.unfocus();
  }

  void _submit() {
    final query = _controller.text.trim();
    if (query.isEmpty) {
      return;
    }
    DesktopRoutes.search(
      query: query,
      fallbackPath: widget.currentPath,
    ).push(context);
  }

  void _openTextImageSearch() {
    DesktopRoutes.imageSearch(
      fallbackPath: widget.currentPath,
      mode: ImageSearchInputKind.text.name,
    ).push(context);
  }

  Future<void> _pickAndOpenImageSearch() async {
    final l10n = appL10n(context);
    try {
      final pickedFile = await pickImageSearchFile(l10n: l10n);
      if (pickedFile == null || !mounted) {
        return;
      }
      final draftId = saveImageSearchDraft(
        context,
        fileName: pickedFile.fileName,
        bytes: pickedFile.bytes,
        mimeType: pickedFile.mimeType,
      );
      DesktopRoutes.imageSearch(
        fallbackPath: widget.currentPath,
        draftId: draftId,
      ).push(context);
    } on ImageSearchFilePickerException catch (error) {
      if (mounted) {
        showToast(error.message, tone: AppToastTone.error);
      }
    } catch (_) {
      if (mounted) {
        showToast(l10n.shellImagePickFailed, tone: AppToastTone.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = appL10n(context);
    final imageSearchEnabled = ref.watch(imageSearchEnabledProvider);
    final searchField = widget.glass
        ? AppTopBarGlassSearchField(
            key: const Key('topbar-search-field'),
            fieldKey: const Key('topbar-search-input'),
            imageSearchButtonKey: const Key('topbar-search-image'),
            textImageSearchButtonKey: const Key('topbar-search-text-image'),
            controller: _controller,
            focusNode: _focusNode,
            hintText: l10n.shellSearchHintExample,
            onSubmitted: (_) => _submit(),
            showImageSearchButton: imageSearchEnabled,
            showTextImageSearchButton: imageSearchEnabled,
            onImageSearchTap: _pickAndOpenImageSearch,
            onTextImageSearchTap: _openTextImageSearch,
          )
        : CatalogSearchField(
            key: const Key('topbar-search-field'),
            fieldKey: const Key('topbar-search-input'),
            imageSearchButtonKey: const Key('topbar-search-image'),
            textImageSearchButtonKey: const Key('topbar-search-text-image'),
            controller: _controller,
            focusNode: _focusNode,
            hintText: l10n.shellSearchHintExample,
            // 收紧到 34 高：tightSuffix 解除后缀 48px 热区下限后，
            // 高度 = max(后缀按钮 28, 字高 14 + 2×10)。
            tightSuffix: true,
            contentPadding: EdgeInsets.symmetric(
              horizontal: context.appFormTokens.fieldHorizontalPadding,
              vertical: _compactSearchFieldVerticalPadding,
            ),
            // 34 高的字段上 8px 圆角偏圆，收紧到 4 更方。
            borderRadius: context.appRadius.xsBorder,
            showSearchButton: false,
            showImageSearchButton: imageSearchEnabled,
            showTextImageSearchButton: imageSearchEnabled,
            onSubmitted: (_) => _submit(),
            onImageSearchTap: _pickAndOpenImageSearch,
            onTextImageSearchTap: _openTextImageSearch,
          );

    return SizedBox(
      width: _fieldWidth,
      child: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.escape): _clearAndUnfocus,
        },
        child: searchField,
      ),
    );
  }
}
