import 'package:flutter/material.dart';
import 'package:decimal/decimal.dart';
import '../core/api.dart';
import '../core/ui.dart';
import 'day.dart';

Decimal d(String s) => Decimal.tryParse(s.trim()) ?? Decimal.zero;
num n(String s) => num.tryParse(s.trim()) ?? 0;
num num0(dynamic v) => num.tryParse('${v ?? 0}') ?? 0;
List L(dynamic x) => x is List ? x : [];
List stockRows(Map j) => L((j['stock'] as Map?)?['rows']);
bool openingDone(Map j) =>
    stockRows(j).any((r) => r['opening_confirmed'] == true) ||
    '${j['status']}' == 'closed';

class OpeningScreen extends StatefulWidget {
  final Map j;
  const OpeningScreen({super.key, required this.j});
  @override
  State<OpeningScreen> createState() => _OSt();
}

class _OSt extends State<OpeningScreen> {
  List fish = [];
  final cs = <int, TextEditingController>{};
  final prev = <int, String>{};
  final sel = <int>[];
  bool ok = false;
  @override
  void initState() {
    super.initState();
    init();
  }

  Future<void> init() async {
    fish = await fetch('/api/v1/fish');
    final rows = stockRows(widget.j);
    for (final f in fish) {
      final id = f['id'] as int;
      final r = rows
          .cast<dynamic>()
          .firstWhere((x) => x['fish_id'] == id, orElse: () => null);
      final q = r == null
          ? 0
          : num0(r['opening_confirmed'] == true
              ? r['opening_quantity']
              : r['suggested_opening']);
      cs[id] = TextEditingController(text: q > 0 ? '$q' : '');
      prev[id] = '${r?['previous_closing'] ?? 0}';
      if (q > 0) sel.add(id);
    }
    if (mounted) setState(() => ok = true);
  }

  String nm(int id) => '${fish.firstWhere((f) => f['id'] == id)['name']}';
  Future<void> add() async {
    final q = TextEditingController();
    final id = await showModalBottomSheet<int>(
        context: context,
        isScrollControlled: true,
        backgroundColor: const Color(0xFFF3F6FA),
        builder: (c) => StatefulBuilder(
            builder: (c, st) => Padding(
                padding: EdgeInsets.fromLTRB(
                    16, 16, 16, MediaQuery.of(c).viewInsets.bottom + 16),
                child: SingleChildScrollView(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(
                      controller: q,
                      onChanged: (_) => st(() {}),
                      decoration: const InputDecoration(
                          labelText: 'Search fish',
                          prefixIcon: Icon(Icons.search))),
                  const SizedBox(height: 12),
                  for (final f in fish.where((f) =>
                      !sel.contains(f['id']) &&
                      '${f['name']}'
                          .toLowerCase()
                          .contains(q.text.toLowerCase())))
                    Panel(
                        onTap: () => Navigator.pop(c, f['id'] as int),
                        child: Row(children: [
                          const Icon(Icons.set_meal, color: teal),
                          const SizedBox(width: 12),
                          Text('${f['name']}',
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600))
                        ]))
                ])))));
    if (id != null) setState(() => sel.add(id));
  }

  Future<void> save() async {
    try {
      await Api.req('PUT', '/api/v1/journals/${widget.j['id']}/opening-stock',
          body: {
            'items': [
              for (final f in fish)
                {
                  'fish_id': f['id'],
                  'quantity': sel.contains(f['id']) ? n(cs[f['id']]!.text) : 0
                }
            ]
          });
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
      appBar: AppBar(title: const Text('Opening stock')),
      body: !ok
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(16), children: [
              const Text(
                  "Select today's fish and enter the kg you really have.",
                  style: TextStyle(color: Colors.black54)),
              const SizedBox(height: 12),
              for (final id in sel)
                Panel(
                    child: Column(children: [
                  Row(children: [
                    const Icon(Icons.set_meal, color: teal),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(nm(id),
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 17))),
                    IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() => sel.remove(id)))
                  ]),
                  Row(children: [
                    Expanded(
                        child: Tile('Yesterday closing', kg(prev[id]),
                            col: Colors.black54)),
                    SizedBox(width: 130, child: numField(cs[id]!, 'Today kg'))
                  ])
                ])),
              OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(54)),
                  onPressed: add,
                  icon: const Icon(Icons.add),
                  label: const Text('Add fish')),
              const SizedBox(height: 12),
              FilledButton(
                  onPressed: sel.isEmpty ? null : save,
                  child: const Text('Confirm opening stock'))
            ]));
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
            if (n(paid.text) > 0) 'payment_mode': mode
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

class CloseScreen extends StatefulWidget {
  final Map j;
  const CloseScreen({super.key, required this.j});
  @override
  State<CloseScreen> createState() => _CS();
}

class _CS extends State<CloseScreen> {
  List fish = [];
  final cs = <int, TextEditingController>{};
  final cash = TextEditingController(), upi = TextEditingController();
  Map? prev;
  Map<String, dynamic>? body;
  late final Set<int> ids = {
    for (final r in stockRows(widget.j))
      if (num0(r['opening_quantity']) > 0 || num0(r['purchased']) > 0)
        r['fish_id'] as int
  };
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

  Map<String, dynamic> make() => {
        'stocks': [
          for (final f in fish)
            {
              'fish_id': f['id'],
              'quantity': ids.contains(f['id']) ? n(cs[f['id']]!.text) : 0
            }
        ],
        'cash_amount': n(cash.text),
        'upi_amount': n(upi.text)
      };
  Future<void> preview() async {
    final b = make();
    try {
      final r = await Api.req(
          'POST', '/api/v1/journals/${widget.j['id']}/close-preview',
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
    if (!await confirm(context, "Close today's business? It will be locked."))
      return;
    try {
      await Api.req('POST', '/api/v1/journals/${widget.j['id']}/close',
          body: body);
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    }
  }

  @override
  Widget build(BuildContext c) {
    final can = prev != null && prev!['can_close'] == true;
    void dirty(String _) => setState(() => prev = null);
    return Scaffold(
        appBar: AppBar(title: const Text('Close business')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          Panel(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Text('Fish left in the shop (kg)',
                    style:
                        TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 10),
                for (final f in fish.where((f) => ids.contains(f['id'])))
                  Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: numField(cs[f['id']]!, '${f['name']}',
                          onChanged: dirty))
              ])),
          Panel(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Text("Today's money",
                    style:
                        TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 10),
                numField(cash, 'Cash (₹)', onChanged: dirty),
                const SizedBox(height: 10),
                numField(upi, 'UPI (₹)', onChanged: dirty)
              ])),
          FilledButton.tonal(
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54)),
              onPressed: fish.isEmpty ? null : preview,
              child: const Text('Check before closing')),
          if (prev != null) ...[
            const SizedBox(height: 14),
            Panel(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(can ? 'Ready to close' : 'Cannot close yet',
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: can ? teal : coral)),
                  const SizedBox(height: 10),
                  for (final p in L(prev!['problems']))
                    Inner(Text('$p', style: const TextStyle(color: coral))),
                  for (final r in stockRows(prev!))
                    if (fishCard(r) != null) fishCard(r)!,
                  if (prev!['money'] is Map)
                    Inner(Row(children: [
                      Mini('Cash', inr(prev!['money']['cash_amount'])),
                      Mini('UPI', inr(prev!['money']['upi_amount'])),
                      Mini('Total', inr(prev!['money']['total']), col: teal)
                    ]))
                ])),
            FilledButton(
                onPressed: can ? close : null,
                child: const Text('Close business'))
          ]
        ]));
  }
}
