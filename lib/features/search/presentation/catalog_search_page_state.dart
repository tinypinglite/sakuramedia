import 'dart:async';

import 'package:sakuramedia/app/app_page_state_cache.dart';
import 'package:sakuramedia/features/actors/data/actors_api.dart';
import 'package:sakuramedia/features/movies/data/movies_api.dart';
import 'package:sakuramedia/features/movies/presentation/movie_subscription_change_notifier.dart';
import 'package:sakuramedia/features/search/presentation/catalog_search_controller.dart';

class CatalogSearchPageStateEntry implements AppPageStateEntry {
  CatalogSearchPageStateEntry({
    required MoviesApi moviesApi,
    required ActorsApi actorsApi,
    required MovieSubscriptionChangeNotifier subscriptionChangeNotifier,
  }) : controller = CatalogSearchController(
         moviesApi: moviesApi,
         actorsApi: actorsApi,
         onMovieSubscriptionChanged:
             ({required movieNumber, required isSubscribed}) =>
                 subscriptionChangeNotifier.reportChange(
                   movieNumber: movieNumber,
                   isSubscribed: isSubscribed,
                 ),
       ),
       _subscriptionChangeNotifier = subscriptionChangeNotifier {
    _subscriptionChangeNotifier.addListener(_onMovieSubscriptionChanged);
  }

  final CatalogSearchController controller;
  final MovieSubscriptionChangeNotifier _subscriptionChangeNotifier;
  String queryText = '';
  bool useOnlineSearch = false;
  bool hasBootstrapped = false;

  void _onMovieSubscriptionChanged() {
    final change = _subscriptionChangeNotifier.lastChange;
    if (change == null) {
      return;
    }
    controller.applyMovieSubscriptionChange(
      movieNumber: change.movieNumber,
      isSubscribed: change.isSubscribed,
    );
  }

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
    _subscriptionChangeNotifier.removeListener(_onMovieSubscriptionChanged);
    controller.dispose();
  }
}
