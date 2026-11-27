import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../core/api.dart';
import '../core/config.dart';
import '../core/jobs.dart';
import '../core/store.dart';
import '../core/ui.dart';
import '../core/update.dart';
import '../core/result.dart';

class SettingsPage extends StatelessWidget {
  final VoidCallback onLogout;
  const SettingsPage({super.key, required this.onLogout});

  Widget item(
          BuildContext c, IconData i, String t, String s, VoidCallback on) =>
      Panel(
          onTap: on,
          child: Row(children: [
            CircleAvatar(
                backgroundColor: tint(ocean), child: Icon(i, color: ocean)),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(t,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16)),
                  if (s.isNotEmpty)
                    Text(s,
                        style: const TextStyle(
                            color: Colors.black54, fontSize: 12))
                ])),
            const Icon(Icons.chevron_right),
          ]));

  void go(BuildContext c, Widget w) =>
      Navigator.push(c, MaterialPageRoute(builder: (_) => w));

  Future<void> shop(BuildContext c) async {
    final t = TextEditingController(text: (await Store.get('shop')) ?? '');
    if (!c.mounted) return;
    final ok = await showDialog<bool>(
        context: c,
        builder: (_) => AlertDialog(
                title: const Text('Shop name'),
                content: TextField(
                    controller: t,
                    textCapitalization: TextCapitalization.words,
                    decoration:
                        const InputDecoration(labelText: 'Name shown on Home')),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('Cancel')),
                  FilledButton(
                      style: FilledButton.styleFrom(
                          minimumSize: const Size(100, 48)),
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('Save')),
                ]));
    if (ok == true) await Store.set('shop', t.text.trim());
  }

  @override
  Widget build(BuildContext c) =>
      ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Settings',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
        const SizedBox(height: 14),
        const Sect('Your business', Icons.store, teal),
        item(c, Icons.set_meal, 'Fish varieties', 'Add or hide fish',
            () => go(c, const MasterPage(kind: 'fish'))),
        item(c, Icons.local_shipping, 'Suppliers', 'Add or hide suppliers',
            () => go(c, const MasterPage(kind: 'suppliers'))),
        item(c, Icons.hotel, 'Hotels', 'Add hotels and agreed rates',
            () => go(c, const MasterPage(kind: 'hotels'))),
        item(c, Icons.storefront, 'Shop name', 'Shown on Home', () => shop(c)),
        const SizedBox(height: 8),
        const Sect('App', Icons.phone_android, ocean),
        item(
            c,
            Icons.system_update,
            'About and updates',
            'Version, what is new, check for update',
            () => go(c, const AboutPage())),
        item(c, Icons.lock_outline, 'Change password', '',
            () => sheet(c, const PwSheet())),
        item(c, Icons.logout, 'Log out', '', () async {
          final pending = Jobs.i.list.isNotEmpty;
          if (await confirm(
              c,
              pending
                  ? 'Some entries are not uploaded yet. They stay on the phone and upload after you log in again. Log out?'
                  : 'Log out?')) onLogout();
        }),
      ]);
}

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});
  @override
  Widget build(BuildContext c) => Scaffold(
      appBar: AppBar(title: const Text('About and updates')),
      body: FutureBuilder<PackageInfo>(
          future: PackageInfo.fromPlatform(),
          builder: (c, s) {
            final v = s.data?.version ?? '';
            final keys = changelog.keys.toList().reversed.toList();
            return ListView(padding: const EdgeInsets.all(16), children: [
              Grad(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    const Text('Fish Khata',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800)),
                    Text('Version $v',
                        style: const TextStyle(color: Colors.white70))
                  ])),
              const SizedBox(height: 14),
              const Panel(
                  child: Text(
                      'This app is installed directly, not from Play Store. When a new version is ready, a notice appears here and on opening the app. Tap Download, open the file, tap Install. Your data stays.')),
              FilledButton.icon(
                  onPressed: () => Updates.check(c, manual: true),
                  icon: const Icon(Icons.system_update),
                  label: const Text('Check for update')),
              const SizedBox(height: 16),
              for (final k in keys)
                Panel(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text("What's new in $k",
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      for (final x in changelog[k]!)
                        Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text('• $x'))
                    ])),
            ]);
          }));
}

class PwSheet extends StatefulWidget {
  const PwSheet({super.key});
  @override
  State<PwSheet> createState() => _PW();
}

class _PW extends State<PwSheet> {
  final a = TextEditingController(), b = TextEditingController();
  Future<void> save() async {
    if (b.text.length < 10) {
      toast(context, 'New password needs at least 10 characters');
      return;
    }
    final changed = await runWithResult(
      context,
      action: () => Api.req(
        'POST',
        '/api/v1/auth/change-password',
        body: {'current_password': a.text, 'new_password': b.text},
      ),
      working: 'Changing password...',
      okTitle: 'Password changed',
      retryable: false,
      failHint:
          'If the request failed unexpectedly, try logging in with your new password before attempting another change.',
    );

    if (changed && mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext c) =>
      Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Change password',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 14),
        TextField(
            controller: a,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Current password')),
        const SizedBox(height: 12),
        TextField(
            controller: b,
            obscureText: true,
            decoration: const InputDecoration(
                labelText: 'New password (10+ characters)')),
        const SizedBox(height: 16),
        FilledButton(onPressed: save, child: const Text('Save')),
      ]);
}

/// Fish, suppliers and hotels: list, add, hide.
class MasterPage extends StatefulWidget {
  final String kind;
  const MasterPage({super.key, required this.kind});
  @override
  State<MasterPage> createState() => _MP();
}

class _MP extends State<MasterPage> {
  int v = 0;
  bool inactive = false;
  String get title => const {
        'fish': 'Fish varieties',
        'suppliers': 'Suppliers',
        'hotels': 'Hotels'
      }[widget.kind]!;
  String get path => '/api/v1/${widget.kind}';

  Future<void> add() async {
    final ok = await sheet<bool>(context, AddMaster(kind: widget.kind));
    if (ok == true && mounted) setState(() => v++);
  }

  Future<void> toggle(Map x, bool on) async {
    try {
      await Api.req('PATCH', '$path/${x['id']}', body: {'is_active': on});
      if (mounted) setState(() => v++);
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
      appBar: AppBar(title: Text(title), actions: [
        Row(children: [
          const Text('Hidden'),
          Switch(
              value: inactive, onChanged: (x) => setState(() => inactive = x))
        ]),
      ]),
      floatingActionButton: FloatingActionButton.extended(
          onPressed: add,
          icon: const Icon(Icons.add),
          label: const Text('Add')),
      body: Fut(
          key: ValueKey('$v-$inactive'),
          cacheKey: 'master:$path:$inactive',
          load: () => fetch(path, q: {'include_inactive': '$inactive'}),
          build: (c, data, re) {
            final l = data as List;
            if (l.isEmpty)
              return const Center(child: Text('Nothing here yet.'));
            return ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                children: [
                  for (final x in l)
                    Panel(
                        onTap: widget.kind == 'hotels'
                            ? () async {
                                await Navigator.push(
                                    c,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            HotelRates(hotel: x as Map)));
                                if (mounted) setState(() => v++);
                              }
                            : null,
                        child: Row(children: [
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text('${x['name']}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 17)),
                                if (widget.kind == 'hotels')
                                  Text(
                                      '${L(x['rates']).length} agreed rates. Tap to edit.',
                                      style: const TextStyle(
                                          color: Colors.black54, fontSize: 12)),
                                if (x['is_active'] == false)
                                  const Text('Hidden',
                                      style: TextStyle(
                                          color: coral,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700)),
                              ])),
                          Switch(
                              value: x['is_active'] == true,
                              onChanged: (on) => toggle(x as Map, on)),
                        ])),
                ]);
          }));
}

class AddMaster extends StatefulWidget {
  final String kind;
  const AddMaster({super.key, required this.kind});
  @override
  State<AddMaster> createState() => _AM();
}

class _AM extends State<AddMaster> {
  final name = TextEditingController(),
      phone = TextEditingController(),
      bal = TextEditingController();
  bool get party => widget.kind != 'fish';

  Future<void> save() async {
    if (name.text.trim().isEmpty) {
      toast(context, 'Type a name');
      return;
    }

    final body = <String, dynamic>{'name': name.text.trim()};
    if (party) {
      if (phone.text.trim().isNotEmpty) body['phone'] = phone.text.trim();
      if (n(bal.text) > 0) {
        body['opening_balance'] = '${n(bal.text)}';
        body['opening_balance_date'] = isoDate(DateTime.now());
      }
    }

    final added = await runWithResult(
      context,
      action: () => Api.req('POST', '/api/v1/${widget.kind}', body: body),
      working: 'Adding...',
      okTitle: 'Added successfully',
      retryable: false,
      failHint:
          'Check the list first. If the item is already there, do not add it again.',
    );

    if (added && mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext c) =>
      Column(mainAxisSize: MainAxisSize.min, children: [
        Text(
            widget.kind == 'fish'
                ? 'New fish'
                : (widget.kind == 'hotels' ? 'New hotel' : 'New supplier'),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 14),
        TextField(
            controller: name,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Name')),
        if (party) ...[
          const SizedBox(height: 12),
          TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone (optional)')),
          const SizedBox(height: 12),
          numField(
              bal,
              widget.kind == 'hotels'
                  ? 'Already owes you (₹, optional)'
                  : 'You already owe (₹, optional)'),
        ],
        const SizedBox(height: 16),
        FilledButton(onPressed: save, child: const Text('Save')),
      ]);
}

class HotelRates extends StatefulWidget {
  final Map hotel;
  const HotelRates({super.key, required this.hotel});
  @override
  State<HotelRates> createState() => _HR();
}

class _HR extends State<HotelRates> {
  int v = 0;

  Future<void> edit(int fishId, String fishName, String current) async {
    final t = TextEditingController(text: current);
    final act = await showDialog<String>(
        context: context,
        builder: (_) => AlertDialog(
                title: Text(fishName),
                content: numField(t, 'Agreed rate per kg (₹)', autofocus: true),
                actions: [
                  if (current.isNotEmpty)
                    TextButton(
                        onPressed: () => Navigator.pop(context, 'del'),
                        child: const Text('Remove')),
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel')),
                  FilledButton(
                      style: FilledButton.styleFrom(
                          minimumSize: const Size(90, 48)),
                      onPressed: () => Navigator.pop(context, 'save'),
                      child: const Text('Save')),
                ]));
    if (act == null) return;
    try {
      final p = '/api/v1/hotels/${widget.hotel['id']}/rates/$fishId';
      if (act == 'del') {
        await Api.req('DELETE', p);
      } else {
        if (n(t.text) <= 0) {
          if (mounted) toast(context, 'Type a rate');
          return;
        }
        await Api.req('PUT', p, body: {'rate': '${n(t.text)}'});
      }
      if (mounted) setState(() => v++);
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
      appBar: AppBar(title: Text('${widget.hotel['name']} rates')),
      body: Fut(
          key: ValueKey(v),
          cacheKey: 'hotel-rates:${widget.hotel['id']}',
          load: () async {
            final fish = await fetch('/api/v1/fish');
            final rates =
                await fetch('/api/v1/hotels/${widget.hotel['id']}/rates');
            return [fish, rates];
          },
          build: (c, d, re) {
            final fish = d[0] as List;
            final rates = <int, String>{
              for (final r in d[1] as List)
                r['fish_id'] as int: fmt(nz(r['rate']))
            };
            return ListView(padding: const EdgeInsets.all(16), children: [
              const Text(
                  'Agreed price per kg for this hotel. Used automatically in hotel sales.',
                  style: TextStyle(color: Colors.black54)),
              const SizedBox(height: 12),
              for (final f in fish)
                Panel(
                    onTap: () => edit(
                        f['id'] as int, '${f['name']}', rates[f['id']] ?? ''),
                    child: Row(children: [
                      Expanded(
                          child: Text('${f['name']}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 17))),
                      Text(
                          rates.containsKey(f['id'])
                              ? '₹${rates[f['id']]}'
                              : 'Set rate',
                          style: TextStyle(
                              color: rates.containsKey(f['id']) ? ocean : coral,
                              fontWeight: FontWeight.w800)),
                      const Icon(Icons.chevron_right),
                    ])),
            ]);
          }));
}
