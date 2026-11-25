import 'package:material_ui/material_ui.dart';
import 'package:decimal/decimal.dart';
import '../core/api.dart';
import '../core/ui.dart';

Decimal d(String s) => Decimal.tryParse(s.trim()) ?? Decimal.zero;
num n(String s) => num.tryParse(s.trim()) ?? 0;

class JournalPage extends StatefulWidget {
  final DateTime date;
  const JournalPage({super.key, required this.date});
  @override
  State<JournalPage> createState() => _JS();
}

class _JS extends State<JournalPage> {
  Map? j;
  bool busy = true;
  String? err;
  int v = 0;
  String get ds => isoDate(widget.date);
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
    if (mounted) {
      setState(() {
        busy = false;
        v++;
      });
    }
  }

  Future<void> start() async {
    try {
      await Api.req('POST', '/api/v1/journals', body: {'business_date': ds});
      await load();
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    }
  }

  @override
  Widget build(BuildContext c) {
    if (busy) return const Center(child: CircularProgressIndicator());
    if (err != null) {
      return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(err!),
        const SizedBox(height: 12),
        FilledButton(onPressed: load, child: const Text('Retry'))
      ]));
    }
    if (j == null) {
      return Center(
          child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.menu_book, size: 64, color: teal),
                const SizedBox(height: 12),
                Text('No journal for ${niceDate(ds)}',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                FilledButton(
                    onPressed: start, child: const Text('Start daily journal'))
              ])));
    }
    final closed = '${j!['status']}' == 'closed';
    final jid = j!['id'] as int;
    return DefaultTabController(
        length: 4,
        child: Column(children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Grad(
                  child: Row(children: [
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(niceDate(ds),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700)),
                      Text(closed ? 'Closed (read-only)' : 'Open',
                          style: const TextStyle(color: Colors.white70))
                    ])),
                Icon(closed ? Icons.lock : Icons.edit_note, color: Colors.white)
              ]))),
          const TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(text: 'Opening'),
                Tab(text: 'Purchases'),
                Tab(text: 'Hotel sales'),
                Tab(text: 'Close')
              ]),
          Expanded(
              child: TabBarView(key: ValueKey(v), children: [
            OpeningTab(j: j!, ro: closed, done: load),
            TxTab(
                path: '/api/v1/purchases',
                jid: jid,
                ro: closed,
                done: load,
                sale: false),
            TxTab(
                path: '/api/v1/hotel-sales',
                jid: jid,
                ro: closed,
                done: load,
                sale: true),
            CloseTab(jid: jid, closed: closed, j: j!, done: load)
          ]))
        ]));
  }
}

class OpeningTab extends StatefulWidget {
  final Map j;
  final bool ro;
  final VoidCallback done;
  const OpeningTab(
      {super.key, required this.j, required this.ro, required this.done});
  @override
  State<OpeningTab> createState() => _OS();
}

class _OS extends State<OpeningTab> {
  List fish = [];
  final cs = <int, TextEditingController>{};
  final prev = <int, dynamic>{};
  bool ok = false;
  @override
  void initState() {
    super.initState();
    init();
  }

  Future<void> init() async {
    fish = await fetch('/api/v1/fish');
    final items = asList(widget.j['opening_stock'] ??
        widget.j['opening_stocks'] ??
        widget.j['opening'] ??
        widget.j['stock']);
    for (final f in fish) {
      final it = items.cast<dynamic>().firstWhere(
          (e) => e is Map && e['fish_id'] == f['id'],
          orElse: () => null);
      prev[f['id']] = pick(it, [
        'previous_closing',
        'previous_closing_quantity',
        'previous_closing_stock'
      ]);
      cs[f['id']] = TextEditingController(
          text: '${pick(it, [
                    'quantity',
                    'confirmed_quantity',
                    'opening_quantity',
                    'suggested_quantity',
                    'suggested_opening_quantity'
                  ]) ?? 0}');
    }
    if (mounted) setState(() => ok = true);
  }

  Future<void> save() async {
    try {
      await Api.req('PUT', '/api/v1/journals/${widget.j['id']}/opening-stock',
          body: {
            'items': [
              for (final f in fish)
                {'fish_id': f['id'], 'quantity': n(cs[f['id']]!.text)}
            ]
          });
      if (mounted) toast(context, 'Opening stock confirmed');
      widget.done();
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    }
  }

  @override
  Widget build(BuildContext c) {
    if (!ok) return const Center(child: CircularProgressIndicator());
    return ListView(padding: const EdgeInsets.all(16), children: [
      const Text('Check the real stock in the shop, then confirm.',
          style: TextStyle(color: Colors.black54)),
      const SizedBox(height: 12),
      for (final f in fish)
        Panel(
            child: Row(children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('${f['name']}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 16)),
                Text('Yesterday closing: ${kg(prev[f['id']])}',
                    style: const TextStyle(color: Colors.black54, fontSize: 12))
              ])),
          SizedBox(
              width: 120,
              child: widget.ro
                  ? Text(cs[f['id']]!.text)
                  : numField(cs[f['id']]!, 'kg'))
        ])),
      if (!widget.ro)
        FilledButton(
            onPressed: save, child: const Text('Confirm opening stock'))
    ]);
  }
}

class TxTab extends StatelessWidget {
  final String path;
  final int jid;
  final bool ro, sale;
  final VoidCallback done;
  const TxTab(
      {super.key,
      required this.path,
      required this.jid,
      required this.ro,
      required this.done,
      required this.sale});
  @override
  Widget build(BuildContext c) => Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: ro
          ? null
          : FloatingActionButton.extended(
              backgroundColor: ocean,
              foregroundColor: Colors.white,
              onPressed: () async {
                if (await sheet<bool>(c, TxForm(jid: jid, sale: sale)) ==
                    true) {
                  done();
                }
              },
              icon: const Icon(Icons.add),
              label: Text(sale ? 'Add sale' : 'Add purchase')),
      body: Fut(
          load: () => fetch(path, q: {'journal_id': '$jid'}),
          build: (c, data, re) {
            final l = data as List;
            if (l.isEmpty) {
              return Center(
                  child:
                      Text(sale ? 'No hotel sales yet' : 'No purchases yet'));
            }
            return ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                children: [
                  for (final e in l)
                    Panel(
                        child: Row(children: [
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(
                                '${pick(e, [
                                          sale ? 'hotel_name' : 'supplier_name',
                                          'name'
                                        ]) ?? ''} • ${pick(e, ['fish_name']) ?? ''}',
                                style: const TextStyle(fontWeight: FontWeight.w700)),
                            Text('${kg(e['quantity'])} × ${inr(e['rate'])}'),
                            if (!sale)
                              Text(
                                  'Paid ${inr(e['paid_now'])} • Due ${inr(pick(e, [
                                        'due_created',
                                        'due'
                                      ]))}',
                                  style: const TextStyle(color: coral))
                          ])),
                      Text(inr(pick(e, ['amount', 'total_amount'])),
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 16)),
                      if (!ro)
                        IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () async {
                              if (!await confirm(c, 'Delete this entry?')) {
                                return;
                              }
                              try {
                                await Api.req('DELETE', '$path/${e['id']}');
                                done();
                              } on ApiException catch (x) {
                                if (c.mounted) toast(c, x.message);
                              }
                            })
                    ]))
                ]);
          }));
}

class TxForm extends StatefulWidget {
  final int jid;
  final bool sale;
  const TxForm({super.key, required this.jid, required this.sale});
  @override
  State<TxForm> createState() => _TF();
}

class _TF extends State<TxForm> {
  List parties = [], fish = [];
  int? p, f;
  String mode = 'cash';
  String? saved;
  final q = TextEditingController(),
      r = TextEditingController(),
      paid = TextEditingController(text: '0');
  @override
  void initState() {
    super.initState();
    Future.wait([
      fetch(widget.sale ? '/api/v1/hotels' : '/api/v1/suppliers'),
      fetch('/api/v1/fish')
    ])
        .then((x) => setState(() {
              parties = x[0];
              fish = x[1];
            }))
        .catchError((e) {
      if (mounted) toast(context, '$e');
    });
  }

  Future<void> rate() async {
    if (!widget.sale || p == null || f == null) return;
    try {
      final l = await fetch('/api/v1/hotels/$p/rates');
      final m = l
          .cast<dynamic>()
          .firstWhere((e) => e['fish_id'] == f, orElse: () => null);
      saved = m == null ? null : '${m['rate']}';
      setState(() => r.text = saved ?? '');
    } catch (_) {}
  }

  Future<void> submit() async {
    if (p == null ||
        f == null ||
        d(q.text) <= Decimal.zero ||
        (!widget.sale || true) && r.text.trim().isEmpty && !widget.sale) {
      toast(context, 'Fill all fields');
      return;
    }
    final body = widget.sale
        ? {
            'hotel_id': p,
            'fish_id': f,
            'quantity': n(q.text),
            'journal_id': widget.jid,
            if (r.text.isNotEmpty && r.text != saved) 'rate': n(r.text)
          }
        : {
            'journal_id': widget.jid,
            'supplier_id': p,
            'fish_id': f,
            'quantity': n(q.text),
            'rate': n(r.text),
            'paid_now': n(paid.text),
            'payment_mode': mode
          };
    try {
      await Api.req(
          'POST', widget.sale ? '/api/v1/hotel-sales' : '/api/v1/purchases',
          body: body);
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    }
  }

  @override
  Widget build(BuildContext c) {
    final amt = d(q.text) * d(r.text);
    final due = amt - d(paid.text);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text(widget.sale ? 'Hotel sale' : 'New purchase',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
      const SizedBox(height: 14),
      drop(widget.sale ? 'Hotel' : 'Supplier', p, parties, (v) {
        setState(() => p = v);
        rate();
      }),
      const SizedBox(height: 12),
      drop('Fish', f, fish, (v) {
        setState(() => f = v);
        rate();
      }),
      const SizedBox(height: 12),
      numField(q, 'Quantity (kg)', onChanged: (_) => setState(() {})),
      const SizedBox(height: 12),
      numField(r, 'Rate per kg (₹)', onChanged: (_) => setState(() {})),
      const SizedBox(height: 12),
      if (!widget.sale) ...[
        numField(paid, 'Paid now (₹)', onChanged: (_) => setState(() {})),
        const SizedBox(height: 12),
        SegmentedButton<String>(segments: const [
          ButtonSegment(
              value: 'cash', label: Text('Cash'), icon: Icon(Icons.payments)),
          ButtonSegment(
              value: 'upi', label: Text('UPI'), icon: Icon(Icons.qr_code))
        ], selected: {
          mode
        }, onSelectionChanged: (s) => setState(() => mode = s.first)),
        const SizedBox(height: 12)
      ],
      Panel(
          child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Amount'),
          Text('₹$amt',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18))
        ]),
        if (!widget.sale)
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Due'),
            Text('₹$due',
                style:
                    const TextStyle(color: coral, fontWeight: FontWeight.w700))
          ])
      ])),
      FilledButton(onPressed: submit, child: const Text('Save'))
    ]);
  }
}

class CloseTab extends StatefulWidget {
  final int jid;
  final bool closed;
  final Map j;
  final VoidCallback done;
  const CloseTab(
      {super.key,
      required this.jid,
      required this.closed,
      required this.j,
      required this.done});
  @override
  State<CloseTab> createState() => _CS();
}

class _CS extends State<CloseTab> {
  List fish = [];
  final cs = <int, TextEditingController>{};
  final cash = TextEditingController(), upi = TextEditingController();
  Map? prev;
  Map<String, dynamic>? body;
  @override
  void initState() {
    super.initState();
    fetch('/api/v1/fish').then((l) => setState(() {
          fish = l;
          for (final f in l) {
            cs[f['id']] = TextEditingController();
          }
        }));
  }

  Map<String, dynamic> build_() => {
        'stocks': [
          for (final f in fish)
            {'fish_id': f['id'], 'quantity': n(cs[f['id']]!.text)}
        ],
        'cash_amount': n(cash.text),
        'upi_amount': n(upi.text)
      };
  Future<void> preview() async {
    final b = build_();
    try {
      final r = await Api.req(
          'POST', '/api/v1/journals/${widget.jid}/close-preview',
          body: b);
      setState(() {
        prev = r;
        body = b;
      });
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    }
  }

  Future<void> close() async {
    if (!await confirm(context, 'Close this journal? It becomes read-only.')) {
      return;
    }
    try {
      await Api.req('POST', '/api/v1/journals/${widget.jid}/close', body: body);
      widget.done();
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    }
  }

  @override
  Widget build(BuildContext c) {
    if (widget.closed) {
      return ListView(
          padding: const EdgeInsets.all(16),
          children: [Panel(child: KV(widget.j))]);
    }
    final can = prev != null && prev!['can_close'] == true;
    return ListView(padding: const EdgeInsets.all(16), children: [
      const Text('Remaining stock in the shop',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
      const SizedBox(height: 8),
      for (final f in fish)
        Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: numField(cs[f['id']]!, '${f['name']} (kg)',
                onChanged: (_) => setState(() => prev = null))),
      numField(cash, 'Cash collected (₹)',
          onChanged: (_) => setState(() => prev = null)),
      const SizedBox(height: 10),
      numField(upi, 'UPI collected (₹)',
          onChanged: (_) => setState(() => prev = null)),
      const SizedBox(height: 14),
      FilledButton.tonal(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
          onPressed: preview,
          child: const Text('Preview closing')),
      if (prev != null) ...[
        const SizedBox(height: 14),
        Panel(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          KV(prev!),
          for (final e in prev!.values.whereType<List>())
            for (final it in e) ...[
              const Divider(),
              it is Map
                  ? KV(it)
                  : Text('$it', style: const TextStyle(color: coral))
            ]
        ])),
        FilledButton(
            onPressed: can ? close : null, child: const Text('Close journal'))
      ]
    ]);
  }
}
