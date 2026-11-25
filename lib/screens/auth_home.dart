import 'package:material_ui/material_ui.dart';

import '../core/api.dart';
import '../core/ui.dart';
import 'accounts.dart';

class LoginPage extends StatefulWidget {
  final VoidCallback onDone;

  const LoginPage({super.key, required this.onDone});

  @override
  State<LoginPage> createState() => _LoginS();
}

class _LoginS extends State<LoginPage> {
  final u = TextEditingController();
  final p = TextEditingController();

  bool busy = false;
  bool hide = true;

  Future<void> go() async {
    setState(() => busy = true);

    try {
      await Api.login(u.text.trim(), p.text);

      if (mounted) {
        widget.onDone();
      }
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    u.dispose();
    p.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [ocean, Color(0xFF0E6E7E)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Icon(Icons.set_meal, size: 72, color: Colors.white),
                  const SizedBox(height: 12),
                  const Text(
                    'Fish Journal',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Panel(
                    pad: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        TextField(
                          controller: u,
                          decoration: const InputDecoration(
                            labelText: 'Username',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: p,
                          obscureText: hide,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                hide ? Icons.visibility : Icons.visibility_off,
                              ),
                              onPressed: () {
                                setState(() => hide = !hide);
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: busy ? null : go,
                          child: busy
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Log in'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  final void Function(int) go;

  const HomePage({super.key, required this.go});

  @override
  Widget build(BuildContext c) {
    return Fut(
      load: () => Api.req(
        'GET',
        '/api/v1/dashboard',
        q: {'business_date': isoDate(DateTime.now())},
      ),
      build: (c, d, re) {
        final status =
            '${pick(d, ['status', 'journal_status']) ?? 'not_started'}';

        return RefreshIndicator(
          onRefresh: () async => re(),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Grad(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      niceDate(isoDate(DateTime.now())),
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "Today's Journal",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Chip(
                      label: Text(label(status)),
                      backgroundColor: status == 'open'
                          ? teal
                          : status == 'closed'
                              ? Colors.white
                              : coral,
                    ),
                    const SizedBox(height: 10),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: ocean,
                      ),
                      onPressed: () => go(1),
                      child: Text(
                        status == 'open'
                            ? 'Continue journal'
                            : status == 'closed'
                                ? 'View summary'
                                : 'Start daily journal',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _tot(
                      'Hotels owe you',
                      pick(d, [
                        'total_hotel_outstanding',
                        'hotel_outstanding',
                        'hotels_outstanding',
                      ]),
                      teal,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _tot(
                      'You owe suppliers',
                      pick(d, [
                        'total_supplier_outstanding',
                        'supplier_outstanding',
                        'suppliers_outstanding',
                      ]),
                      coral,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => sheet(c, const PaySheet(hotel: false)),
                      icon: const Icon(Icons.north_east),
                      label: const Text('Pay supplier'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => sheet(c, const PaySheet(hotel: true)),
                      icon: const Icon(Icons.south_west),
                      label: const Text('Hotel paid'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (d is Map)
                Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Overview',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      KV(d),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _tot(String t, dynamic v, Color col) {
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t,
            style: const TextStyle(color: Colors.black54, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Text(
            inr(v),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: col,
            ),
          ),
        ],
      ),
    );
  }
}
