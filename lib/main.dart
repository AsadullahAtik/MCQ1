import 'package:flutter/material.dart';

import 'api.dart';
import 'screens/home.dart';
import 'screens/login.dart';
import 'screens/staff/staff_home.dart';

void main() {
  runApp(const LiveMcqApp());
}

/// Roles this app can serve. The platform owner (SUPER_ADMIN) uses the website.
bool isSupportedRole(Object? role) => role == 'STUDENT' || role == 'ADMIN' || role == 'TEACHER';

class LiveMcqApp extends StatefulWidget {
  const LiveMcqApp({super.key});

  @override
  State<LiveMcqApp> createState() => _LiveMcqAppState();
}

class _LiveMcqAppState extends State<LiveMcqApp> {
  final api = Api();
  bool ready = false;
  Map<String, dynamic>? user;

  @override
  void initState() {
    super.initState();
    api.onSignedOut = () {
      if (mounted) setState(() => user = null);
    };
    _boot();
  }

  /// A saved token may be stale (expired, password changed elsewhere): ask the server before trusting it.
  Future<void> _boot() async {
    await api.restore();
    if (api.signedIn) {
      try {
        final u = await api.me();
        if (isSupportedRole(u['role'])) user = u;
      } catch (_) {
        // offline or expired: show the login screen
      }
    }
    if (mounted) setState(() => ready = true);
  }

  void signOut() => setState(() => user = null);

  @override
  Widget build(BuildContext context) {
    final Widget home;
    if (!ready) {
      home = const Scaffold(body: Center(child: CircularProgressIndicator()));
    } else if (user == null) {
      home = LoginScreen(api: api, onLoggedIn: (u) => setState(() => user = u));
    } else if (user!['role'] == 'STUDENT') {
      home = HomeScreen(api: api, user: user!, onLoggedOut: signOut);
    } else {
      home = StaffHome(api: api, user: user!, onLoggedOut: signOut);
    }
    return MaterialApp(
      title: 'Live MCQ',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: const Color(0xFF2F6FED), useMaterial3: true),
      home: home,
    );
  }
}
