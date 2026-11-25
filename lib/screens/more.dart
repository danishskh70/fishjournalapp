import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/ui.dart';
import 'day.dart';
import 'journal.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});
  @override
  Widget build(BuildContext c) => Column(children: [
        const Padding(
            padding: EdgeInsets.all(16),
            child: Align(
                alignment: Alignment.centerLeft,
                child: Text('History',
                    style:
                        TextStyle(fontSize: 26, fontWeight: FontWeight.w800)))),
        Expanded(
            child: Fut(
                load: () =>
                    fetch('/api/v1/history', q: {'limit': '60', 'offset': '0'}),
                build: (c, data, re) {
                  final l = data as List;
                  if (l.isEmpty)
                    return const Center(child: Text('No previous journals'));
                  return ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        for (final e in l)
                          Panel(
                              onTap: () {
                                final dt = DateTime.tryParse(
                                    '${pick(e, ['business_date', 'date'])}');
                                if (dt != null)
                                  Navigator.push(
                                      c,
                                      MaterialPageRoute(
                                          builder: (_) => DayDetail(date: dt)));
                              },
                              child: Row(children: [
                                Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Text(
                                          niceDate('${pick(e, [
                                                'business_date',
                                                'date'
                                              ])}'),
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 16)),
                                      Text(
                                          'Cash ${inr(pick(e, [
                                                'cash_amount'
                                              ]))} • UPI ${inr(pick(e, [
                                                'upi_amount'
                                              ]))}',
                                          style: const TextStyle(
                                              color: Colors.black54,
                                              fontSize: 12))
                                    ])),
                                Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                          inr(pick(e, [
                                            'total_money',
                                            'total_amount',
                                            'total_collection',
                                            'total'
                                          ])),
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w800)),
                                      Text(label('${pick(e, ['status'])}'),
                                          style: TextStyle(
                                              color: '${pick(e, ['status'])}' ==
                                                      'closed'
                                                  ? Colors.black45
                                                  : teal,
                                              fontSize: 12))
                                    ])
                              ]))
                      ]);
                }))
      ]);
}

class SettingsPage extends StatelessWidget {
  final VoidCallback onLogout;
  const SettingsPage({super.key, required this.onLogout});
  @override
  Widget build(BuildContext c) =>
      ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Settings',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        for (final x in [
          ['Fish varieties', '/api/v1/fish', Icons.set_meal],
          ['Suppliers', '/api/v1/suppliers', Icons.local_shipping],
          ['Hotels', '/api/v1/hotels', Icons.hotel]
        ])
          Panel(
              onTap: () => Navigator.push(
                  c,
                  MaterialPageRoute(
                      builder: (_) => MasterPage(
                          title: x[0] as String, path: x[1] as String))),
              child: Row(children: [
                Icon(x[2] as IconData, color: ocean),
                const SizedBox(width: 14),
                Expanded(
                    child: Text(x[0] as String,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600))),
                const Icon(Icons.chevron_right)
              ])),
        for (final x in [
          ['Shop details', 'Shop name and business information', Icons.store],
          ['Rate history', 'When selling rates changed', Icons.price_change],
          [
            'App preferences',
            'Language (English / Hindi) and theme',
            Icons.tune
          ],
          ['Offline & sync', 'Pending entries and last sync', Icons.sync]
        ])
          Panel(
              onTap: () => Navigator.push(
                  c,
                  MaterialPageRoute(
                      builder: (_) => StubPage(
                          title: x[0] as String,
                          note: x[1] as String,
                          icon: x[2] as IconData))),
              child: Row(children: [
                Icon(x[2] as IconData, color: Colors.black45),
                const SizedBox(width: 14),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(x[0] as String,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                      Text(x[1] as String,
                          style: const TextStyle(
                              color: Colors.black54, fontSize: 12))
                    ])),
                Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: coral.withOpacity(.12),
                        borderRadius: BorderRadius.circular(20)),
                    child: const Text('Soon',
                        style: TextStyle(
                            color: coral,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)))
              ])),
        Panel(
            onTap: () => sheet(c, const PwSheet()),
            child: const Row(children: [
              Icon(Icons.lock_reset, color: ocean),
              SizedBox(width: 14),
              Text('Change password',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600))
            ])),
        Panel(
            onTap: () async {
              if (await confirm(c, 'Log out?')) onLogout();
            },
            child: const Row(children: [
              Icon(Icons.logout, color: coral),
              SizedBox(width: 14),
              Text('Log out',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600))
            ]))
      ]);
}

class MasterPage extends StatefulWidget {
  final String title, path;
  const MasterPage({super.key, required this.title, required this.path});
  @override
  State<MasterPage> createState() => _MS();
}

class _MS extends State<MasterPage> {
  bool inactive = false;
  int v = 0;
  bool get party => !widget.path.endsWith('/fish');
  Future<void> add() async {
    final t = TextEditingController(),
        ph = TextEditingController(),
        ob = TextEditingController();
    final ok = await sheet<bool>(
        context,
        Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Add ${widget.title}',
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          TextField(
              controller: t,
              decoration: const InputDecoration(labelText: 'Name')),
          const SizedBox(height: 12),
          if (party) ...[
            TextField(
                controller: ph,
                keyboardType: TextInputType.phone,
                decoration:
                    const InputDecoration(labelText: 'Phone (optional)')),
            const SizedBox(height: 12),
            numField(ob, 'Old balance already pending (₹, optional)'),
            const SizedBox(height: 12)
          ],
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'))
        ]));
    if (ok != true || t.text.trim().isEmpty) return;
    try {
      await Api.req('POST', widget.path, body: {
        'name': t.text.trim(),
        if (party && ph.text.isNotEmpty) 'phone': ph.text.trim(),
        if (party && n(ob.text) > 0) 'opening_balance': n(ob.text)
      });
      setState(() => v++);
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
      appBar: AppBar(title: Text(widget.title), actions: [
        Row(children: [
          const Text('Inactive'),
          Switch(
              value: inactive,
              onChanged: (x) => setState(() {
                    inactive = x;
                    v++;
                  }))
        ])
      ]),
      floatingActionButton: FloatingActionButton(
          backgroundColor: ocean,
          foregroundColor: Colors.white,
          onPressed: add,
          child: const Icon(Icons.add)),
      body: Fut(
          key: ValueKey(v),
          load: () =>
              fetch(widget.path, q: {if (inactive) 'include_inactive': 'true'}),
          build: (c, data, re) =>
              ListView(padding: const EdgeInsets.all(16), children: [
                for (final e in data as List)
                  Panel(
                      onTap: widget.path.endsWith('/hotels')
                          ? () => Navigator.push(
                              c,
                              MaterialPageRoute(
                                  builder: (_) => HotelRates(
                                      id: e['id'], name: '${e['name']}')))
                          : null,
                      child: Row(children: [
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text('${e['name']}',
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700)),
                              if (widget.path.endsWith('/hotels'))
                                const Text('Tap to set fish rates',
                                    style: TextStyle(
                                        color: Colors.black45, fontSize: 12))
                            ])),
                        Switch(
                            value: e['is_active'] != false,
                            onChanged: (x) async {
                              try {
                                await Api.req(
                                    'PATCH', '${widget.path}/${e['id']}',
                                    body: {'is_active': x});
                                setState(() => v++);
                              } on ApiException catch (er) {
                                if (c.mounted) toast(c, er.message);
                              }
                            })
                      ]))
              ])));
}

class HotelRates extends StatefulWidget {
  final int id;
  final String name;
  const HotelRates({super.key, required this.id, required this.name});
  @override
  State<HotelRates> createState() => _HR();
}

class _HR extends State<HotelRates> {
  List fish = [];
  final cs = <int, TextEditingController>{};
  final old = <int, String>{};
  bool ok = false;
  @override
  void initState() {
    super.initState();
    init();
  }

  Future<void> init() async {
    fish = await fetch('/api/v1/fish');
    final rates = await fetch('/api/v1/hotels/${widget.id}/rates');
    for (final f in fish) {
      final r = rates
          .cast<dynamic>()
          .firstWhere((x) => x['fish_id'] == f['id'], orElse: () => null);
      old[f['id']] = r == null ? '' : '${r['rate']}';
      cs[f['id']] = TextEditingController(text: old[f['id']]);
    }
    if (mounted) setState(() => ok = true);
  }

  Future<void> save() async {
    try {
      for (final f in fish) {
        final t = cs[f['id']]!.text.trim();
        if (t.isNotEmpty && t != old[f['id']] && n(t) > 0)
          await Api.req('PUT', '/api/v1/hotels/${widget.id}/rates/${f['id']}',
              body: {'rate': n(t)});
      }
      if (mounted) {
        toast(context, 'Rates saved');
        Navigator.pop(context);
      }
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
      appBar: AppBar(title: Text('${widget.name} rates')),
      body: !ok
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(16), children: [
              for (final f in fish)
                Panel(
                    child: Row(children: [
                  const Icon(Icons.set_meal, color: teal),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text('${f['name']}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 16))),
                  SizedBox(width: 120, child: numField(cs[f['id']]!, '₹/kg'))
                ])),
              FilledButton(onPressed: save, child: const Text('Save rates'))
            ]));
}

class PwSheet extends StatefulWidget {
  const PwSheet({super.key});
  @override
  State<PwSheet> createState() => _PW();
}

class _PW extends State<PwSheet> {
  final o = TextEditingController(), n_ = TextEditingController();
  Future<void> save() async {
    if (n_.text.length < 10) {
      toast(context, 'New password needs at least 10 characters');
      return;
    }
    try {
      await Api.req('POST', '/api/v1/auth/change-password',
          body: {'current_password': o.text, 'new_password': n_.text});
      if (mounted) {
        Navigator.pop(context);
        toast(context, 'Password changed');
      }
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    }
  }

  @override
  Widget build(BuildContext c) =>
      Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Change password',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 14),
        TextField(
            controller: o,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Current password')),
        const SizedBox(height: 12),
        TextField(
            controller: n_,
            obscureText: true,
            decoration: const InputDecoration(
                labelText: 'New password (10+ characters)')),
        const SizedBox(height: 16),
        FilledButton(onPressed: save, child: const Text('Update'))
      ]);
}

class StubPage extends StatelessWidget {
  final String title, note;
  final IconData icon;
  const StubPage(
      {super.key, required this.title, required this.note, required this.icon});
  @override
  Widget build(BuildContext c) => Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Padding(
          padding: const EdgeInsets.all(16),
          child: Panel(
              pad: const EdgeInsets.all(28),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, size: 56, color: teal),
                const SizedBox(height: 14),
                Text(title,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(note,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.black54)),
                const SizedBox(height: 14),
                const Text('Coming soon',
                    style: TextStyle(color: coral, fontWeight: FontWeight.w700))
              ]))));
}
