import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/cache.dart';
import '../core/jobs.dart';
import '../core/store.dart';
import '../core/ui.dart';
import 'entries.dart';
import 'entry.dart';
import 'close.dart';
import 'pay.dart';
import 'sheet.dart';

/// The screen the owner stays on during the day. Two big fast actions.
class WorkScreen extends StatefulWidget {
  final String date;
  const WorkScreen({super.key, required this.date});
  @override
  State<WorkScreen> createState() => _WS();
}

class _WS extends State<WorkScreen> {
  Map? j;
  bool busy = true;
  String? err;
  bool get closed => j != null && '${j!['status']}' == 'closed';
  bool get isToday => widget.date == isoDate(DateTime.now());

  @override
  void initState() {
    super.initState();
    Store.set('resume', '1');
    final c0 = DataCache.i.peek('journal:${widget.date}');
    if (c0 is Map) j = c0;
    Jobs.i.tick.addListener(_tick);
    DataCache.i.addListener(_cacheChanged);
    load();
  }

  @override
  void dispose() {
    Store.del('resume');
    Jobs.i.tick.removeListener(_tick);
    DataCache.i.removeListener(_cacheChanged);
    super.dispose();
  }

  void _cacheChanged() {
    final key = 'journal:${widget.date}';
    final cached = DataCache.i.peek(key);

    if (cached is Map) j = cached;
    if (!mounted) return;

    setState(() {});

    if (DataCache.i.has(key) && DataCache.i.isStale(key)) {
      load(quiet: true);
    }
  }

  void _tick() {
    if (mounted) load(quiet: true);
  }

  Future<void> load({bool quiet = false}) async {
    if (!quiet)
      setState(() {
        busy = true;
        err = null;
      });
    try {
      j = await DataCache.i.cached(
        'journal:${widget.date}',
        () => Api.req('GET', '/api/v1/journals/by-date/${widget.date}'),
      ) as Map;
      err = null;
    } on ApiException catch (e) {
      err = e.message;
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> flow(bool sale) async {
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => EntryFlow(sale: sale, journalId: j!['id'] as int)));
    if (mounted) load(quiet: true);
  }

  Future<void> pay(bool hotel) async {
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => PayScreen(hotel: hotel)));
    if (mounted) load(quiet: true);
  }

  Future<void> entries() async {
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => TodayEntries(date: widget.date)));
    if (mounted) load(quiet: true);
  }

  Future<void> endDay() async {
    if (Jobs.i.list.isNotEmpty) {
      toast(context, 'Wait. Some entries are not saved yet.');
      return;
    }
    final ok = await Navigator.push<bool>(
        context, MaterialPageRoute<bool>(builder: (_) => CloseScreen(j: j!)));
    if (ok == true && mounted) {
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => DaySheet(date: widget.date)));
    }
  }

  @override
  Widget build(BuildContext c) {
    final title = isToday ? "Today's Business" : niceDate(widget.date);
    return Scaffold(
        appBar: AppBar(title: Text(title)),
        bottomNavigationBar: j != null && !closed
            ? SafeArea(
                child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: coral),
                        onPressed: endDay,
                        child: const Text('End of Day'))))
            : null,
        body: body());
  }

  /// Stock flow: fish across the top, steps down the side.
  Widget stockTable() {
    final rows = L(M(j!['stock'])['rows'])
        .where((r) =>
            nz(r['opening_quantity']) != 0 ||
            nz(r['purchased']) != 0 ||
            nz(r['hotel_sold']) != 0 ||
            nz(r['current_stock']) != 0)
        .toList();
    if (rows.isEmpty) return const EmptyNote('No stock yet.');
    List<String> line(String k) => [
          for (final r in rows) qty(r[k]),
          qty(sum(rows, k)),
        ];
    return LayoutBuilder(builder: (c, box) {
      final need = 100.0 + 72.0 * (rows.length + 1);
      final w = need > box.maxWidth ? need : box.maxWidth;
      return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
              width: w,
              child: tbl([
                'kg',
                for (final r in rows) '${r['fish_name']}',
                'Total'
              ], [
                ['Opening', ...line('opening_quantity')],
                ['+ Purchase', ...line('purchased')],
                ['\u2212 Hotel sale', ...line('hotel_sold')],
              ], foot: [
                'Now',
                ...line('current_stock')
              ], flex: [
                3,
                for (final _ in rows) 2,
                2
              ])));
    });
  }

  Widget body() {
    if (busy && j == null)
      return const Center(child: CircularProgressIndicator());
    if (j == null) {
      return Center(
          child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(err ?? 'No business for this date',
                    textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton(onPressed: load, child: const Text('Retry')),
              ])));
    }
    if (closed) {
      return Center(
          child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.lock, size: 48, color: Colors.black38),
                const SizedBox(height: 12),
                const Text('This business day is closed.'),
                const SizedBox(height: 12),
                FilledButton(
                    onPressed: () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (_) => DaySheet(date: widget.date))),
                    child: const Text('View sheet')),
              ])));
    }
    final pt = M(M(j!['purchases'])['totals']);
    final sa = M(j!['sales']);
    final live = L(M(j!['stock'])['rows'])
        .where((r) => nz(r['current_stock']) > 0)
        .toList();
    return RefreshIndicator(
        onRefresh: load,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          const JobTray(),
          Row(children: [
            Expanded(
                child: BigTile('Purchase', 'Buy from supplier',
                    Icons.shopping_basket, coral, () => flow(false))),
            const SizedBox(width: 12),
            Expanded(
                child: BigTile('Hotel sale', 'Fish to hotel', Icons.storefront,
                    teal, () => flow(true))),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: OutlinedButton(
                        onPressed: () => pay(true),
                        child: const Text('Hotel paid')))),
            Expanded(
                child: Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: OutlinedButton(
                        onPressed: () => pay(false),
                        child: const Text('Pay supplier')))),
          ]),
          const SizedBox(height: 16),
          Panel(
              onTap: entries,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Expanded(
                          child: Sect('Today so far', Icons.today, ocean)),
                      const Icon(Icons.chevron_right)
                    ]),
                    Row(children: [
                      Mini('Bought',
                          '${kg(pt['total_quantity'])}\n${inr(pt['total_amount'])}',
                          col: coral),
                      Mini('Hotel sales',
                          '${kg(sa['total_hotel_quantity'])}\n${inr(sa['total_hotel_amount'])}',
                          col: teal)
                    ]),
                    const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Text('Tap to see, edit or delete entries',
                            style: TextStyle(
                                color: Colors.black54, fontSize: 12))),
                  ])),
          if (live.isNotEmpty)
            Panel(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const Sect('Stock now', Icons.inventory_2, teal),
                  stockTable(),
                ])),
        ]));
  }
}
