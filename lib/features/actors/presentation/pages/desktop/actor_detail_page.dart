import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/actors/presentation/pages/shared/actor_detail_content.dart';
import 'package:sakuramedia/routes/app_routes.dart';

class DesktopActorDetailPage extends StatelessWidget {
  const DesktopActorDetailPage({super.key, required this.actorId});

  final int actorId;

  @override
  Widget build(BuildContext context) {
    return ActorDetailContent(
      actorId: actorId,
      mobile: false,
      onMovieTap: (context, movieNumber) => DesktopRoutes.movieDetail(
        movieNumber: movieNumber,
        fallbackPath: '/desktop/library/actors/$actorId',
      ).push(context),
    );
  }
}
