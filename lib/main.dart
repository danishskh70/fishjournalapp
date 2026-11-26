import 'package:flutter/material.dart';
import 'core/api.dart';
import 'core/jobs.dart';
import 'core/ui.dart';
import 'core/update.dart';
import 'screens/accounts.dart';
import 'screens/auth.dart';
import 'screens/history.dart';
import 'screens/home.dart';
import 'screens/settings.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  Api.ping();
  runApp(const App());
}

class App extends StatefulWidget {
  const App({super.key});
  @override
  State<App> createState() => _AppS();
}

class _AppS extends State<App> {
  bool? ok;
  @override
  void initState() {
    super.initState();
    Api.onExpired = () {
      if (mounted) setState(() => ok = false);
    };
    Api.hasSession().then((v) {
      if (mounted) setState(() => ok = v);
    });
  }

  @override
  Widget build(BuildContext c) => MaterialApp(
      title: 'Fish Journal',
      scaffoldMessengerKey: msgKey,
      debugShowCheckedModeBanner: false,
      theme: appTheme(),
      home: ok == null
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : ok!
              ? Shell(onLogout: () async {
                  await Api.logout();
                  if (mounted) setState(() => ok = false);
                })
              : LoginPage(onDone: () => setState(() => ok = true)));
}

class Shell extends StatefulWidget {
  final VoidCallback onLogout;
  const Shell({super.key, required this.onLogout});
  @override
  State<Shell> createState() => _ShellS();
}

class _ShellS extends State<Shell> {
  @override
  void initState() {
    super.initState();
    shellTab.value = 0;
    Jobs.i.init();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Updates.onLaunch(context);
    });
  }

  @override
  Widget build(BuildContext c) => ValueListenableBuilder<int>(
      valueListenable: shellTab,
      builder: (c, i, _) {
        final pages = <Widget>[const HomePage(), const AccountsPage(), const HistoryPage(), SettingsPage(onLogout: widget.onLogout)];
        return Scaffold(
            body: SafeArea(child: pages[i]),
            bottomNavigationBar: NavigationBar(selectedIndex: i, onDestinationSelected: (n) => shellTab.value = n, destinations: const [
              NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
              NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet), label: 'Accounts'),
              NavigationDestination(icon: Icon(Icons.history), label: 'History'),
              NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
            ]));
      });
}
