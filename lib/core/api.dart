import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:async';

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

  /// Wakes the free Render server early. Result ignored.
  static Future<void> ping() async {
    try {
      await http
          .get(Uri.parse('$base/health'))
          .timeout(const Duration(seconds: 45));
    } catch (_) {}
  }

  static Future<bool>? _refreshing;
  static Future<void> _clearTokens() async {
    _a = null;
    _r = null;
    await _s.delete(key: 'a');
    await _s.delete(key: 'r');
  }

  static Future<bool> hasSession() async {
    _a = await _s.read(key: 'a');
    _r = await _s.read(key: 'r');

    // Existing access token: restore the session immediately.
    if (_a != null && _a!.isNotEmpty) return true;

    // No tokens: login is required.
    if (_r == null || _r!.isEmpty) return false;

    // Access token missing, but refresh token exists.
    try {
      return await _refresh();
    } on ApiException {
      // Network/server failure does not mean the user is logged out.
      return true;
    }
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
    final refresh = _r;

    // Clear local tokens before allowing another login.
    await _clearTokens();

    // Revoke the old refresh token in the background.
    if (refresh != null && refresh.isNotEmpty) {
      unawaited(_revokeSession(refresh));
    }
  }

  static Future<void> _revokeSession(String refresh) async {
    try {
      await req(
        'POST',
        '/api/v1/auth/logout',
        body: {'refresh_token': refresh},
        auth: false,
      );
    } catch (_) {
      // Local logout remains complete if the server is unavailable.
    }
  }

  static Future<bool> _refresh() {
    // If another request is already refreshing, wait for it.
    final pending = _refreshing;
    if (pending != null) return pending;

    final future = _performRefresh();
    _refreshing = future;

    return future.whenComplete(() {
      if (identical(_refreshing, future)) {
        _refreshing = null;
      }
    });
  }

  static Future<bool> _performRefresh() async {
    if (_r == null || _r!.isEmpty) {
      await _clearTokens();
      return false;
    }

    try {
      final result = await req(
        'POST',
        '/api/v1/auth/refresh',
        body: {'refresh_token': _r},
        auth: false,
      );

      await _save(result);
      return true;
    } on ApiException catch (e) {
      if (e.code == 401 || e.code == 403) {
        await _clearTokens();
        return false;
      }

      // Do not log out when the server or internet is temporarily unavailable.
      rethrow;
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
          0, 'Cannot reach the server. Check internet and try again.');
    }
    if (r.statusCode == 401 && auth) {
      if (retry && await _refresh()) {
        return req(
          method,
          path,
          body: body,
          q: q,
          retry: false,
        );
      }

      await _clearTokens();
      onExpired?.call();

      throw ApiException(
        401,
        'Session expired. Please log in again.',
      );
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
