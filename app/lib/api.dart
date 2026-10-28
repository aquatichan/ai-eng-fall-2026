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
