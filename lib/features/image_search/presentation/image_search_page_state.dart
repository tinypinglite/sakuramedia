import 'package:sakuramedia/app/app_page_state_cache.dart';
import 'package:sakuramedia/features/actors/data/actors_api.dart';
import 'package:sakuramedia/features/image_search/data/image_search_api.dart';
import 'package:sakuramedia/features/image_search/presentation/image_search_controller.dart';
import 'package:sakuramedia/features/image_search/presentation/image_search_filter_state.dart';

class ImageSearchPageStateEntry implements AppPageStateEntry {
  ImageSearchPageStateEntry({
    required ImageSearchApi imageSearchApi,
    required ActorsApi actorsApi,
    required ImageSearchCurrentMovieScope initialCurrentMovieScope,
  }) : filterState = ImageSearchFilterState(
         currentMovieScope: initialCurrentMovieScope,
       ) {
    controller = ImageSearchController(
      imageSearchApi: imageSearchApi,
      actorsApi: actorsApi,
    );
    controller.attachScrollListener();
  }

  late final ImageSearchController controller;
  ImageSearchFilterState filterState;
  Object? bootstrappedSourceSignature;

  @override
  void dispose() {
    controller.dispose();
  }
}
