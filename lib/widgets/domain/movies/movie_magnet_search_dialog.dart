import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show KeepAliveLink;
import 'package:sakuramedia/features/movies/presentation/providers/movie_detail_magnet_provider.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/overlays/app_desktop_dialog.dart';
import 'package:sakuramedia/widgets/domain/movies/movie_magnet_search_content.dart';

Future<void> showMovieMagnetSearchDialog({
  required BuildContext context,
  required String movieNumber,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AppDesktopDialog(
      dialogKey: const Key('movie-magnet-search-dialog'),
      contentKey: const Key('movie-magnet-search-dialog-content'),
      width: dialogContext.appComponentTokens.movieDetailDialogWidth,
      height: dialogContext.appComponentTokens.movieDetailDialogMinHeight,
      child: _MovieMagnetSearchDialogBody(movieNumber: movieNumber),
    ),
  );
}

class _MovieMagnetSearchDialogBody extends ConsumerStatefulWidget {
  const _MovieMagnetSearchDialogBody({required this.movieNumber});

  final String movieNumber;

  @override
  ConsumerState<_MovieMagnetSearchDialogBody> createState() =>
      _MovieMagnetSearchDialogBodyState();
}

class _MovieMagnetSearchDialogBodyState
    extends ConsumerState<_MovieMagnetSearchDialogBody> {
  KeepAliveLink? _cacheLink;

  @override
  void initState() {
    super.initState();
    _cacheLink = ref
        .read(movieDetailMagnetProvider(widget.movieNumber).notifier)
        .cacheLink;
  }

  @override
  void dispose() {
    _cacheLink?.close();
    _cacheLink = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsetsDirectional.only(
            end: context.appComponentTokens.buttonHeightMd,
          ),
          child: Text(
            '磁力搜索',
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s18,
              weight: AppTextWeight.semibold,
              tone: AppTextTone.primary,
            ),
          ),
        ),
        SizedBox(height: context.appSpacing.md),
        Expanded(
          child: MovieMagnetSearchContent(movieNumber: widget.movieNumber),
        ),
      ],
    );
  }
}
