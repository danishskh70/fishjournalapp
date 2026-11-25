import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/ui.dart';
import 'journal.dart';

class AccountsPage extends StatelessWidget {
  const AccountsPage({super.key});
  @override
  Widget build(BuildContext c) => DefaultTabController(
      length: 2,
      child: Column(children: [
        const Padding(
            padding: EdgeInsets.all(16),
            child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Accounts',
                    style:
                        TextStyle(fontSize: 26, fontWeight: FontWeight.w800)))),
        const TabBar(tabs: [Tab(text: 'Hotels'), Tab(text: 'Suppliers')]),
        const Expanded(
            child:
                TabBarView(children: [_Bal(hotel: true), _Bal(hotel: false)]))
      ]));
}

class _Bal extends StatelessWidget {
  final bool hotel;
  const _Bal({required this.hotel});
  @override
  Widget build(BuildContext c) {
    final k = hotel ? 'hotels' : 'suppliers';
    return Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: FloatingActionButton.extended(
            backgroundColor: ocean,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.payments),
            label: Text(hotel ? 'Hotel payment' : 'Pay supplier'),
            onPressed: () => sheet(c, PaySheet(hotel: hotel))),
        body: Fut(
            load: () => fetch('/api/v1/accounts/$k'),
            build: (c, data, re) {
              final l = data as List;
              if (l.isEmpty)
                return const Center(child: Text('No accounts yet'));
              return RefreshIndicator(
                  onRefresh: () async => re(),
                  child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                      children: [
                        for (final e in l)
                          Panel(
                              onTap: () => Navigator.push(
                                  c,
                                  MaterialPageRoute(
                                      builder: (_) => LedgerPage(
                                          hotel: hotel,
                                          id: (pick(e, [
                                            'id',
                                            '${hotel ? 'hotel' : 'supplier'}_id'
                                          ])) as int,
                                          name: '${pick(e, [
                                                'name',
                                                '${hotel ? 'hotel' : 'supplier'}_name'
                                              ])}'))),
                              child: Row(children: [
                                CircleAvatar(
                                    backgroundColor:
                                        (hotel ? teal : coral).withOpacity(.15),
                                    child: Icon(
                                        hotel
                                            ? Icons.hotel
                                            : Icons.local_shipping,
                                        color: hotel ? teal : coral)),
                                const SizedBox(width: 12),
                                Expanded(
                                    child: Text(
                                        '${pick(e, [
                                              'name',
                                              '${hotel ? 'hotel' : 'supplier'}_name'
                                            ])}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 16))),
                                Text(
                                    inr(pick(e, [
                                      'outstanding',
                                      'outstanding_balance',
                                      'balance',
                                      'closing_balance'
                                    ])),
                                    style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 17,
                                        color: hotel ? teal : coral))
                              ]))
                      ]));
            }));
  }
}

class LedgerPage extends StatefulWidget {
  final bool hotel;
  final int id;
  final String name;
  const LedgerPage(
      {super.key, required this.hotel, required this.id, required this.name});
  @override
  State<LedgerPage> createState() => _LS();
}

class _LS extends State<LedgerPage> {
  DateTimeRange? r;
  @override
  Widget build(BuildContext c) => Scaffold(
      appBar: AppBar(title: Text(widget.name), actions: [
        if (widget.hotel)
          IconButton(
              icon: const Icon(Icons.calendar_month),
              onPressed: () => sheet(c, MonthSheet(id: widget.id))),
        IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: () async {
              final x = await showDateRangePicker(
                  context: c,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now());
              if (x != null) setState(() => r = x);
            }),
        if (r != null)
          IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () => setState(() => r = null))
      ]),
      body: Fut(
          key: ValueKey(r),
          load: () => Api.req('GET',
                  '/api/v1/accounts/${widget.hotel ? 'hotels' : 'suppliers'}/${widget.id}/ledger',
                  q: {
                    if (r != null) 'from_date': isoDate(r!.start),
                    if (r != null) 'to_date': isoDate(r!.end)
                  }),
          build: (c, d, re) =>
              ListView(padding: const EdgeInsets.all(16), children: [
                Grad(
                    child: Column(children: [
                  for (final k in ['previous_balance', 'closing_balance'])
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(label(k),
                              style: const TextStyle(color: Colors.white70)),
                          Text(inr(d[k]),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18))
                        ])
                ])),
                const SizedBox(height: 12),
                for (final e in d['entries'] as List)
                  Panel(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Row(children: [
                          Expanded(
                              child: Text(
                                  label('${e['entry_type']}') +
                                      (e['fish_name'] != null
                                          ? ' • ${e['fish_name']}'
                                          : ''),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800))),
                          Text(niceDate('${e['date']}'),
                              style: const TextStyle(
                                  color: Colors.black54, fontSize: 12))
                        ]),
                        const SizedBox(height: 8),
                        Wrap(children: [
                          if (e['quantity'] != null)
                            Tile('Quantity', kg(e['quantity'])),
                          if (e['rate'] != null) Tile('Rate', inr(e['rate'])),
                          Tile('Amount', inr(e['amount'])),
                          if (e['paid_now'] != null)
                            Tile('Paid now', inr(e['paid_now'])),
                          if (e['due_created'] != null)
                            Tile('Due', inr(e['due_created']), col: coral),
                          if (e['payment_mode'] != null)
                            Tile('Mode', '${e['payment_mode']}'.toUpperCase()),
                          Tile('Change', inr(e['balance_change']), col: teal),
                          Tile('Balance', inr(e['running_balance']), col: ocean)
                        ])
                      ]))
              ])));
}

class MonthSheet extends StatefulWidget {
  final int id;
  const MonthSheet({super.key, required this.id});
  @override
  State<MonthSheet> createState() => _MoS();
}

class _MoS extends State<MonthSheet> {
  DateTime m = DateTime(DateTime.now().year, DateTime.now().month);
  @override
  Widget build(BuildContext c) =>
      Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () =>
                  setState(() => m = DateTime(m.year, m.month - 1))),
          Expanded(
              child: Center(
                  child: Text('${m.month}/${m.year}',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800)))),
          IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () =>
                  setState(() => m = DateTime(m.year, m.month + 1)))
        ]),
        SizedBox(
            height: 220,
            child: Fut(
                key: ValueKey(m),
                load: () => Api.req('GET',
                    '/api/v1/accounts/hotels/${widget.id}/monthly-summary',
                    q: {'year': '${m.year}', 'month': '${m.month}'}),
                build: (c, d, re) => Column(children: [
                      Inner(Row(children: [
                        Mini('Opening', inr(d['opening_outstanding'])),
                        Mini('Fish taken', inr(d['fish_taken']))
                      ])),
                      Inner(Row(children: [
                        Mini('Payments', inr(d['payments_received']),
                            col: teal),
                        Mini('Closing', inr(d['closing_outstanding']),
                            col: coral)
                      ]))
                    ])))
      ]);
}

class PaySheet extends StatefulWidget {
  final bool hotel;
  const PaySheet({super.key, required this.hotel});
  @override
  State<PaySheet> createState() => _PS();
}

class _PS extends State<PaySheet> {
  List parties = [];
  int? p;
  String mode = 'cash';
  DateTime? dt;
  final a = TextEditingController();
  @override
  void initState() {
    super.initState();
    fetch(widget.hotel ? '/api/v1/hotels' : '/api/v1/suppliers')
        .then((l) => setState(() => parties = l));
  }

  Future<void> save() async {
    if (p == null || n(a.text) <= 0) {
      toast(context, 'Select party and amount');
      return;
    }
    try {
      await Api.req('POST',
          widget.hotel ? '/api/v1/hotel-payments' : '/api/v1/supplier-payments',
          body: {
            widget.hotel ? 'hotel_id' : 'supplier_id': p,
            'amount': n(a.text),
            'payment_mode': mode,
            if (dt != null) 'payment_date': isoDate(dt!)
          });
      if (mounted) {
        Navigator.pop(context);
        toast(context, 'Payment recorded');
      }
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    }
  }

  @override
  Widget build(BuildContext c) =>
      Column(mainAxisSize: MainAxisSize.min, children: [
        Text(
            widget.hotel
                ? 'Payment received from hotel'
                : 'Payment to supplier',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 14),
        drop(widget.hotel ? 'Hotel' : 'Supplier', p, parties,
            (v) => setState(() => p = v)),
        const SizedBox(height: 12),
        numField(a, 'Amount (₹)'),
        const SizedBox(height: 12),
        SegmentedButton<String>(segments: const [
          ButtonSegment(
              value: 'cash', label: Text('Cash'), icon: Icon(Icons.payments)),
          ButtonSegment(
              value: 'upi', label: Text('UPI'), icon: Icon(Icons.qr_code))
        ], selected: {
          mode
        }, onSelectionChanged: (s) => setState(() => mode = s.first)),
        const SizedBox(height: 12),
        OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50)),
            icon: const Icon(Icons.event),
            label: Text(
                dt == null ? 'Date: Today' : 'Date: ${niceDate(isoDate(dt!))}'),
            onPressed: () async {
              final x = await showDatePicker(
                  context: c,
                  initialDate: dt ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now());
              if (x != null) setState(() => dt = x);
            }),
        const SizedBox(height: 16),
        FilledButton(onPressed: save, child: const Text('Save payment'))
      ]);
}
