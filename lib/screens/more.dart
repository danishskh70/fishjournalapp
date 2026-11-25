import 'package:material_ui/material_ui.dart';
import '../core/api.dart';
import '../core/ui.dart';
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
                  if (l.isEmpty) {
                    return const Center(child: Text('No previous journals'));
                  }
                  return ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        for (final e in l)
                          Panel(
                              onTap: () {
                                final dt = DateTime.tryParse(
                                    '${pick(e, ['business_date', 'date'])}');
                                if (dt != null) {
                                  Navigator.push(
                                      c,
                                      MaterialPageRoute(
                                          builder: (_) => Scaffold(
                                              appBar: AppBar(),
                                              body: JournalPage(date: dt))));
                                }
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
  Future<void> add() async {
    final t = TextEditingController();
    final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
                title: Text('Add ${widget.title}'),
                content: TextField(
                    controller: t,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: 'Name')),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel')),
                  FilledButton(
                      style: FilledButton.styleFrom(
                          minimumSize: const Size(90, 44)),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Save'))
                ]));
    if (ok != true || t.text.trim().isEmpty) return;
    try {
      await Api.req('POST', widget.path, body: {'name': t.text.trim()});
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
                      child: Row(children: [
                    Expanded(
                        child: Text('${e['name']}',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600))),
                    Switch(
                        value: e['is_active'] != false,
                        onChanged: (x) async {
                          try {
                            await Api.req('PATCH', '${widget.path}/${e['id']}',
                                body: {'is_active': x});
                            setState(() => v++);
                          } on ApiException catch (er) {
                            if (c.mounted) toast(c, er.message);
                          }
                        })
                  ]))
              ])));
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
