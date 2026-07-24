import 'dart:async';

import 'package:sakuramedia/app/app_page_state_cache.dart';
import 'package:sakuramedia/features/actors/data/api/actors_api.dart';
import 'package:sakuramedia/features/movies/data/api/movies_api.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/notifiers/movie_subscription_change_notifier.dart';
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
    // 走 consumePendingChanges 而非直接读 lastChange：批量广播时 lastChange 只是
    // changes.last，逐条读会漏掉同批的其余番号，搜索结果里的订阅心就会留在旧态。
    _subscriptionChangeNotifier.consumePendingChanges((changes) {
      for (final change in changes) {
        controller.applyMovieSubscriptionChange(
          movieNumber: change.movieNumber,
          isSubscribed: change.isSubscribed,
        );
      }
    });
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
