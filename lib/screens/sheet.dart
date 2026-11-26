import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/cache.dart';
import '../core/ui.dart';

/// Read-only sheet of one business day. Same view for today (closed), yesterday and History.
/// Order: stock -> purchases -> hotel sales -> walk-in customers -> money -> payments -> balances.
class DaySheet extends StatefulWidget {
  final String date;
  const DaySheet({super.key, required this.date});
  @override
  State<DaySheet> createState() => _DS();
}

class _DS extends State<DaySheet> {
  Map? j;
  String? err;
  bool busy = true;

  @override
  void initState() {
    super.initState();
    DataCache.i.addListener(_cacheChanged);
    load();
  }

  @override
  void dispose() {
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
      load();
    }
  }

  Future<void> load() async {
    if (j == null)
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

  Future<void> _refresh() async {
    try {
      final fresh = await DataCache.i.load(
        'journal:${widget.date}',
        () => Api.req('GET', '/api/v1/journals/by-date/${widget.date}'),
      );

      if (!mounted) return;

      setState(() {
        j = fresh as Map;
        err = null;
      });
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    }
  }

  bool get closed => j != null && '${j!['status']}' == 'closed';

  Future<void> reopen() async {
    if (!await confirm(context,
        'Open this day again to correct it? You must close it again after.'))
      return;
    try {
      await Api.req('POST', '/api/v1/journals/${j!['id']}/reopen',
          body: {'confirm': true});
      if (!mounted) return;
      toast(context, 'Day opened again. Correct it, then End of Day.');
      Navigator.pop(context);
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
      appBar: AppBar(title: Text(niceDate(widget.date)), actions: [
        if (closed)
          PopupMenuButton<String>(
              tooltip: 'More',
              onSelected: (v) {
                if (v == 'reopen') reopen();
              },
              itemBuilder: (_) => const [
                    PopupMenuItem(
                        value: 'reopen', child: Text('Open again to correct'))
                  ]),
      ]),
      body: busy
          ? const Center(child: CircularProgressIndicator())
          : j == null
              ? Center(
                  child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(err ?? 'No business on this day',
                            textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(
                            onPressed: load, child: const Text('Retry'))
                      ])))
              : RefreshIndicator(onRefresh: _refresh, child: body(j!)));

  // ---------- helpers ----------
  Widget card(String t, IconData i, Color col, List<Widget> kids) => Panel(
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [Sect(t, i, col), ...kids]));

  List<List<String>> mergeRows(List es) {
    final m = <String, List<dynamic>>{};
    for (final e in es) {
      final k = '${e['fish_id']}|${e['rate']}';
      final r = m.putIfAbsent(k, () => [e['fish_name'], 0.0, e['rate'], 0.0]);
      r[1] = (r[1] as num) + nz(e['quantity']);
      r[3] = (r[3] as num) + nz(e['amount']);
    }
    return [
      for (final r in m.values) ['${r[0]}', qty(r[1]), inr(r[2]), inr(r[3])]
    ];
  }

  /// One block per account (supplier or hotel). Repeated rows of the same account are combined.
  Widget acct(String name, List es, {bool purchase = false}) {
    final amount = sum(es, 'amount');
    return Inner(
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
            child: Text(name,
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 16))),
        Text(inr(amount),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      ]),
      const SizedBox(height: 4),
      tbl(['Fish', 'Kg', 'Rate', 'Amount'], mergeRows(es),
          foot: ['Total', qty(sum(es, 'quantity')), '', inr(amount)],
          flex: [3, 2, 2, 3]),
      if (purchase)
        Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
                'Paid ${inr(sum(es, 'paid_now'))} • Pending ${inr(sum(es, 'due_created'))}',
                style: const TextStyle(color: Colors.black54, fontSize: 12))),
    ]));
  }

  List<Widget> groups(List es, String nameKey, {bool purchase = false}) {
    final g = <String, List>{};
    for (final e in es) {
      g.putIfAbsent('${e[nameKey]}', () => []).add(e);
    }
    return [for (final k in g.keys) acct(k, g[k]!, purchase: purchase)];
  }

  /// Fish card with two stacked lines: what came in, what went out.
  Widget stockCard(Map r) {
    String v(dynamic x) => x == null ? '-' : qty(x);
    return Inner(
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('${r['fish_name']}',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      const SizedBox(height: 6),
      Row(children: [
        Mini('Morning', '${v(r['opening_quantity'])} kg'),
        Mini('Bought', '${v(r['purchased'])} kg'),
        Mini('Available', '${v(r['available'])} kg', col: ocean),
      ]),
      Row(children: [
        Mini('Hotels', '${v(r['hotel_sold'])} kg', col: teal),
        Mini('Walk-in', '${v(r['normal_customer'])} kg', col: teal),
        Mini('Left', '${v(r['remaining'])} kg', col: coral),
      ]),
    ]));
  }

  Widget stockSection(Map jj) {
    final st = M(jj['stock']);
    final rows = L(st['rows'])
        .where((r) =>
            nz(r['opening_quantity']) != 0 ||
            nz(r['purchased']) != 0 ||
            nz(r['hotel_sold']) != 0 ||
            nz(r['remaining']) != 0 ||
            nz(r['normal_customer']) != 0)
        .toList();
    if (rows.isEmpty) return const EmptyNote('No stock recorded.');
    final t = M(st['totals']);
    final notes = [
      for (final r in rows)
        if (r['previous_closing'] != null &&
            r['opening_quantity'] != null &&
            nz(r['previous_closing']) != nz(r['opening_quantity']))
          '${r['fish_name']}: yesterday ${qty(r['previous_closing'])} kg, morning ${qty(r['opening_quantity'])} kg'
    ];
    String v(dynamic x) => x == null ? '-' : qty(x);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final r in rows) stockCard(r as Map),
      Inner(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('All fish',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        const SizedBox(height: 6),
        Row(children: [
          Mini('Morning', '${v(t['opening_quantity'])} kg'),
          Mini('Bought', '${v(t['purchased'])} kg'),
          Mini('Available', '${v(t['available'])} kg')
        ]),
        Row(children: [
          Mini('Hotels', '${v(t['hotel_sold'])} kg', col: teal),
          Mini('Walk-in', '${v(t['normal_customer'])} kg', col: teal),
          Mini('Left', '${v(t['remaining'])} kg', col: coral)
        ]),
      ])),
      for (final s in notes)
        Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(s,
                style: const TextStyle(color: Colors.black54, fontSize: 12))),
    ]);
  }

  Widget payTable(List ps, String nameKey) {
    if (ps.isEmpty) return const EmptyNote('None.');
    final names = <String>[];
    final cash = <String, num>{}, upi = <String, num>{};
    for (final p in ps) {
      final k = '${p[nameKey]}';
      if (!names.contains(k)) names.add(k);
      final m = '${p['payment_mode']}' == 'upi' ? upi : cash;
      m[k] = (m[k] ?? 0) + nz(p['amount']);
    }
    final rows = [
      for (final k in names)
        [
          k,
          inr(cash[k] ?? 0),
          inr(upi[k] ?? 0),
          inr((cash[k] ?? 0) + (upi[k] ?? 0))
        ]
    ];
    final tc = cash.values.fold<num>(0, (a, b) => a + b),
        tu = upi.values.fold<num>(0, (a, b) => a + b);
    return tbl(['Name', 'Cash', 'UPI', 'Total'], rows,
        foot: ['Total', inr(tc), inr(tu), inr(tc + tu)], flex: [3, 2, 2, 2]);
  }

  Widget balances(List bs) {
    final l = bs.where((b) => nz(b['outstanding']) != 0).toList();
    if (l.isEmpty) return const EmptyNote('All clear.');
    return tbl([
      'Name',
      'Pending'
    ], [
      for (final b in l) ['${b['name']}', inr(b['outstanding'])]
    ], foot: [
      'Total',
      inr(sum(l, 'outstanding'))
    ], flex: [
      3,
      2
    ]);
  }

  Widget body(Map jj) {
    final pu = M(jj['purchases']);
    final pt = M(pu['totals']);
    final sa = M(jj['sales']);
    final hi = M(jj['hotel_info']);
    final si = M(jj['supplier_info']);
    final nc = L(sa['normal_customer']);
    final m = jj['money'] == null ? null : M(jj['money']);
    final pur = L(pu['entries']);
    final sal = L(sa['hotel_sales']);
    return ListView(padding: const EdgeInsets.all(16), children: [
      Grad(
          child: Row(children: [
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(shortDate(widget.date),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800)),
          Text(closed ? 'Closed. Read only.' : 'Still open',
              style: const TextStyle(color: Colors.white70)),
        ])),
        Icon(closed ? Icons.lock : Icons.lock_open, color: Colors.white),
      ])),
      const SizedBox(height: 14),
      card('1. Stock', Icons.inventory_2, teal, [stockSection(jj)]),
      card('2. Purchases', Icons.shopping_basket, coral, [
        if (pur.isEmpty) const EmptyNote('No purchases.'),
        ...groups(pur, 'supplier_name', purchase: true),
        if (pur.isNotEmpty)
          Row(children: [
            Mini('Kg', qty(pt['total_quantity'])),
            Mini('Amount', inr(pt['total_amount'])),
            Mini('Paid', inr(pt['total_paid_now']), col: teal),
            Mini('Pending', inr(pt['total_due_created']), col: coral)
          ]),
      ]),
      card('3. Hotel sales', Icons.storefront, teal, [
        if (sal.isEmpty) const EmptyNote('No hotel sales.'),
        ...groups(sal, 'hotel_name'),
        if (sal.isNotEmpty)
          Row(children: [
            Mini('Kg', qty(sa['total_hotel_quantity'])),
            Mini('Amount', inr(sa['total_hotel_amount']), col: teal)
          ]),
      ]),
      card('4. Walk-in customers', Icons.people, ocean, [
        if (sa['total_normal_customer_quantity'] == null)
          const EmptyNote('Worked out at End of Day.')
        else if (nc.isEmpty)
          const EmptyNote('No walk-in sales.')
        else
          tbl([
            'Fish',
            'Kg'
          ], [
            for (final e in nc) ['${e['fish_name']}', qty(e['quantity'])]
          ], foot: [
            'Total',
            qty(sa['total_normal_customer_quantity'])
          ], flex: [
            3,
            1
          ]),
      ]),
      card('5. Money (entered by you)', Icons.payments, ocean, [
        if (m == null || m.isEmpty)
          const EmptyNote('Not entered yet.')
        else
          Row(children: [
            Mini('Cash', inr(m['cash_amount'])),
            Mini('UPI', inr(m['upi_amount'])),
            Mini('Total', inr(m['total']), col: teal)
          ]),
      ]),
      card('6. Payments today', Icons.swap_horiz, deep, [
        const Text('Received from hotels',
            style: TextStyle(fontWeight: FontWeight.w700)),
        payTable(L(hi['payments_received']), 'hotel_name'),
        const SizedBox(height: 12),
        const Text('Paid to suppliers later',
            style: TextStyle(fontWeight: FontWeight.w700)),
        payTable(L(si['later_payments']), 'supplier_name'),
        if (nz(si['paid_immediately_total']) > 0)
          Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                  'Paid at purchase: ${inr(si['paid_immediately_total'])}',
                  style: const TextStyle(color: Colors.black54, fontSize: 12))),
        const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text('These are not part of the money above.',
                style: TextStyle(color: Colors.black54, fontSize: 12))),
      ]),
      card('7. Pending on this date', Icons.account_balance_wallet, coral, [
        const Text('Hotels owe you',
            style: TextStyle(fontWeight: FontWeight.w700)),
        balances(L(hi['outstanding_balances'])),
        const SizedBox(height: 12),
        const Text('You owe suppliers',
            style: TextStyle(fontWeight: FontWeight.w700)),
        balances(L(si['outstanding_balances'])),
      ]),
    ]);
  }
}
