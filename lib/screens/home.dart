import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/ui.dart';
import 'accounts.dart';
import 'day.dart';
import 'journal.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HS();
}

class _HS extends State<HomePage> {
  Map? j;
  bool busy = true;
  String? err;
  final today = DateTime.now();
  String get ds => isoDate(today);
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      busy = true;
      err = null;
    });
    try {
      j = await Api.req('GET', '/api/v1/journals/by-date/$ds');
    } on ApiException catch (e) {
      if (e.code == 404) {
        j = null;
      } else {
        err = e.message;
      }
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> go(Widget w) async {
    if (await Navigator.push(context, MaterialPageRoute(builder: (_) => w)) ==
        true) load();
  }

  Future<void> del(String path, Map e) async {
    if (!await confirm(context, 'Delete this entry?')) return;
    try {
      await Api.req('DELETE', '$path/${e['id']}');
      load();
    } on ApiException catch (x) {
      if (mounted) toast(context, x.message);
    }
  }

  Widget act(String t, String s, IconData i, Color col, VoidCallback on) =>
      Expanded(
          child: Padding(
              padding: const EdgeInsets.all(4),
              child: Material(
                  color: col,
                  borderRadius: BorderRadius.circular(22),
                  child: InkWell(
                      borderRadius: BorderRadius.circular(22),
                      onTap: on,
                      child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(i, color: Colors.white, size: 30),
                                const SizedBox(height: 14),
                                Text(t,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 17)),
                                Text(s,
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 12))
                              ]))))));
  @override
  Widget build(BuildContext c) {
    if (busy) return const Center(child: CircularProgressIndicator());
    if (err != null)
      return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(err!),
        const SizedBox(height: 12),
        FilledButton(onPressed: load, child: const Text('Retry'))
      ]));
    final closed = j != null && '${j!['status']}' == 'closed';
    final jid = j == null ? 0 : j!['id'] as int;
    final done = j != null && openingDone(j!);
    final open = j == null
        ? []
        : stockRows(j!).where((r) => num0(r['opening_quantity']) > 0).toList();
    return RefreshIndicator(
        onRefresh: load,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Grad(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(niceDate(ds),
                    style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 4),
                Text(
                    j == null
                        ? 'Start your day'
                        : closed
                            ? 'Business closed'
                            : 'Business is open',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800)),
                if (j == null) ...[
                  const SizedBox(height: 14),
                  FilledButton(
                      style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: ocean),
                      onPressed: () async {
                        try {
                          await Api.req('POST', '/api/v1/journals',
                              body: {'business_date': ds});
                          load();
                        } on ApiException catch (e) {
                          toast(c, e.message);
                        }
                      },
                      child: const Text("Start today's journal"))
                ]
              ])),
          const SizedBox(height: 14),
          if (j != null) ...[
            if (!done)
              Panel(
                  onTap: () => go(OpeningScreen(j: j!)),
                  child: const Row(children: [
                    CircleAvatar(
                        backgroundColor: Color(0x22FF7A59),
                        child: Icon(Icons.inventory_2, color: coral)),
                    SizedBox(width: 12),
                    Expanded(
                        child: Text('Confirm opening stock first',
                            style: TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 16))),
                    Icon(Icons.chevron_right)
                  ]))
            else
              block('Opening stock', Icons.inventory_2, teal, [
                Wrap(children: [
                  for (final r in open)
                    Tile('${r['fish_name']}', kg(r['opening_quantity']))
                ])
              ]),
            if (done && !closed) ...[
              Row(children: [
                act(
                    'Purchase',
                    'with payment',
                    Icons.shopping_basket,
                    coral,
                    () => sheet<bool>(c, TxForm(jid: jid, sale: false))
                        .then((v) => v == true ? load() : null)),
                act(
                    'Hotel sale',
                    'fish to hotel',
                    Icons.storefront,
                    teal,
                    () => sheet<bool>(c, TxForm(jid: jid, sale: true))
                        .then((v) => v == true ? load() : null))
              ]),
              Row(children: [
                act(
                    'Pay supplier',
                    'old dues',
                    Icons.north_east,
                    const Color(0xFFB4533A),
                    () => sheet(c, const PaySheet(hotel: false))
                        .then((_) => load())),
                act(
                    'Hotel paid',
                    'money received',
                    Icons.south_west,
                    const Color(0xFF0E6E7E),
                    () => sheet(c, const PaySheet(hotel: true))
                        .then((_) => load()))
              ]),
              const SizedBox(height: 10)
            ],
            block("Today's purchases", Icons.shopping_basket, coral, [
              for (final e in L(j!['purchases']['entries']))
                entry('purchase', e,
                    del: closed ? null : () => del('/api/v1/purchases', e))
            ]),
            block("Today's hotel sales", Icons.storefront, teal, [
              for (final e in L(j!['sales']['hotel_sales']))
                entry('sale', e,
                    del: closed ? null : () => del('/api/v1/hotel-sales', e))
            ]),
            block('Paid to suppliers (later)', Icons.north_east, coral, [
              for (final e in L(j!['supplier_info']['later_payments']))
                entry('spay', e)
            ]),
            block('Received from hotels', Icons.south_west, teal, [
              for (final e in L(j!['hotel_info']['payments_received']))
                entry('hpay', e)
            ]),
            if (closed) ...[
              FilledButton(
                  onPressed: () => Navigator.push(
                          c,
                          MaterialPageRoute(
                              builder: (_) => DayDetail(date: today)))
                      .then((_) => load()),
                  child: const Text("View today's full record"))
            ] else if (done)
              FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: coral),
                  onPressed: () => go(CloseScreen(j: j!)),
                  child: const Text('Close business'))
          ]
        ]));
  }
}
