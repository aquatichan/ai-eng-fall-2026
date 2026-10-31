import 'dart:convert';

import 'package:autocontact/api.dart';
import 'package:autocontact/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('Api.getGroups', () {
    test('sends the bearer token and parses groups', () async {
      late http.Request seen;
      final api = Api(
        accessToken: () async => 'tok123',
        client: MockClient((req) async {
          seen = req;
          return http.Response(
            jsonEncode({
              'groups': [
                {'id': 'g1', 'name': 'Crew A', 'join_code': 'ABC123', 'is_owner': true},
              ],
            }),
            200,
          );
        }),
      );

      final groups = await api.getGroups();

      expect(seen.method, 'GET');
      expect(seen.url.path, '/api/groups');
      expect(seen.headers['Authorization'], 'Bearer tok123');
      expect(groups.single.name, 'Crew A');
      expect(groups.single.isOwner, isTrue);
      expect(groups.single.displayCode, 'ABC-123');
    });

    test('turns API errors into ApiException', () async {
      final api = Api(
        accessToken: () async => 'tok',
        client: MockClient((_) async => http.Response('{"error":"Invalid or expired token"}', 401)),
      );
      expect(
        api.getGroups(),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 401)
            .having((e) => e.message, 'message', 'Invalid or expired token')),
      );
    });

    test('fails fast when signed out', () async {
      final api = Api(
        accessToken: () async => null,
        client: MockClient((_) async => fail('should not send')),
      );
      expect(api.getGroups(), throwsA(isA<ApiException>()));
    });
  });

  group('Api writes', () {
    late http.Request seen;
    Api apiReturning(Map<String, dynamic> body, [int status = 200]) => Api(
      accessToken: () async => 'tok',
      client: MockClient((req) async {
        seen = req;
        return http.Response(jsonEncode(body), status);
      }),
    );
    final groupJson = {'id': 'g1', 'name': 'Crew A', 'join_code': 'ABC123', 'is_owner': false};

    test('createGroup posts the name', () async {
      final group = await apiReturning({
        'group': {...groupJson, 'is_owner': true},
      }, 201).createGroup('Crew A');
      expect(seen.method, 'POST');
      expect(seen.url.path, '/api/groups');
      expect(seen.headers['Content-Type'], startsWith('application/json'));
      expect(jsonDecode(seen.body), {'name': 'Crew A'});
      expect(group.isOwner, isTrue);
    });

    test('joinGroup posts the code as typed', () async {
      final group = await apiReturning({'group': groupJson, 'member': {}}).joinGroup('abc-123');
      expect(seen.url.path, '/api/groups/join');
      expect(jsonDecode(seen.body), {'code': 'abc-123'});
      expect(group.id, 'g1');
    });

    test('joinGroup surfaces a bad code', () async {
      final api = Api(
        accessToken: () async => 'tok',
        client: MockClient((_) async => http.Response('{"error":"No group with that code"}', 404)),
      );
      expect(
        api.joinGroup('ZZZZ'),
        throwsA(isA<ApiException>().having((e) => e.message, 'message', 'No group with that code')),
      );
    });

    test('getGroup parses cards, owner and me', () async {
      final ana = {
        'user_id': 'u1',
        'first_name': 'Ana',
        'last_name': 'Ruiz',
        'phones': [
          {'label': 'iphone', 'number': '555 0102'},
        ],
        'emails': [],
        'company': 'Crew',
        'job_title': null,
        'website': null,
        'address': null,
        'birthday': '1999-02-03',
        'is_owner': true,
        'updated_at': '2026-10-31T10:00:00Z',
      };
      final detail = await apiReturning({
        'group': groupJson,
        'members': [ana],
        'me_id': 'u1',
      }).getGroup('g1');
      expect(seen.url.path, '/api/groups/g1');
      final m = detail.members.single;
      expect(m.name, 'Ana Ruiz');
      expect(m.isOwner, isTrue);
      expect(m.card.phones.single, const LabeledValue('iphone', '555 0102'));
      expect(m.card.birthday, DateTime(1999, 2, 3));
      expect(detail.meId, 'u1');
    });

    test('getProfile returns null before onboarding', () async {
      expect(await apiReturning({'profile': null}).getProfile(), isNull);
      expect(seen.url.path, '/api/profile');
    });

    test('saveProfile PUTs the card and drops nothing', () async {
      final card = ContactCard(
        firstName: 'Ana',
        lastName: 'Ruiz',
        phones: const [LabeledValue('mobile', '555 0102'), LabeledValue('work', '555 0199')],
        emails: const [LabeledValue('work', 'ana@crew.co')],
        jobTitle: 'Gaffer',
        birthday: DateTime(1999, 2, 3),
      );
      final saved = await apiReturning({'profile': card.toJson()}).saveProfile(card);
      expect(seen.method, 'PUT');
      expect(seen.url.path, '/api/profile');
      final body = jsonDecode(seen.body) as Map<String, dynamic>;
      expect(body['phones'], [
        {'label': 'mobile', 'number': '555 0102'},
        {'label': 'work', 'number': '555 0199'},
      ]);
      expect(body['birthday'], '1999-02-03');
      expect(saved.toJson(), card.toJson());
    });
  });

  test('formatJoinCode splits letters from digits', () {
    expect(formatJoinCode('ABC123'), 'ABC-123');
  });
}
