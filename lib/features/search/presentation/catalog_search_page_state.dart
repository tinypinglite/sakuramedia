import 'dart:async';

import 'package:sakuramedia/app/app_page_state_cache.dart';
import 'package:sakuramedia/features/actors/data/actors_api.dart';
import 'package:sakuramedia/features/movies/data/movies_api.dart';
import 'package:sakuramedia/features/search/presentation/catalog_search_controller.dart';

class CatalogSearchPageStateEntry implements AppPageStateEntry {
  CatalogSearchPageStateEntry({
    required MoviesApi moviesApi,
    required ActorsApi actorsApi,
  }) : controller = CatalogSearchController(
         moviesApi: moviesApi,
         actorsApi: actorsApi,
       );

  final CatalogSearchController controller;
  String queryText = '';
  bool useOnlineSearch = false;
  bool hasBootstrapped = false;

  void bootstrap({
    required String initialQuery,
    required bool initialUseOnlineSearch,
  }) {
    if (hasBootstrapped) {
      return;
    }
    queryText = initialQuery;
    useOnlineSearch = initialUseOnlineSearch;
    hasBootstrapped = true;
    if (initialQuery.trim().isNotEmpty) {
      unawaited(
        controller.submit(
          initialQuery,
          useOnlineSearch: initialUseOnlineSearch,
        ),
      );
    }
  }

  @override
  void dispose() {
    controller.dispose();
  }
}
