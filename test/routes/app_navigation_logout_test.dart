import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/session/credential_store.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';

import '../support/in_memory_credential_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('logOut clears both the session and saved credentials', (
    WidgetTester tester,
  ) async {
    final sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');
    await sessionStore.saveTokens(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresAt: DateTime.parse('2026-03-10T12:00:00Z'),
    );
    final credentialStore = InMemoryCredentialStore();
    await credentialStore.saveCredentials(
      username: 'account',
      password: 'pwd',
    );

    expect(sessionStore.hasSession, isTrue);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SessionStore>.value(value: sessionStore),
          Provider<CredentialStore>.value(value: credentialStore),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => context.logOut(),
                  child: const Text('logout'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('logout'));
    await tester.pumpAndSettle();

    expect(sessionStore.hasSession, isFalse);
    expect(sessionStore.accessToken, isEmpty);
    expect(credentialStore.username, isNull);
    expect(credentialStore.password, isNull);
  });
}
