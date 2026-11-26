import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/cache.dart';
import '../core/jobs.dart';
import '../core/store.dart';
import '../core/ui.dart';
import 'close.dart';
import 'opening.dart';
import 'sheet.dart';
import 'work.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HS();
}

class _HS extends State<HomePage> {
  Map? dash;
  List hist = [];
  bool busy = true;
  String? err;
  String shop = '';
  static bool _resumed = false;

  String get ds => isoDate(DateTime.now());
  Map? get jn => dash == null ? null : dash!['journal'] as Map?;
  bool get closed => jn != null && '${jn!['status']}' == 'closed';
  List get stock => L(dash?['stock_overview']);
  bool get openingDone =>
      jn != null &&
      (closed || stock.any((r) => r['opening_confirmed'] == true));

  Map? get prevOpen {
    for (final h in hist) {
      if ('${h['status']}' != 'closed' && '${h['business_date']}' != ds)
        return h as Map;
    }
    return null;
  }

  Map? get lastClosed {
    for (final h in hist) {
      if ('${h['status']}' == 'closed' && '${h['business_date']}' != ds)
        return h as Map;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    Jobs.i.tick.addListener(_tick);
    DataCache.i.addListener(_cacheChanged);
    load();
  }

  @override
  void dispose() {
    Jobs.i.tick.removeListener(_tick);
    DataCache.i.removeListener(_cacheChanged);
    super.dispose();
  }

  void _cacheChanged() {
    final dashboardKey = 'dashboard:$ds';
    const historyKey = 'history:6:0';

    final d = DataCache.i.peek(dashboardKey);
    final h = DataCache.i.peek(historyKey);

    if (d is Map) dash = d;
    if (h is List) hist = h;

    if (!mounted) return;

    setState(() {});

    final dashboardStale =
        DataCache.i.has(dashboardKey) && DataCache.i.isStale(dashboardKey);
    final historyStale =
        DataCache.i.has(historyKey) && DataCache.i.isStale(historyKey);

    if (dashboardStale || historyStale) {
      load(quiet: true);
    }
  }

  void _tick() {
    if (mounted) load(quiet: true);
  }

  Future<void> refresh() async {
    try {
      await Future.wait([
        DataCache.i.load(
          'dashboard:$ds',
          () => Api.req('GET', '/api/v1/dashboard', q: {'business_date': ds}),
        ),
        DataCache.i.load(
          'history:6:0',
          () => fetch('/api/v1/history', q: {'limit': '6', 'offset': '0'}),
        ),
      ]);
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    }
  }

  Future<void> load({bool quiet = false}) async {
    if (!quiet)
      setState(() {
        busy = true;
        err = null;
      });
    try {
      final d = await DataCache.i.cached(
        'dashboard:$ds',
        () => Api.req('GET', '/api/v1/dashboard', q: {'business_date': ds}),
      );
      final h = await DataCache.i.cached(
        'history:6:0',
        () => fetch('/api/v1/history', q: {'limit': '6', 'offset': '0'}),
      );
      dash = d as Map;
      hist = h;
      shop = (await Store.get('shop')) ?? '';
      err = null;
    } on ApiException catch (e) {
      err = e.message;
    }
    if (!mounted) return;
    setState(() => busy = false);
    _maybeResume();
  }

  /// After the phone closed the app, go back into the work screen once.
  Future<void> _maybeResume() async {
    if (_resumed) return;
    _resumed = true;
    if (jn != null &&
        openingDone &&
        !closed &&
        (await Store.get('resume')) == '1' &&
        mounted) {
      openWork();
    }
  }

  Future<T?> push<T>(Widget w) =>
      Navigator.push<T>(context, MaterialPageRoute<T>(builder: (_) => w));

  Future<void> openWork({String? date}) async {
    await push(WorkScreen(date: date ?? ds));
    if (mounted) load(quiet: true);
  }

  Future<void> openSheet(String d) async {
    await push(DaySheet(date: d));
    if (mounted) load(quiet: true);
  }

  Future<Map?> _today() async {
    try {
      final key = 'journal:$ds';
      final fetch = () => Api.req('GET', '/api/v1/journals/by-date/$ds');

      if (DataCache.i.has(key) && !DataCache.i.isStale(key)) {
        return await DataCache.i.cached(key, fetch) as Map;
      }

      return await DataCache.i.load(key, fetch) as Map;
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
      return null;
    }
  }

  Future<void> start() async {
    try {
      await Api.req('POST', '/api/v1/journals', body: {'business_date': ds});
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
      return;
    }
    await openOpening();
  }

  Future<void> openOpening() async {
    final j = await _today();
    if (j == null || !mounted) return;
    final ok = await push<bool>(OpeningScreen(j: j));
    if (ok == true && mounted) {
      await openWork();
    } else if (mounted) {
      load(quiet: true);
    }
  }

  Future<void> endDay() async {
    if (Jobs.i.list.isNotEmpty) {
      toast(context, 'Wait. Some entries are not saved yet.');
      return;
    }
    final j = await _today();
    if (j == null || !mounted) return;
    final ok = await push<bool>(CloseScreen(j: j));
    if (ok == true && mounted) await push(DaySheet(date: ds));
    if (mounted) load(quiet: true);
  }

  Widget hero() {
    final prev = prevOpen;
    late String title, btn;
    late VoidCallback on;
    String sub = '';
    Widget? second;
    if (jn == null && prev != null) {
      final yest = '${prev['business_date']}' ==
          isoDate(DateTime.now().subtract(const Duration(days: 1)));
      title = yest
          ? "Yesterday isn't closed"
          : '${niceDate('${prev['business_date']}')} is not closed';
      sub = 'Close it first. Then start today.';
      btn = 'Open that day';
      on = () => openWork(date: '${prev['business_date']}');
    } else if (jn == null) {
      title = 'Business not started';
      btn = "Start Today's Business";
      on = start;
    } else if (!openingDone) {
      title = 'Confirm morning stock';
      sub = 'Check the fish you really have.';
      btn = 'Confirm morning stock';
      on = openOpening;
    } else if (!closed) {
      title = 'Business is open';
      sub = 'Record purchases and hotel sales.';
      btn = 'Continue Business';
      on = () => openWork();
      second = TextButton(
          onPressed: endDay,
          child:
              const Text('End of Day', style: TextStyle(color: Colors.white)));
    } else {
      title = 'Business closed';
      sub = 'Today is saved.';
      btn = "View Today's Sheet";
      on = () => openSheet(ds);
    }
    return Grad(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title,
          style: const TextStyle(
              color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
      if (sub.isNotEmpty)
        Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(sub, style: const TextStyle(color: Colors.white70))),
      const SizedBox(height: 16),
      FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: Colors.white, foregroundColor: ocean),
          onPressed: on,
          child: Text(btn)),
      if (second != null) Center(child: second),
    ]));
  }

  Widget owe(String t, dynamic v, Color col, int tab) => Expanded(
      child: Panel(
          onTap: () {
            accTab.value = tab;
            shellTab.value = 1;
          },
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t,
                style: const TextStyle(color: Colors.black54, fontSize: 12)),
            const SizedBox(height: 6),
            Text(inr(v),
                style: TextStyle(
                    color: col, fontWeight: FontWeight.w800, fontSize: 22)),
          ])));

  Widget act(String t, IconData i, Color col, VoidCallback on) => Expanded(
      child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: col),
              onPressed: on,
              icon: Icon(i),
              label: Text(t))));

  @override
  Widget build(BuildContext c) {
    if (busy && dash == null)
      return const Center(child: CircularProgressIndicator());
    if (dash == null) {
      return Center(
          child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.cloud_off, size: 48, color: Colors.black38),
                const SizedBox(height: 12),
                Text(err ?? 'Could not load', textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton(onPressed: load, child: const Text('Retry')),
              ])));
    }
    final h = DateTime.now().hour;
    final hi =
        h < 12 ? 'Good morning' : (h < 17 ? 'Good afternoon' : 'Good evening');
    final lc = lastClosed;
    final y = isoDate(DateTime.now().subtract(const Duration(days: 1)));
    final live = stock.where((r) => nz(r['current_stock']) > 0).toList();
    return RefreshIndicator(
        onRefresh: refresh,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Text(shop.isEmpty ? hi : '$hi • $shop',
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          Text(shortDate(ds), style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 14),
          const JobTray(),
          hero(),
          const SizedBox(height: 14),
          Row(children: [
            owe('Hotels owe you', dash!['hotel_outstanding_total'], teal, 0),
            const SizedBox(width: 12),
            owe('You owe suppliers', dash!['supplier_outstanding_total'], coral,
                1),
          ]),
          const SizedBox(height: 16),
          if (openingDone && !closed && live.isNotEmpty)
            Panel(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const Sect('Stock now', Icons.inventory_2, teal),
                  Wrap(children: [
                    for (final r in live)
                      Tile('${r['fish_name']}', kg(r['current_stock']))
                  ]),
                ])),
          if (lc != null)
            Panel(
                onTap: () => openSheet('${lc['business_date']}'),
                child: Row(children: [
                  CircleAvatar(
                      backgroundColor: tint(ocean),
                      child: const Icon(Icons.history, color: ocean)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(
                            '${lc['business_date']}' == y
                                ? "Yesterday's review"
                                : 'Last business day',
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 16)),
                        Text(
                            '${niceDate('${lc['business_date']}')} • Money ${inr(lc['total_money'])}',
                            style: const TextStyle(color: Colors.black54)),
                      ])),
                  const Icon(Icons.chevron_right),
                ])),
        ]));
  }
}
