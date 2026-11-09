import 'package:flutter/material.dart';

import '../api.dart';
import '../messages.dart';

/// Who I am, change my password, log out.
class ProfileView extends StatefulWidget {
  const ProfileView({super.key, required this.api, required this.user, required this.onLoggedOut});
  final Api api;
  final Map<String, dynamic> user;
  final VoidCallback onLoggedOut;

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  final current = TextEditingController();
  final next = TextEditingController();
  final again = TextEditingController();
  String? error;
  bool done = false;
  bool busy = false;

  Future<void> save() async {
    setState(() {
      error = null;
      done = false;
    });
    if (current.text.isEmpty) return setState(() => error = 'বর্তমান পাসওয়ার্ড লিখুন');
    if (next.text.length < 4) return setState(() => error = 'নতুন পাসওয়ার্ড অন্তত ৪ অক্ষরের হতে হবে');
    if (next.text == current.text) return setState(() => error = 'নতুন পাসওয়ার্ড বর্তমানটির থেকে আলাদা হতে হবে');
    if (again.text != next.text) return setState(() => error = 'দুইবার একই পাসওয়ার্ড লিখুন');
    setState(() => busy = true);
    try {
      await widget.api.changePassword(current.text, next.text);
      current.clear();
      next.clear();
      again.clear();
      if (mounted) setState(() => done = true);
    } catch (e) {
      if (mounted) setState(() => error = errorMessage(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            title: Text(u['name'] as String),
            subtitle: Text('রোল ${u['roll']} · ${u['className'] ?? ''} ${u['sectionName'] ?? ''}\n${u['institution']['name']}'),
            isThreeLine: true,
          ),
        ),
        const SizedBox(height: 16),
        Text('পাসওয়ার্ড বদলান', style: Theme.of(context).textTheme.titleMedium),
        const Text('বদলালে অন্য সব ডিভাইসে আপনি লগআউট হয়ে যাবেন।'),
        const SizedBox(height: 8),
        TextField(controller: current, obscureText: true, decoration: const InputDecoration(labelText: 'বর্তমান পাসওয়ার্ড', border: OutlineInputBorder())),
        const SizedBox(height: 8),
        TextField(controller: next, obscureText: true, decoration: const InputDecoration(labelText: 'নতুন পাসওয়ার্ড', border: OutlineInputBorder())),
        const SizedBox(height: 8),
        TextField(controller: again, obscureText: true, decoration: const InputDecoration(labelText: 'নতুন পাসওয়ার্ড আবার', border: OutlineInputBorder())),
        if (error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
        if (done) const Padding(padding: EdgeInsets.only(top: 8), child: Text('পাসওয়ার্ড বদলানো হয়েছে।')),
        const SizedBox(height: 8),
        FilledButton(onPressed: busy ? null : save, child: const Text('পাসওয়ার্ড বদলান')),
        const SizedBox(height: 24),
        OutlinedButton(
          onPressed: () async {
            await widget.api.logout();
            widget.onLoggedOut();
          },
          child: const Text('লগআউট'),
        ),
      ],
    );
  }
}
