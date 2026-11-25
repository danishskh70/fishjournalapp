import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/ui.dart';
import 'journal.dart';

const _lab = {
  'opening_quantity': 'Opening',
  'purchased': 'Purchased',
  'available': 'Available',
  'hotel_sold': 'Hotels',
  'normal_customer': 'Walk-in',
  'remaining': 'Remaining'
};
Widget? fishCard(Map r) {
  final t = [
    for (final e in _lab.entries)
      if (r[e.key] != null && num0(r[e.key]) != 0)
        Tile(e.value, kg(r[e.key]),
            col: e.key == 'normal_customer' ? teal : ocean)
  ];
  if (t.isEmpty) return null;
  return Inner(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text('${r['fish_name']}',
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
    const SizedBox(height: 8),
    Wrap(children: t)
  ]));
}

Widget entry(String kind, Map e, {VoidCallback? del}) {
  final pay = kind.endsWith('pay');

  return Inner(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${e['hotel_name'] ?? e['supplier_name'] ?? ''}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
            Text(
              inr(e['amount']),
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: kind == 'purchase' || kind == 'spay' ? coral : teal,
              ),
            ),
            if (del != null)
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.delete_outline),
                onPressed: del,
              ),
          ],
        ),
        if (e['fish_name'] != null)
          Text(
            '${e['fish_name']}',
            style: const TextStyle(color: Colors.black54),
          ),
        const SizedBox(height: 6),
        if (pay)
          Row(
            children: [
              Mini('Mode', '${e['payment_mode']}'.toUpperCase()),
              Mini('Date', niceDate('${e['payment_date']}')),
            ],
          )
        else ...[
          Row(
            children: [
              Mini('Quantity', kg(e['quantity'])),
              Mini('Rate', inr(e['rate'])),
            ],
          ),
          if (kind == 'purchase')
            Row(
              children: [
                Mini('Paid now', inr(e['paid_now'])),
                Mini('Due', inr(e['due_created']), col: coral),
              ],
            ),
        ],
      ],
    ),
  );
}

Widget block(String t, IconData i, Color col, List<Widget> kids,
        {List<Widget> tiles = const []}) =>
    Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(i, color: col),
        const SizedBox(width: 8),
        Text(t,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))
      ]),
      const SizedBox(height: 10),
      if (tiles.isNotEmpty) Wrap(children: tiles),
      if (kids.isEmpty)
        const Text('Nothing recorded', style: TextStyle(color: Colors.black45)),
      ...kids
    ]));
Widget balances(List l, Color col) => Column(children: [
      for (final b in l)
        Inner(Row(children: [
          Expanded(
              child: Text('${b['name']}',
                  style: const TextStyle(fontWeight: FontWeight.w700))),
          Text(inr(b['outstanding']),
              style: TextStyle(fontWeight: FontWeight.w800, color: col))
        ]))
    ]);

class DayDetail extends StatelessWidget {
  final DateTime date;
  const DayDetail({super.key, required this.date});
  @override
  Widget build(BuildContext c) => Scaffold(
      appBar: AppBar(title: Text(niceDate(isoDate(date)))),
      body: Fut(
          load: () =>
              Api.req('GET', '/api/v1/journals/by-date/${isoDate(date)}'),
          build: (c, x, re) {
            final j = x as Map;
            final pu = j['purchases'] as Map,
                sa = j['sales'] as Map,
                hi = j['hotel_info'] as Map,
                si = j['supplier_info'] as Map,
                m = j['money'] as Map?,
                pt = pu['totals'] as Map;
            final closed = '${j['status']}' == 'closed';
            return ListView(padding: const EdgeInsets.all(16), children: [
              Grad(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(closed ? 'CLOSED' : 'OPEN',
                        style: const TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    if (m != null)
                      Row(children: [
                        for (final p in [
                          ['Cash', m['cash_amount']],
                          ['UPI', m['upi_amount']],
                          ['Total', m['total']]
                        ])
                          Expanded(
                              child: Container(
                                  margin: const EdgeInsets.only(right: 8),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(.14),
                                      borderRadius: BorderRadius.circular(14)),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(p[0] as String,
                                            style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 12)),
                                        Text(inr(p[1]),
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w800,
                                                fontSize: 16))
                                      ])))
                      ])
                    else
                      const Text('Money not entered yet',
                          style: TextStyle(color: Colors.white))
                  ])),
              const SizedBox(height: 12),
              block('Stock', Icons.inventory_2, teal, [
                for (final r in stockRows(j))
                  if (fishCard(r) != null) fishCard(r)!
              ]),
              block('Purchases', Icons.shopping_basket, coral, [
                for (final e in L(pu['entries'])) entry('purchase', e)
              ], tiles: [
                Tile('Quantity', kg(pt['total_quantity'])),
                Tile('Amount', inr(pt['total_amount'])),
                Tile('Paid now', inr(pt['total_paid_now'])),
                Tile('Dues created', inr(pt['total_due_created']), col: coral)
              ]),
              block('Hotel sales', Icons.storefront, teal, [
                for (final e in L(sa['hotel_sales'])) entry('sale', e)
              ], tiles: [
                Tile('Quantity', kg(sa['total_hotel_quantity'])),
                Tile('Amount', inr(sa['total_hotel_amount']))
              ]),
              block('Walk-in customers', Icons.people, ocean, [
                for (final r in L(sa['normal_customer']))
                  Inner(Row(children: [
                    Expanded(
                        child: Text('${r['fish_name']}',
                            style:
                                const TextStyle(fontWeight: FontWeight.w700))),
                    Text(kg(r['quantity']),
                        style: const TextStyle(fontWeight: FontWeight.w800))
                  ]))
              ]),
              block('Later payments to suppliers', Icons.north_east, coral,
                  [for (final e in L(si['later_payments'])) entry('spay', e)]),
              block('Received from hotels', Icons.south_west, teal, [
                for (final e in L(hi['payments_received'])) entry('hpay', e)
              ], tiles: [
                Tile('Hotel sales', inr(hi['sales_total']))
              ]),
              block('Hotels owe you (on this date)', Icons.hotel, teal,
                  [balances(L(hi['outstanding_balances']), teal)]),
              block('You owe suppliers (on this date)', Icons.local_shipping,
                  coral, [balances(L(si['outstanding_balances']), coral)]),
              if (closed)
                OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(54)),
                    icon: const Icon(Icons.lock_open),
                    label: const Text('Reopen to correct'),
                    onPressed: () async {
                      if (!await confirm(c,
                          'Reopen this day? Later records will be recalculated.'))
                        return;
                      try {
                        await Api.req(
                            'POST', '/api/v1/journals/${j['id']}/reopen',
                            body: {'confirm': true});
                        re();
                      } on ApiException catch (e) {
                        if (c.mounted) toast(c, e.message);
                      }
                    })
            ]);
          }));
}
