import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/ui.dart';

class LoginPage extends StatefulWidget {
  final VoidCallback onDone;
  const LoginPage({super.key, required this.onDone});
  @override
  State<LoginPage> createState() => _LoginS();
}

class _LoginS extends State<LoginPage> {
  final u = TextEditingController(), p = TextEditingController();
  bool busy = false, hide = true;

  Future<void> go() async {
    if (u.text.trim().isEmpty || p.text.isEmpty) {
      toast(context, 'Enter username and password');
      return;
    }
    setState(() => busy = true);
    try {
      await Api.login(u.text.trim(), p.text);
      widget.onDone();
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext c) => Scaffold(
      body: Container(
          decoration: const BoxDecoration(gradient: LinearGradient(colors: [ocean, deep], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
          child: SafeArea(
              child: Center(
                  child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(children: [
                        const Icon(Icons.set_meal, size: 72, color: Colors.white),
                        const SizedBox(height: 12),
                        const Text('Fish Journal', style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 28),
                        Panel(
                            pad: const EdgeInsets.all(20),
                            child: Column(children: [
                              TextField(controller: u, decoration: const InputDecoration(labelText: 'Username', prefixIcon: Icon(Icons.person_outline))),
                              const SizedBox(height: 14),
                              TextField(
                                  controller: p,
                                  obscureText: hide,
                                  decoration: InputDecoration(
                                      labelText: 'Password',
                                      prefixIcon: const Icon(Icons.lock_outline),
                                      suffixIcon: IconButton(tooltip: 'Show or hide password', icon: Icon(hide ? Icons.visibility : Icons.visibility_off), onPressed: () => setState(() => hide = !hide)))),
                              const SizedBox(height: 20),
                              FilledButton(
                                  onPressed: busy ? null : go,
                                  child: busy ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Log in')),
                              if (busy) const Padding(padding: EdgeInsets.only(top: 12), child: Text('Connecting. First time can take 30 seconds.', style: TextStyle(color: Colors.black54, fontSize: 12))),
                            ]))
                      ]))))));
}
