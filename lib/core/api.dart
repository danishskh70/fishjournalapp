import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiException implements Exception {
  final int code;
  final String message;
  ApiException(this.code, this.message);
  @override
  String toString() => message;
}

class Api {
  static const base = 'https://fish-journal.onrender.com';
  static const _s = FlutterSecureStorage();
  static String? _a, _r;
  static void Function()? onExpired;

  static Future<bool> hasSession() async {
    _a = await _s.read(key: 'a');
    _r = await _s.read(key: 'r');
    return _a != null;
  }

  static Future<void> _save(Map m) async {
    _a = m['access_token'];
    _r = m['refresh_token'] ?? _r;
    await _s.write(key: 'a', value: _a);
    await _s.write(key: 'r', value: _r);
  }

  static Future<void> login(String u, String p) async =>
      _save(await req('POST', '/api/v1/auth/login',
          body: {'username': u, 'password': p}, auth: false));
  static Future<void> logout() async {
    try {
      await req('POST', '/api/v1/auth/logout',
          body: _r == null ? null : {'refresh_token': _r});
    } catch (_) {}
    _a = null;
    _r = null;
    await _s.deleteAll();
  }

  static Future<bool> _refresh() async {
    if (_r == null) return false;
    try {
      await _save(await req('POST', '/api/v1/auth/refresh',
          body: {'refresh_token': _r}, auth: false));
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<dynamic> req(String method, String path,
      {Map<String, dynamic>? body,
      Map<String, String>? q,
      bool auth = true,
      bool retry = true}) async {
    final uri = Uri.parse(base + path)
        .replace(queryParameters: q == null || q.isEmpty ? null : q);
    final rq = http.Request(method, uri)
      ..headers['Content-Type'] = 'application/json';
    if (auth && _a != null) rq.headers['Authorization'] = 'Bearer $_a';
    if (body != null) rq.body = jsonEncode(body);
    http.Response r;
    try {
      r = await http.Response.fromStream(
          await rq.send().timeout(const Duration(seconds: 60)));
    } catch (_) {
      throw ApiException(
          0, 'Cannot reach the server. Check your internet and try again.');
    }
    if (r.statusCode == 401 && auth) {
      if (retry && await _refresh()) {
        return req(method, path, body: body, q: q, retry: false);
      }
      onExpired?.call();
      throw ApiException(401, 'Session expired. Please log in again.');
    }
    final data = r.body.isEmpty ? null : jsonDecode(utf8.decode(r.bodyBytes));
    if (r.statusCode >= 200 && r.statusCode < 300) return data;
    throw ApiException(r.statusCode, _msg(r.statusCode, data));
  }

  static String _msg(int c, dynamic d) {
    if (c >= 500) return 'Server problem. Please try again shortly.';
    if (d is Map) {
      final x = d['detail'] ?? d['message'];
      if (x is String) return x;
      if (x is List) {
        return x.map((e) => e is Map ? '${e['msg']}' : '$e').join('\n');
      }
    }
    return {
          403: 'Not permitted.',
          404: 'Record not found.',
          409: 'Already exists / conflict.',
          422: 'Invalid data.'
        }[c] ??
        'Error $c';
  }
}
