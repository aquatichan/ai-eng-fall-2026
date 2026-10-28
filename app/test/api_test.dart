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
                {'id': 'g1', 'name': 'Crew A', 'join_code': 'ABCDEFGHJKMN', 'is_owner': true},
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
      expect(groups.single.displayCode, 'ABCD-EFGH-JKMN');
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

  test('formatJoinCode groups by four', () {
    expect(formatJoinCode('ABCDEFGHJKMN'), 'ABCD-EFGH-JKMN');
  });
}
