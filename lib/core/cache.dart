import 'dart:async';
import 'package:flutter/foundation.dart';

class DataCache extends ChangeNotifier {
  DataCache._();

  static final i = DataCache._();

  final _data = <String, dynamic>{};
  final _at = <String, DateTime>{};
  final _stale = <String>{};
  final _flight = <String, Future<dynamic>>{};
  final _versions = <String, int>{};

  int _epoch = 0;

  bool has(String k) => _data.containsKey(k);

  dynamic peek(String k) => _data[k];

  bool marked(String k) => _stale.contains(k);

  bool isStale(
    String k, {
    Duration maxAge = const Duration(seconds: 30),
  }) {
    final t = _at[k];

    return t == null ||
        _stale.contains(k) ||
        DateTime.now().difference(t) > maxAge;
  }

  /// Fetches fresh data and stores it only if the request is still valid.
  /// Retries automatically if invalidated while in flight.
  /// Rejects responses from a cleared session.
  /// Concurrent requests for the same key share one Future.
  Future<dynamic> load(
    String k,
    Future<dynamic> Function() fetch,
  ) {
    final current = _flight[k];

    if (current != null) return current;

    final requestEpoch = _epoch;
    final requestVersion = _versions[k] ?? 0;

    late final Future<dynamic> future;

    future = Future<dynamic>.sync(fetch).then(
      (value) {
        if (requestEpoch != _epoch) {
          throw StateError('Cache cleared while request was in progress');
        }

        if (requestVersion != (_versions[k] ?? 0)) {
          return load(k, fetch);
        }

        _data[k] = value;
        _at[k] = DateTime.now();
        _stale.remove(k);
        notifyListeners();

        return value;
      },
      onError: (Object error, StackTrace stack) {
        if (requestEpoch != _epoch) {
          Error.throwWithStackTrace(
            StateError('Cache cleared while request was in progress'),
            stack,
          );
        }

        if (requestVersion != (_versions[k] ?? 0)) {
          return load(k, fetch);
        }

        Error.throwWithStackTrace(error, stack);
      },
    ).whenComplete(() {
      if (identical(_flight[k], future)) {
        _flight.remove(k);
      }
    });

    _flight[k] = future;

    return future;
  }

  /// Returns cached data immediately and refreshes stale data in the background.
  Future<dynamic> cached(
    String k,
    Future<dynamic> Function() fetch,
  ) async {
    if (has(k)) {
      if (isStale(k)) {
        unawaited(
          load(k, fetch).then<void>(
            (_) {},
            onError: (Object error, StackTrace stack) {},
          ),
        );
      }

      return peek(k);
    }

    return load(k, fetch);
  }

  /// Invalidates matching cached and in-flight requests.
  void invalidate(String prefix) {
    final keys = <String>{
      ..._data.keys,
      ..._flight.keys,
      ..._versions.keys,
    }.where((key) => key.startsWith(prefix));

    for (final key in keys) {
      _versions[key] = (_versions[key] ?? 0) + 1;
      _stale.add(key);

      // A subsequent load must start a new request.
      _flight.remove(key);
    }

    notifyListeners();
  }

  void invalidateAll() => invalidate('');

  /// Clears cached data and invalidates every request started before this call.
  void clear() {
    _epoch++;

    _data.clear();
    _at.clear();
    _stale.clear();
    _flight.clear();
    _versions.clear();

    notifyListeners();
  }
}
