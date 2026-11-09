import 'package:flutter/material.dart';

import '../../api.dart';
import '../../messages.dart';
import 'widgets.dart';

/// ADMIN only: the other admins and teachers of this institution.
class StaffTab extends StatelessWidget {
  const StaffTab({super.key, required this.api});
  final Api api;

  @override
  Widget build(BuildContext context) {
    return LoadView<List<Map<String, dynamic>>>(
      load: api.staff,
      builder: (context, staff, reload) {
        Future<void> run(Future<void> Function() action) async {
          try {
            await action();
            await reload();
          } catch (e) {
            if (context.mounted) showMessage(context, errorMessage(e));
          }
        }

        return Scaffold(
          floatingActionButton: FloatingActionButton.extended(
            icon: const Icon(Icons.person_add_alt),
            label: const Text('শিক্ষক যোগ'),
            onPressed: () async {
              final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => StaffFormScreen(api: api)));
              if (ok == true) await reload();
            },
          ),
          body: RefreshIndicator(
            onRefresh: reload,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
              children: [
                for (final u in staff)
                  Card(
                    child: ListTile(
                      title: Text('${u['name']}${u['you'] == true ? ' (আপনি)' : ''}'),
                      subtitle: Text('${u['loginId']} · ${u['role'] == 'ADMIN' ? 'অ্যাডমিন' : 'শিক্ষক'}'),
                      trailing: u['you'] == true
                          ? null
                          : PopupMenuButton<String>(
                              onSelected: (v) async {
                                final id = u['id'] as int;
                                if (v == 'role') {
                                  await run(() => api.changeStaffRole(id, u['role'] == 'ADMIN' ? 'TEACHER' : 'ADMIN'));
                                } else if (v == 'reset') {
                                  if (!await confirmDialog(context, 'পাসওয়ার্ড রিসেট?', '${u['name']} এর নতুন পাসওয়ার্ড তৈরি হবে, পুরনো লগইন বন্ধ হবে।', yes: 'রিসেট করুন')) return;
                                  try {
                                    final pw = await api.resetStaffPassword(id);
                                    if (context.mounted) await showSecret(context, title: '${u['name']} এর নতুন পাসওয়ার্ড', loginId: u['loginId'] as String, password: pw);
                                  } catch (e) {
                                    if (context.mounted) showMessage(context, errorMessage(e));
                                  }
                                } else if (v == 'delete') {
                                  if (!await confirmDialog(context, 'মুছবেন?', '${u['name']} এর অ্যাকাউন্ট মুছে যাবে।', yes: 'মুছুন')) return;
                                  await run(() => api.deleteStaff(id));
                                }
                              },
                              itemBuilder: (_) => [
                                PopupMenuItem(value: 'role', child: Text(u['role'] == 'ADMIN' ? 'শিক্ষক করুন' : 'অ্যাডমিন করুন')),
                                const PopupMenuItem(value: 'reset', child: Text('পাসওয়ার্ড রিসেট')),
                                const PopupMenuItem(value: 'delete', child: Text('মুছুন')),
                              ],
                            ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class StaffFormScreen extends StatefulWidget {
  const StaffFormScreen({super.key, required this.api});
  final Api api;

  @override
  State<StaffFormScreen> createState() => _StaffFormScreenState();
}

class _StaffFormScreenState extends State<StaffFormScreen> {
  final name = TextEditingController();
  final loginId = TextEditingController();
  final password = TextEditingController();
  String role = 'TEACHER';
  String? error;
  bool busy = false;

  Future<void> save() async {
    String? problem;
    if (name.text.trim().length < 3) {
      problem = 'নাম অন্তত ৩ অক্ষরের হতে হবে';
    } else if (!RegExp(r'^[A-Za-z0-9._-]{3,20}$').hasMatch(loginId.text.trim())) {
      problem = 'লগইন আইডি ৩–২০ অক্ষরের: ইংরেজি অক্ষর, সংখ্যা, ডট, ড্যাশ বা আন্ডারস্কোর';
    } else if (password.text.isNotEmpty && password.text.length < 4) {
      problem = 'পাসওয়ার্ড অন্তত ৪ অক্ষরের হতে হবে (ফাঁকা রাখলে নিজে তৈরি হবে)';
    }
    if (problem != null) {
      setState(() => error = problem);
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final r = await widget.api.createStaff({
        'name': name.text.trim(),
        'loginId': loginId.text.trim(),
        'role': role,
        if (password.text.isNotEmpty) 'password': password.text,
      });
      if (!mounted) return;
      final s = r['staff'] as Map<String, dynamic>;
      await showSecret(context, title: '${s['name']} যোগ হয়েছে', loginId: s['loginId'] as String, password: r['password'] as String);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => error = errorMessage(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('শিক্ষক / অ্যাডমিন যোগ')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          field(name, 'নাম'),
          field(loginId, 'লগইন আইডি', helper: 'লগইনে রোল ঘরে এটাই লিখবেন'),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: DropdownButtonFormField<String>(
              initialValue: role,
              decoration: const InputDecoration(labelText: 'ভূমিকা', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'TEACHER', child: Text('শিক্ষক')),
                DropdownMenuItem(value: 'ADMIN', child: Text('অ্যাডমিন (শিক্ষক-কর্মীও পরিচালনা করতে পারবে)')),
              ],
              onChanged: (v) => setState(() => role = v ?? 'TEACHER'),
            ),
          ),
          field(password, 'পাসওয়ার্ড (ফাঁকা রাখলে নিজে তৈরি হবে)'),
          if (error != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
          FilledButton(onPressed: busy ? null : save, child: Text(busy ? 'সংরক্ষণ হচ্ছে…' : 'যোগ করুন')),
        ],
      ),
    );
  }
}
