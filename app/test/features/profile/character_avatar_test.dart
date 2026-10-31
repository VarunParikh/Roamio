import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roamio/features/profile/ui/character_avatar.dart';
import 'package:roamio/features/squad/data/squad_service.dart';
import 'package:roamio/features/squad/ui/person.dart';

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(body: Center(child: child)),
  ),
);

String? _asset(WidgetTester tester) {
  final images = tester.widgetList<Image>(find.byType(Image));
  if (images.isEmpty) return null;
  return (images.single.image as AssetImage).assetName;
}

void main() {
  group('CharacterAvatar', () {
    testWidgets('shows the chosen character', (tester) async {
      await _pump(
        tester,
        const CharacterAvatar(uid: 'ari', characterId: 'panda'),
      );
      expect(_asset(tester), 'assets/characters/panda.webp');
    });

    testWidgets('with none chosen, shows their default', (tester) async {
      await _pump(tester, const CharacterAvatar(uid: 'ari'));
      expect(_asset(tester), 'assets/characters/giraffe.webp');
    });

    testWidgets('an unknown id falls back to their default', (tester) async {
      await _pump(
        tester,
        const CharacterAvatar(uid: 'ari', characterId: 'from_the_future'),
      );
      expect(_asset(tester), 'assets/characters/giraffe.webp');
    });

    testWidgets('a deleted user gets a grey icon, not a character', (
      tester,
    ) async {
      await _pump(tester, const CharacterAvatar(uid: 'ari', deleted: true));
      expect(_asset(tester), isNull);
      expect(find.byType(Icon), findsOneWidget);
    });

    testWidgets('while loading, a plain circle and no character', (
      tester,
    ) async {
      await _pump(tester, const CharacterAvatar(uid: 'ari', loading: true));
      expect(_asset(tester), isNull);
      expect(find.byType(Icon), findsNothing);
    });

    testWidgets('TalkBack doesn’t read the character', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pump(
        tester,
        const CharacterAvatar(uid: 'ari', characterId: 'panda'),
      );
      expect(find.bySemanticsLabel('Panda'), findsNothing);
      semantics.dispose();
    });
  });

  group('PersonName', () {
    testWidgets('shows the picture beside the name', (tester) async {
      await _pump(
        tester,
        const PersonName(
          uid: 'bob',
          person: SquadPerson(name: 'Bob Lee', characterId: 'fox'),
        ),
      );
      expect(find.text('Bob Lee'), findsOneWidget);
      expect(_asset(tester), 'assets/characters/fox.webp');
    });

    testWidgets('a deleted person reads "Deleted user" with the grey icon', (
      tester,
    ) async {
      await _pump(
        tester,
        const PersonName(
          uid: 'gone',
          person: SquadPerson(name: deletedUserName, deleted: true),
        ),
      );
      expect(find.text(deletedUserName), findsOneWidget);
      expect(find.byType(Icon), findsOneWidget);
    });

    testWidgets('someone not looked up yet shows a neutral circle', (
      tester,
    ) async {
      await _pump(tester, const PersonName(uid: 'bob', person: null));
      expect(find.text('…'), findsOneWidget);
      expect(_asset(tester), isNull);
    });

    testWidgets('a long name stays on the screen', (tester) async {
      await _pump(
        tester,
        SizedBox(
          width: 120,
          child: PersonName(
            uid: 'bob',
            person: SquadPerson(name: 'Bob ' * 30),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
