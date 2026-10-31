import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'models.dart';

class ApiException implements Exception {
  ApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => message;
}

/// Talks to the Next.js API, sending the Supabase access token on every call.
class Api {
  Api({http.Client? client, Future<String?> Function()? accessToken})
      : _client = client ?? http.Client(),
        _accessToken = accessToken ?? _supabaseAccessToken;

  final http.Client _client;
  final Future<String?> Function() _accessToken;

  static Future<String?> _supabaseAccessToken() async {
    final auth = Supabase.instance.client.auth;
    var session = auth.currentSession;
    if (session != null && session.isExpired) {
      session = (await auth.refreshSession()).session;
    }
    return session?.accessToken;
  }

  Future<List<Group>> getGroups() async {
    final body = await _send('GET', '/api/groups');
    return (body['groups'] as List)
        .map((g) => Group.fromJson(g as Map<String, dynamic>))
        .toList();
  }

  Future<Group> createGroup(String name) async {
    final body = await _send('POST', '/api/groups', {'name': name});
    return Group.fromJson(body['group'] as Map<String, dynamic>);
  }

  /// Joins by code. The server ignores case, dashes and spaces.
  Future<Group> joinGroup(String code) async {
    final body = await _send('POST', '/api/groups/join', {'code': code});
    return Group.fromJson(body['group'] as Map<String, dynamic>);
  }

  Future<GroupDetail> getGroup(String id) async {
    final body = await _send('GET', '/api/groups/${Uri.encodeComponent(id)}');
    return GroupDetail.fromJson(body);
  }

  /// Your contact card, or null if you haven't set one up yet.
  Future<ContactCard?> getProfile() async {
    final body = await _send('GET', '/api/profile');
    final profile = body['profile'];
    return profile == null ? null : ContactCard.fromJson(profile as Map<String, dynamic>);
  }

  /// Saves your card. Every group you're in shows it right away.
  Future<ContactCard> saveProfile(ContactCard card) async {
    final body = await _send('PUT', '/api/profile', card.toJson());
    return ContactCard.fromJson(body['profile'] as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> _send(String method, String path, [Object? body]) async {
    final token = await _accessToken();
    if (token == null) throw ApiException(401, 'Not signed in');

    final request = http.Request(method, Uri.parse('${Config.apiBaseUrl}$path'))
      ..headers['Authorization'] = 'Bearer $token';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }

    final response = await http.Response.fromStream(await _client.send(request));
    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw ApiException(response.statusCode, 'Unexpected response (${response.statusCode})');
    }
    if (response.statusCode >= 400) {
      final message = decoded is Map && decoded['error'] is String
          ? decoded['error'] as String
          : 'Request failed (${response.statusCode})';
      throw ApiException(response.statusCode, message);
    }
    return decoded as Map<String, dynamic>;
  }
}
