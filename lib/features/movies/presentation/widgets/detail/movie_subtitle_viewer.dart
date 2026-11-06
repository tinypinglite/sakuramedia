import 'dart:async';
import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/app/language/providers/app_localizations_provider.dart';
import 'package:sakuramedia/core/media/media_url_resolver.dart';
import 'package:sakuramedia/core/network/providers/api_client_provider.dart';
import 'package:sakuramedia/core/session/providers/session_store_provider.dart';
import 'package:sakuramedia/features/movies/data/dto/player/movie_subtitle_dto.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_error_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_inline_spinner.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_selectable_text_scroll_configuration.dart';
import 'package:sakuramedia/widgets/base/overlays/app_adaptive_modal.dart';

Future<void> showMovieSubtitleViewer(
  BuildContext context, {
  required MovieSubtitleItemDto item,
}) async {
  await showAppAdaptiveModal<void>(
    context: context,
    modalKey: const Key('movie-subtitle-viewer-dialog'),
    desktopWidth: context.appLayoutTokens.dialogWidthMd,
    desktopHeight: MediaQuery.sizeOf(context).height * 0.72,
    mobileHeightFactor: 0.9,
    builder: (_) => _MovieSubtitleViewerContent(item: item),
  );
}

class _MovieSubtitleViewerContent extends ConsumerStatefulWidget {
  const _MovieSubtitleViewerContent({required this.item});

  final MovieSubtitleItemDto item;

  @override
  ConsumerState<_MovieSubtitleViewerContent> createState() =>
      _MovieSubtitleViewerContentState();
}

class _MovieSubtitleViewerContentState
    extends ConsumerState<_MovieSubtitleViewerContent> {
  String? _text;
  String? _errorMessage;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.item.displayName(AppLocalizations.of(context)),
          key: const Key('movie-subtitle-viewer-title'),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s16,
            weight: AppTextWeight.semibold,
            tone: AppTextTone.primary,
          ),
        ),
        SizedBox(height: spacing.lg),
        Expanded(child: _buildBody(context)),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const Center(child: AppInlineSpinner());
    }

    final errorMessage = _errorMessage;
    if (errorMessage != null) {
      return AppErrorState(
        key: const Key('movie-subtitle-viewer-error'),
        icon: Icons.error_outline_rounded,
        title: AppLocalizations.of(
          context,
        ).movieWidgetSubtitleContentLoadFailed,
        message: errorMessage,
        onRetry: _retry,
        retryKey: const Key('movie-subtitle-viewer-retry'),
        variant: AppStatePanelVariant.section,
      );
    }

    final text = _text ?? '';
    return AppSelectableTextScrollConfiguration(
      child: Scrollbar(
        child: SingleChildScrollView(
          key: const Key('movie-subtitle-viewer-scroll'),
          padding: EdgeInsets.only(right: context.appSpacing.sm),
          child: SelectableText(
            text.isEmpty
                ? AppLocalizations.of(context).movieWidgetSubtitleContentEmpty
                : text,
            key: const Key('movie-subtitle-viewer-text'),
            style:
                resolveAppTextStyle(
                  context,
                  size: AppTextSize.s12,
                  weight: AppTextWeight.regular,
                  tone: AppTextTone.primary,
                ).copyWith(
                  fontFamilyFallback: kAppMonospaceFontFallback,
                  height: 1.5,
                ),
          ),
        ),
      ),
    );
  }

  Future<void> _load() async {
    try {
      final baseUrl = ref.read(sessionStoreProvider).baseUrl;
      final resolvedUrl = resolveMediaUrl(
        rawUrl: widget.item.url,
        baseUrl: baseUrl,
      );
      if (resolvedUrl == null || resolvedUrl.isEmpty) {
        throw StateError('字幕地址无效');
      }

      final bytes = await ref.read(apiClientProvider).getBytes(resolvedUrl);
      final text = utf8.decode(bytes);
      if (!mounted) {
        return;
      }
      setState(() {
        _text = text;
        _errorMessage = null;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = ref.read(appLocalizationsProvider).errorRetryLater;
        _isLoading = false;
      });
    }
  }

  void _retry() {
    if (_isLoading) {
      return;
    }
    setState(() {
      _text = null;
      _errorMessage = null;
      _isLoading = true;
    });
    unawaited(_load());
  }
}
