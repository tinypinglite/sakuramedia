import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/actors/presentation/pages/shared/actor_detail_content.dart';
import 'package:sakuramedia/routes/app_routes.dart';

class MobileActorDetailPage extends StatelessWidget {
  const MobileActorDetailPage({super.key, required this.actorId});

  final int actorId;

  @override
  Widget build(BuildContext context) {
    return ActorDetailContent(
      actorId: actorId,
      mobile: true,
      onMovieTap: (context, movieNumber) =>
          MobileRoutes.movieDetail(movieNumber: movieNumber).push(context),
    );
  }
}
