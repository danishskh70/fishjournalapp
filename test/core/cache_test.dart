import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fish_journal/core/cache.dart';

void main() {
  setUp(() {
    DataCache.i.clear();
  });

  tearDown(() {
    DataCache.i.clear();
  });

  group('DataCache', () {
    test('stores and returns fetched data', () async {
      final result = await DataCache.i.load(
        'test',
        () async => {'value': 42},
      );

      expect(result, {'value': 42});
      expect(DataCache.i.has('test'), isTrue);
      expect(DataCache.i.peek('test'), {'value': 42});
      expect(DataCache.i.isStale('test'), isFalse);
    });

    test('deduplicates concurrent requests for the same key', () async {
      final completer = Completer<dynamic>();
      var fetchCount = 0;

      Future<dynamic> fetch() {
        fetchCount++;
        return completer.future;
      }

      final first = DataCache.i.load('test', fetch);
      final second = DataCache.i.load('test', fetch);

      expect(fetchCount, 1);

      completer.complete('shared result');

      expect(await first, 'shared result');
      expect(await second, 'shared result');
      expect(fetchCount, 1);
    });

    test('returns cached data and refreshes stale data in background',
        () async {
      final initial = await DataCache.i.load(
        'test',
        () async => 'old value',
      );

      expect(initial, 'old value');

      final completer = Completer<dynamic>();
      var fetchCount = 0;

      final cached = await DataCache.i.cached('test', () {
        fetchCount++;
        return completer.future;
      });

      expect(cached, 'old value');
      expect(fetchCount, 0);

      DataCache.i.invalidate('test');

      final stale = await DataCache.i.cached('test', () {
        fetchCount++;
        return completer.future;
      });

      expect(stale, 'old value');
      expect(fetchCount, 1);

      completer.complete('new value');
      await Future<void>.delayed(Duration.zero);

      expect(DataCache.i.peek('test'), 'new value');
      expect(DataCache.i.isStale('test'), isFalse);
    });

    test('retries when invalidated while a request is in flight', () async {
      final completer = Completer<dynamic>();
      var fetchCount = 0;

      Future<dynamic> fetch() {
        fetchCount++;

        if (fetchCount == 1) return completer.future;

        return Future.value('fresh response');
      }

      final request = DataCache.i.load('test', fetch);

      DataCache.i.invalidate('test');
      completer.complete('outdated response');

      final result = await request;

      expect(result, 'fresh response');
      expect(fetchCount, 2);
      expect(DataCache.i.peek('test'), 'fresh response');
    });

    test('clear blocks old in-flight responses', () async {
      await DataCache.i.load('cached', () async => 'saved');

      final completer = Completer<dynamic>();

      final request = DataCache.i.load(
        'pending',
        () => completer.future,
      );

      DataCache.i.clear();
      completer.complete('old session response');

      await expectLater(request, throwsA(isA<StateError>()));

      expect(DataCache.i.has('cached'), isFalse);
      expect(DataCache.i.has('pending'), isFalse);
    });
  });
}
