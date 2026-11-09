import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api.dart';
import '../main.dart' show isSupportedRole;
import '../messages.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.api, required this.onLoggedIn});

  final Api api;
  final void Function(Map<String, dynamic> user) onLoggedIn;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final inst = TextEditingController();
  final roll = TextEditingController();
  final pw = TextEditingController();
  bool busy = false;
  bool show = false;
  String? error;
  String? errorDetail;
  late final TextEditingController server = TextEditingController(text: widget.api.baseUrl);
  String? probeResult;
  bool probing = false;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      final last = p.getString('livemcq.institution');
      if (last != null && mounted) inst.text = last;
    });
  }

  Future<void> submit() async {
    if (inst.text.trim().isEmpty || roll.text.trim().isEmpty || pw.text.isEmpty) {
      setState(() => error = 'প্রতিষ্ঠান কোড, রোল ও পাসওয়ার্ড তিনটিই লিখুন');
      return;
    }
    setState(() {
      busy = true;
      error = null;
      errorDetail = null;
    });
    try {
      await widget.api.setBaseUrl(server.text);
      final user = await widget.api.login(inst.text, roll.text, pw.text);
      if (!isSupportedRole(user['role'])) {
        await widget.api.logout();
        throw ApiException(403, 'NOT_SUPPORTED_ROLE');
      }
      final p = await SharedPreferences.getInstance();
      await p.setString('livemcq.institution', inst.text.trim());
      widget.onLoggedIn(user);
    } catch (e) {
      if (mounted) {
        setState(() {
          error = errorMessage(e);
          errorDetail = e is ApiException ? e.detail : null;
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> testConnection() async {
    setState(() {
      probing = true;
      probeResult = null;
    });
    await widget.api.setBaseUrl(server.text);
    final r = await widget.api.probe();
    if (mounted) {
      setState(() {
        probing = false;
        probeResult = r ?? 'সংযোগ ঠিক আছে ✓';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('স্বাগতম', style: Theme.of(context).textTheme.headlineMedium, textAlign: TextAlign.center),
                  const SizedBox(height: 4),
                  const Text('আপনার অ্যাকাউন্টে লগইন করুন', textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  TextField(
                    controller: inst,
                    autocorrect: false,
                    textCapitalization: TextCapitalization.none,
                    decoration: const InputDecoration(labelText: 'প্রতিষ্ঠান কোড', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: roll,
                    autocorrect: false,
                    textCapitalization: TextCapitalization.none,
                    decoration: const InputDecoration(labelText: 'রোল', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: pw,
                    obscureText: !show,
                    onSubmitted: (_) => submit(),
                    decoration: InputDecoration(
                      labelText: 'পাসওয়ার্ড',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        tooltip: show ? 'পাসওয়ার্ড লুকান' : 'পাসওয়ার্ড দেখান',
                        icon: Icon(show ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => show = !show),
                      ),
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    if (errorDetail != null) Text(errorDetail!, style: Theme.of(context).textTheme.bodySmall),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: busy ? null : submit,
                    child: busy
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('লগইন'),
                  ),
                  const SizedBox(height: 8),
                  ExpansionTile(
                    title: const Text('সার্ভার ঠিকানা'),
                    subtitle: Text(server.text, overflow: TextOverflow.ellipsis),
                    children: [
                      TextField(
                        controller: server,
                        keyboardType: TextInputType.url,
                        autocorrect: false,
                        onChanged: (_) => setState(() => probeResult = null),
                        decoration: const InputDecoration(
                          helperText: 'যেমন http://192.168.1.107:8080 বা https://exam.example.com',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: probing ? null : testConnection,
                        child: Text(probing ? 'পরীক্ষা হচ্ছে…' : 'সংযোগ পরীক্ষা করুন'),
                      ),
                      if (probeResult != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(probeResult!)),
                    ],
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
