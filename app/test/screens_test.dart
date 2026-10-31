import 'dart:convert';

import 'package:autocontact/api.dart';
import 'package:autocontact/models.dart';
import 'package:autocontact/screens/card_screen.dart';
import 'package:autocontact/screens/group_detail_screen.dart';
import 'package:autocontact/screens/profile_screen.dart';
import 'package:autocontact/screens/sign_in_screen.dart';
import 'package:autocontact/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Layout checks: each screen renders at a small phone size in both themes
// without overflow errors, which flutter_test reports as test failures.

final _group = {'id': 'g1', 'name': 'Stage crew', 'join_code': 'ABC123', 'is_owner': true, 'owner_id': 'u1'};

final _ana = ContactCard(
  firstName: 'Ana',
  lastName: 'de la Cruz Montenegro',
  phones: const [LabeledValue('iphone', '+1 (555) 010-2030'), LabeledValue('work', '555 0199')],
  emails: const [LabeledValue('work', 'ana.delacruz.montenegro@lighting-company.example')],
  company: 'Lighting Company International',
  jobTitle: 'Head Gaffer',
  website: 'https://ana.example',
  address: '1 Main St\nSpringfield',
  birthday: DateTime(1999, 2, 3),
);

Map<String, dynamic> _member(String id, ContactCard card, {bool owner = false}) =>
    {...card.toJson(), 'user_id': 'u$id', 'is_owner': owner};

Api _apiReturning(Map<String, dynamic> body) => Api(
      accessToken: () async => 'tok',
      client: MockClient((_) async => http.Response(jsonEncode(body), 200)),
    );

Future<void> _pump(WidgetTester tester, Widget screen, Brightness brightness) async {
  tester.view.physicalSize = const Size(360, 690) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: buildTheme(brightness), home: screen));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final brightness in Brightness.values) {
    group('${brightness.name} theme', () {
      testWidgets('sign-in screen', (tester) async {
        await _pump(tester, const SignInScreen(), brightness);
        expect(find.text('Continue with Google'), findsOneWidget);
      });

      testWidgets('group roster', (tester) async {
        final api = _apiReturning({
          'group': _group,
          'members': [
            _member('1', _ana, owner: true),
            _member('2', const ContactCard(firstName: 'Bo')),
            _member('3', const ContactCard(firstName: 'Cy', phones: [LabeledValue('mobile', '555 0123')])),
          ],
          'me_id': 'u2',
        });
        await _pump(
          tester,
          GroupDetailScreen(api: api, group: Group.fromJson(_group), profile: ValueNotifier(null)),
          brightness,
        );
        expect(find.text('ABC-123'), findsOneWidget);
        expect(find.text('Sync 2 people to Contacts'), findsOneWidget);
        expect(find.text('You'), findsOneWidget);
        expect(find.text('Owner'), findsOneWidget);
      });

      testWidgets('onboarding with a full card', (tester) async {
        await _pump(tester, ProfileScreen(api: _apiReturning({}), initial: _ana, onboarding: true), brightness);
        expect(find.text('Fill in from my contact card'), findsOneWidget);
        await tester.drag(find.byType(ListView), const Offset(0, -3000));
        await tester.pumpAndSettle();
        expect(find.text('Save and continue'), findsOneWidget);
      });

      testWidgets("someone else's card", (tester) async {
        await _pump(tester, CardScreen(member: Member(userId: 'u1', card: _ana, isOwner: true), isMe: false), brightness);
        expect(find.text('Save to Contacts'), findsOneWidget);
        expect(find.text('Head Gaffer · Lighting Company International'), findsOneWidget);
      });

      testWidgets('my QR code', (tester) async {
        await _pump(tester, MyQrScreen(card: _ana), brightness);
        expect(find.text('Ana de la Cruz Montenegro'), findsOneWidget);
      });
    });
  }
}
