import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/ui.dart';
import 'pay.dart';

class AccountsPage extends StatefulWidget {
  const AccountsPage({super.key});
  @override
  State<AccountsPage> createState() => _AP();
}

class _AP extends State<AccountsPage> {
  int v = 0;

  Future<void> pay(bool hotel, {int? id}) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => PayScreen(hotel: hotel, partyId: id)));
    if (mounted) setState(() => v++);
  }

  @override
  Widget build(BuildContext c) => ValueListenableBuilder<int>(
      valueListenable: accTab,
      builder: (c, t, _) {
        final hotel = t == 0;
        return Scaffold(
            backgroundColor: Colors.transparent,
            floatingActionButton: FloatingActionButton.extended(onPressed: () => pay(hotel), icon: const Icon(Icons.add), label: Text(hotel ? 'Hotel paid' : 'Pay supplier')),
            body: Column(children: [
              const Padding(padding: EdgeInsets.fromLTRB(16, 16, 16, 8), child: Align(alignment: Alignment.centerLeft, child: Text('Accounts', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)))),
              Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SegmentedButton<int>(
                      segments: const [ButtonSegment(value: 0, label: Text('Hotels'), icon: Icon(Icons.hotel)), ButtonSegment(value: 1, label: Text('Suppliers'), icon: Icon(Icons.local_shipping))],
                      selected: {t},
                      onSelectionChanged: (s) => accTab.value = s.first)),
              const SizedBox(height: 8),
              Expanded(
                  child: Fut(
                      key: ValueKey('$t-$v'),
                      load: () => fetch(hotel ? '/api/v1/accounts/hotels' : '/api/v1/accounts/suppliers'),
                      build: (c, data, re) {
                        final l = List.of(data as List)..sort((a, b) => nz(b['outstanding']).compareTo(nz(a['outstanding'])));
                        final totalAmt = sum(l, 'outstanding');
                        return RefreshIndicator(
                            onRefresh: () async => setState(() => v++),
                            child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 96), children: [
                              Grad(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(hotel ? 'Hotels owe you' : 'You owe suppliers', style: const TextStyle(color: Colors.white70)),
                                const SizedBox(height: 4),
                                Text(inr(totalAmt), style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800)),
                              ])),
                              const SizedBox(height: 14),
                              if (l.isEmpty) EmptyNote(hotel ? 'No hotels yet. Add in Settings.' : 'No suppliers yet. Add in Settings.'),
                              for (final x in l)
                                Panel(
                                    onTap: () async {
                                      await Navigator.push(c, MaterialPageRoute(builder: (_) => LedgerPage(hotel: hotel, id: x['id'] as int, name: '${x['name']}')));
                                      if (mounted) setState(() => v++);
                                    },
                                    child: Row(children: [
                                      CircleAvatar(backgroundColor: tint(hotel ? teal : coral), child: Icon(hotel ? Icons.hotel : Icons.local_shipping, color: hotel ? teal : coral)),
                                      const SizedBox(width: 12),
                                      Expanded(child: Text('${x['name']}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17))),
                                      Text(nz(x['outstanding']) > 0 ? inr(x['outstanding']) : 'Clear', style: TextStyle(fontWeight: FontWeight.w800, color: nz(x['outstanding']) > 0 ? (hotel ? teal : coral) : Colors.black54)),
                                      const Icon(Icons.chevron_right),
                                    ])),
                            ]));
                      }))
            ]));
      });
}

class LedgerPage extends StatefulWidget {
  final bool hotel;
  final int id;
  final String name;
  const LedgerPage({super.key, required this.hotel, required this.id, required this.name});
  @override
  State<LedgerPage> createState() => _LP();
}

class _LP extends State<LedgerPage> {
  DateTimeRange? r;
  int v = 0;
  String get base => '/api/v1/accounts/${widget.hotel ? 'hotels' : 'suppliers'}/${widget.id}';

  Future<void> pickRange() async {
    final now = DateTime.now();
    final x = await showDateRangePicker(context: context, firstDate: DateTime(now.year - 3), lastDate: now, initialDateRange: r);
    if (x != null) setState(() => r = x);
  }

  Future<void> pay() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => PayScreen(hotel: widget.hotel, partyId: widget.id)));
    if (mounted) setState(() => v++);
  }

  Future<void> month() async {
    final now = DateTime.now();
    await sheet<void>(context, MonthSheet(hotelId: widget.id, name: widget.name, year: now.year, month: now.month));
  }

  Widget entry(Map e) {
    final pay = '${e['entry_type']}'.toLowerCase().contains('payment') || e['fish_name'] == null;
    final col = pay ? teal : coral;
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(pay ? Icons.south_west : Icons.set_meal, size: 20, color: col),
          const SizedBox(width: 10),
          Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(pay ? '${widget.hotel ? 'Received' : 'Paid'} (${'${e['payment_mode'] ?? ''}'.toUpperCase()})' : '${e['fish_name']}', style: const TextStyle(fontWeight: FontWeight.w700)),
            if (!pay) Text('${qty(e['quantity'])} kg × ${inr(e['rate'])}', style: const TextStyle(color: Colors.black54, fontSize: 12)),
            if (!pay && !widget.hotel && e['paid_now'] != null) Text('Paid ${inr(e['paid_now'])} • Pending ${inr(e['due_created'])}', style: const TextStyle(color: Colors.black54, fontSize: 12)),
          ])),
          Text('${pay ? '-' : '+'}${inr(e['amount'])}', style: TextStyle(color: col, fontWeight: FontWeight.w800)),
        ]));
  }

  @override
  Widget build(BuildContext c) => Scaffold(
      appBar: AppBar(title: Text(widget.name), actions: [
        IconButton(tooltip: 'Choose dates', icon: const Icon(Icons.date_range), onPressed: pickRange),
        if (widget.hotel) IconButton(tooltip: 'Month summary', icon: const Icon(Icons.calendar_month), onPressed: month),
      ]),
      body: Fut(
          key: ValueKey('${r?.start}-${r?.end}-$v'),
          load: () => Api.req('GET', '$base/ledger', q: {if (r != null) 'from_date': isoDate(r!.start), if (r != null) 'to_date': isoDate(r!.end)}),
          build: (c, d, re) {
            final es = L(d['entries']);
            final g = <String, List>{};
            for (final e in es) {
              g.putIfAbsent('${e['date']}', () => []).add(e);
            }
            final keys = g.keys.toList().reversed.toList();
            return ListView(padding: const EdgeInsets.all(16), children: [
              Grad(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.hotel ? 'Owes you' : 'You owe', style: const TextStyle(color: Colors.white70)),
                Text(inr(d['closing_balance']), style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('Balance before this list: ${inr(d['previous_balance'])}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 14),
                FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: ocean), onPressed: pay, child: Text(widget.hotel ? 'Hotel paid' : 'Pay supplier')),
              ])),
              const SizedBox(height: 14),
              if (r != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('Showing ${niceDate(isoDate(r!.start))} to ${niceDate(isoDate(r!.end))}', style: const TextStyle(color: Colors.black54))),
              if (es.isEmpty) const EmptyNote('No entries yet.'),
              for (final k in keys)
                Panel(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(shortDate(k), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                    Text('Balance ${inr(g[k]!.last['running_balance'])}', style: const TextStyle(color: Colors.black54, fontSize: 12)),
                  ]),
                  const Divider(),
                  for (final e in g[k]!) entry(e as Map),
                ])),
            ]);
          }));
}

class MonthSheet extends StatefulWidget {
  final int hotelId, year, month;
  final String name;
  const MonthSheet({super.key, required this.hotelId, required this.name, required this.year, required this.month});
  @override
  State<MonthSheet> createState() => _MS();
}

class _MS extends State<MonthSheet> {
  late int y = widget.year, m = widget.month;
  void step(int d) => setState(() {
        m += d;
        if (m < 1) {
          m = 12;
          y--;
        }
        if (m > 12) {
          m = 1;
          y++;
        }
      });

  @override
  Widget build(BuildContext c) => Column(mainAxisSize: MainAxisSize.min, children: [
        Text(widget.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton(tooltip: 'Previous month', icon: const Icon(Icons.chevron_left), onPressed: () => step(-1)),
          Text('${['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][m - 1]} $y', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          IconButton(tooltip: 'Next month', icon: const Icon(Icons.chevron_right), onPressed: () => step(1)),
        ]),
        SizedBox(
            height: 200,
            child: Fut(
                key: ValueKey('$y-$m'),
                load: () => Api.req('GET', '/api/v1/accounts/hotels/${widget.hotelId}/monthly-summary', q: {'year': '$y', 'month': '$m'}),
                build: (c, d, re) => Column(children: [
                      tbl(['Month summary', 'Amount'], [
                        ['Pending at start', inr(d['opening_outstanding'])],
                        ['Fish taken', inr(d['fish_taken'])],
                        ['Payments received', inr(d['payments_received'])],
                      ], foot: ['Pending at end', inr(d['closing_outstanding'])], flex: [3, 2]),
                    ]))),
      ]);
}
