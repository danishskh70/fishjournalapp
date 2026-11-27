import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/page_physics.dart';
import '../core/ui.dart';
import 'pay.dart';

class AccountsPage extends StatefulWidget {
  const AccountsPage({super.key});

  @override
  State<AccountsPage> createState() => _AP();
}

class _AP extends State<AccountsPage> {
  int v = 0;
  late final PageController _accountsController;

  @override
  void initState() {
    super.initState();
    _accountsController = PageController(initialPage: accTab.value);
    accTab.addListener(_onAccountTabChanged);
  }

  void _onAccountTabChanged() {
    if (!_accountsController.hasClients) return;

    final target = accTab.value;
    final current =
        _accountsController.page ?? _accountsController.initialPage.toDouble();

    if (current.round() == target) return;

    _accountsController.animateToPage(
      target,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  void _onAccountPageChanged(int index) {
    if (accTab.value != index) {
      accTab.value = index;
    }
  }

  @override
  void dispose() {
    accTab.removeListener(_onAccountTabChanged);
    _accountsController.dispose();
    super.dispose();
  }

  Future<void> pay(bool hotel, {int? id}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PayScreen(hotel: hotel, partyId: id),
      ),
    );
    if (mounted) setState(() => v++);
  }

  Widget _accountList(bool hotel) {
    return Fut(
      key: ValueKey('${hotel ? 'hotels' : 'suppliers'}-$v'),
      cacheKey: 'accounts:${hotel ? 'hotels' : 'suppliers'}',
      load: () => fetch(
        hotel ? '/api/v1/accounts/hotels' : '/api/v1/accounts/suppliers',
      ),
      build: (c, data, re) {
        final l = List.of(data as List)
          ..sort(
            (a, b) => nz(b['outstanding']).compareTo(nz(a['outstanding'])),
          );
        final totalAmt = sum(l, 'outstanding');

        return RefreshIndicator(
          onRefresh: re,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              Grad(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hotel ? 'Hotels owe you' : 'You owe suppliers',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      inr(totalAmt),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (l.isEmpty)
                EmptyNote(
                  hotel
                      ? 'No hotels yet. Add in Settings.'
                      : 'No suppliers yet. Add in Settings.',
                ),
              for (final x in l)
                Panel(
                  onTap: () async {
                    await Navigator.push(
                      c,
                      MaterialPageRoute(
                        builder: (_) => LedgerPage(
                          hotel: hotel,
                          id: x['id'] as int,
                          name: '${x['name']}',
                        ),
                      ),
                    );
                    if (mounted) setState(() => v++);
                  },
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: tint(hotel ? teal : coral),
                        child: Icon(
                          hotel ? Icons.hotel : Icons.local_shipping,
                          color: hotel ? teal : coral,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${x['name']}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 17,
                          ),
                        ),
                      ),
                      Text(
                        nz(x['outstanding']) > 0
                            ? inr(x['outstanding'])
                            : 'Clear',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: nz(x['outstanding']) > 0
                              ? (hotel ? teal : coral)
                              : Colors.black54,
                        ),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext c) => ValueListenableBuilder<int>(
        valueListenable: accTab,
        builder: (c, t, _) {
          final hotel = t == 0;

          return Scaffold(
            backgroundColor: Colors.transparent,
            floatingActionButton: FloatingActionButton.extended(
              onPressed: () => pay(hotel),
              icon: const Icon(Icons.add),
              label: Text(hotel ? 'Hotel paid' : 'Pay supplier'),
            ),
            body: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Accounts',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(
                        value: 0,
                        label: Text('Hotels'),
                        icon: Icon(Icons.hotel),
                      ),
                      ButtonSegment(
                        value: 1,
                        label: Text('Suppliers'),
                        icon: Icon(Icons.local_shipping),
                      ),
                    ],
                    selected: {t},
                    onSelectionChanged: (s) => accTab.value = s.first,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: PageView(
                    controller: _accountsController,
                    physics: const OnePageScrollPhysics(),
                    onPageChanged: _onAccountPageChanged,
                    children: [
                      _accountList(true),
                      _accountList(false),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );
}

class LedgerPage extends StatefulWidget {
  final bool hotel;
  final int id;
  final String name;
  const LedgerPage(
      {super.key, required this.hotel, required this.id, required this.name});
  @override
  State<LedgerPage> createState() => _LP();
}

class _LP extends State<LedgerPage> {
  DateTimeRange? r;
  int v = 0;
  String get base =>
      '/api/v1/accounts/${widget.hotel ? 'hotels' : 'suppliers'}/${widget.id}';

  Future<void> pickRange() async {
    final now = DateTime.now();
    final x = await showDateRangePicker(
        context: context,
        firstDate: DateTime(now.year - 3),
        lastDate: now,
        initialDateRange: r);
    if (x != null) setState(() => r = x);
  }

  Future<void> pay() async {
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) =>
                PayScreen(hotel: widget.hotel, partyId: widget.id)));
    if (mounted) setState(() => v++);
  }

  Future<void> month() async {
    final now = DateTime.now();
    await sheet<void>(
        context,
        MonthSheet(
            hotelId: widget.id,
            name: widget.name,
            year: now.year,
            month: now.month));
  }

  static const red = Color(0xFFB91C1C), green = Color(0xFF15803D);

  String get owesLabel => widget.hotel ? 'Owes' : 'You owe';

  bool isPay(Map e) =>
      '${e['entry_type']}'.toLowerCase().contains('payment') ||
      e['fish_name'] == null;

  String dayLabel(String k) {
    final now = DateTime.now();
    if (k == isoDate(now)) return 'Today';
    if (k == isoDate(now.subtract(const Duration(days: 1)))) return 'Yesterday';
    return shortDate(k);
  }

  Widget avatar(IconData i, Color c) =>
      CircleAvatar(backgroundColor: tint(c, 30), child: Icon(i, color: c));

  Widget right(String amt, Color? col, String sub) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(amt,
                style: TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 16, color: col)),
            const SizedBox(height: 2),
            Text(sub,
                style: const TextStyle(color: Colors.black54, fontSize: 12)),
          ]);

  Widget line(String l, String v, {Color? col, bool bold = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Expanded(
            child: Text(l,
                style: TextStyle(
                    fontWeight: bold ? FontWeight.w800 : FontWeight.w500))),
        Text(v,
            style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: bold ? 16 : 14,
                color: col)),
      ]));

  /// Money in (hotel paid you, green) or money out (you paid supplier, red).
  Widget payRow(Map e) {
    final inn = widget.hotel;
    final col = green;
    final mode = '${e['payment_mode'] ?? ''}'.toUpperCase();
    return ListTile(
        leading: avatar(inn ? Icons.arrow_downward : Icons.arrow_upward, col),
        title: Text(inn ? 'Received' : 'Paid',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(mode.isEmpty ? 'Payment' : mode),
        trailing: right(
            inr(e['amount']), col, '$owesLabel ${inr(e['running_balance'])}'));
  }

  /// Fish bought (supplier) or fish sold (hotel). Tap to open details.
  Widget billRow(List<Map> fs) {
    final bill = sum(fs, 'amount');
    final paid = widget.hotel ? 0 : sum(fs, 'paid_now');
    final pend = sum(fs, 'due_created');
    final names = <String>[];
    for (final e in fs) {
      final n = '${e['fish_name']}';
      if (!names.contains(n)) names.add(n);
    }
    final moved = paid > 0;
    return ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        leading: avatar(Icons.set_meal, red),
        title: Text(widget.hotel ? 'Fish sold' : 'Fish bought',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
            '${names.join(', ')} \u2022 ${qty(sum(fs, 'quantity'))} kg',
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        trailing: right(
            inr(bill), red, '$owesLabel ${inr(fs.last['running_balance'])}'),
        children: [
          for (final e in fs)
            line(
                '${e['fish_name']}  ${qty(e['quantity'])} kg \u00d7 ${inr(e['rate'])}',
                inr(e['amount'])),
          const Divider(height: 16, color: Colors.black12),
          line(widget.hotel ? 'Sale total' : 'Bill', inr(bill)),
          if (!widget.hotel)
            line('Paid now', inr(paid), col: moved ? green : null),
          if (!widget.hotel) line('Pending from this bill', inr(pend)),
          line('$owesLabel now', inr(fs.last['running_balance']), bold: true),
        ]);
  }

  Widget dayBlock(String k, List es) {
    final rows = <Widget>[];
    var fs = <Map>[];
    void flush() {
      if (fs.isNotEmpty) {
        rows.add(billRow(List<Map>.of(fs)));
        fs = <Map>[];
      }
    }

    for (final e in es) {
      final m = e as Map;
      if (isPay(m)) {
        flush();
        rows.add(payRow(m));
      } else {
        fs.add(m);
      }
    }
    flush();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
          padding: const EdgeInsets.fromLTRB(4, 10, 0, 6),
          child: Text(dayLabel(k),
              style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: Colors.black54))),
      Panel(
          pad: EdgeInsets.zero,
          child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Theme(
                  data: Theme.of(context)
                      .copyWith(dividerColor: Colors.transparent),
                  child: Column(children: [
                    for (var i = 0; i < rows.length; i++) ...[
                      if (i > 0)
                        const Divider(
                            height: 1, indent: 72, color: Colors.black12),
                      rows[i],
                    ]
                  ])))),
    ]);
  }

  @override
  Widget build(BuildContext c) => Scaffold(
      appBar: AppBar(title: Text(widget.name), actions: [
        IconButton(
            tooltip: 'Choose dates',
            icon: const Icon(Icons.date_range),
            onPressed: pickRange),
        if (widget.hotel)
          IconButton(
              tooltip: 'Month summary',
              icon: const Icon(Icons.calendar_month),
              onPressed: month),
      ]),
      body: Fut(
          key: ValueKey('${r?.start}-${r?.end}-$v'),
          cacheKey:
              'ledger:${widget.hotel ? 'hotel' : 'supplier'}:${widget.id}:${r == null ? 'all' : '${isoDate(r!.start)}-${isoDate(r!.end)}'}',
          load: () => Api.req('GET', '$base/ledger', q: {
                if (r != null) 'from_date': isoDate(r!.start),
                if (r != null) 'to_date': isoDate(r!.end)
              }),
          build: (c, d, re) {
            final es = L(d['entries']);
            final g = <String, List>{};
            for (final e in es) {
              g.putIfAbsent('${e['date']}', () => []).add(e);
            }
            final keys = g.keys.toList().reversed.toList();
            return ListView(padding: const EdgeInsets.all(16), children: [
              Grad(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(widget.hotel ? 'Owes you' : 'You owe',
                        style: const TextStyle(color: Colors.white70)),
                    Text(inr(d['closing_balance']),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(
                        'Balance before this list: ${inr(d['previous_balance'])}',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 14),
                    FilledButton(
                        style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: ocean),
                        onPressed: pay,
                        child:
                            Text(widget.hotel ? 'Hotel paid' : 'Pay supplier')),
                  ])),
              const SizedBox(height: 14),
              if (r != null)
                Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                        'Showing ${niceDate(isoDate(r!.start))} to ${niceDate(isoDate(r!.end))}',
                        style: const TextStyle(color: Colors.black54))),
              const Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Text('Tap a fish entry to see the details',
                      style: TextStyle(color: Colors.black54, fontSize: 12))),
              if (es.isEmpty) const EmptyNote('No entries yet.'),
              for (final k in keys) dayBlock(k, g[k]!),
            ]);
          }));
}

class MonthSheet extends StatefulWidget {
  final int hotelId, year, month;
  final String name;
  const MonthSheet(
      {super.key,
      required this.hotelId,
      required this.name,
      required this.year,
      required this.month});
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
  Widget build(BuildContext c) =>
      Column(mainAxisSize: MainAxisSize.min, children: [
        Text(widget.name,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton(
              tooltip: 'Previous month',
              icon: const Icon(Icons.chevron_left),
              onPressed: () => step(-1)),
          Text(
              '${[
                'Jan',
                'Feb',
                'Mar',
                'Apr',
                'May',
                'Jun',
                'Jul',
                'Aug',
                'Sep',
                'Oct',
                'Nov',
                'Dec'
              ][m - 1]} $y',
              style:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          IconButton(
              tooltip: 'Next month',
              icon: const Icon(Icons.chevron_right),
              onPressed: () => step(1)),
        ]),
        SizedBox(
            height: 200,
            child: Fut(
                key: ValueKey('$y-$m'),
                cacheKey: 'hotel-monthly:${widget.hotelId}:$y-$m',
                load: () => Api.req('GET',
                    '/api/v1/accounts/hotels/${widget.hotelId}/monthly-summary',
                    q: {'year': '$y', 'month': '$m'}),
                build: (c, d, re) => Column(children: [
                      tbl([
                        'Month summary',
                        'Amount'
                      ], [
                        ['Pending at start', inr(d['opening_outstanding'])],
                        ['Fish taken', inr(d['fish_taken'])],
                        ['Payments received', inr(d['payments_received'])],
                      ], foot: [
                        'Pending at end',
                        inr(d['closing_outstanding'])
                      ], flex: [
                        3,
                        2
                      ]),
                    ]))),
      ]);
}
