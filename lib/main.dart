import 'package:flutter/widgets.dart';
import 'package:sakuramedia/app/app.dart';
import 'package:sakuramedia/app/bootstrap.dart';
import 'package:sakuramedia/core/session/session_store.dart';

export 'package:sakuramedia/app/app.dart';

Future<void> main() async {
  await bootstrapApplication();
  final sessionStore = await SessionStore.create();
  runApp(MyApp(sessionStore: sessionStore));
}
