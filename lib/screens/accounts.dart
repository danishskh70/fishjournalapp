import 'package:material_ui/material_ui.dart';
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
              if (l.isEmpty) {
                return const Center(child: Text('No accounts yet'));
              }
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
                                    backgroundColor: (hotel ? teal : coral)
                                        .withValues(alpha: 0.1),
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
                if (d is Map)
                  Grad(
                      child: Column(children: [
                    for (final k in ['previous_balance', 'closing_balance'])
                      if (d[k] != null)
                        Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(label(k),
                                  style:
                                      const TextStyle(color: Colors.white70)),
                              Text(inr(d[k]),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 18))
                            ])
                  ])),
                const SizedBox(height: 12),
                for (final e in asList(d))
                  Panel(
                      child: Row(children: [
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(
                              label('${pick(e, ['entry_type', 'type']) ?? ''}'),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                          Text(
                              '${niceDate('${pick(e, [
                                    'date',
                                    'entry_date'
                                  ])}')} ${pick(e, ['fish_name']) ?? ''}',
                              style: const TextStyle(
                                  color: Colors.black54, fontSize: 12))
                        ])),
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(inr(pick(e, ['amount'])),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                          Text(
                              'Bal ${inr(pick(e, [
                                    'running_balance',
                                    'balance'
                                  ]))}',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.black54))
                        ])
                  ]))
              ])));
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
            'payment_mode': mode
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
        const SizedBox(height: 16),
        FilledButton(onPressed: save, child: const Text('Save payment'))
      ]);
}
