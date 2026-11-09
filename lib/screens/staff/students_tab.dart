import 'package:flutter/material.dart';

import '../../api.dart';
import '../../bn.dart';
import '../../messages.dart';
import 'widgets.dart';

/// Search the students, add one, reset a password.
class StudentsTab extends StatefulWidget {
  const StudentsTab({super.key, required this.api});
  final Api api;

  @override
  State<StudentsTab> createState() => _StudentsTabState();
}

class _StudentsTabState extends State<StudentsTab> {
  final key = GlobalKey<LoadViewState<List<Map<String, dynamic>>>>();
  String query = '';

  Future<void> add() async {
    final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => StudentFormScreen(api: widget.api)));
    if (ok == true) key.currentState?.reload();
  }

  Future<void> reset(Map<String, dynamic> s) async {
    if (!await confirmDialog(context, 'পাসওয়ার্ড রিসেট?', '${s['name']} এর জন্য নতুন পাসওয়ার্ড তৈরি হবে। পুরনো পাসওয়ার্ড ও চালু থাকা লগইন বন্ধ হয়ে যাবে।', yes: 'রিসেট করুন')) return;
    try {
      final pw = await widget.api.resetStudentPassword(s['id'] as int);
      if (mounted) await showSecret(context, title: '${s['name']} এর নতুন পাসওয়ার্ড', loginId: s['roll'] as String, password: pw);
    } catch (e) {
      if (mounted) showMessage(context, errorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(onPressed: add, icon: const Icon(Icons.person_add_alt), label: const Text('নতুন শিক্ষার্থী')),
      body: LoadView<List<Map<String, dynamic>>>(
        key: key,
        load: widget.api.students,
        builder: (context, all, reload) {
          final q = query.trim().toLowerCase();
          final list = q.isEmpty ? all : all.where((s) => (s['name'] as String).toLowerCase().contains(q) || (s['roll'] as String).contains(q)).toList();
          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: TextField(
                onChanged: (v) => setState(() => query = v),
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'নাম বা রোল দিয়ে খুঁজুন', border: OutlineInputBorder()),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: reload,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
                  children: [
                    if (list.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('কোনো শিক্ষার্থী পাওয়া যায়নি।')),
                    for (final s in list)
                      Card(
                        child: ListTile(
                          title: Text(s['name'] as String),
                          subtitle: Text('রোল ${s['roll']} · ${s['className'] ?? '-'} ${s['sectionName'] ?? ''} · পরীক্ষা ${bn(s['attempts'])}টি'),
                          trailing: IconButton(tooltip: 'পাসওয়ার্ড রিসেট', icon: const Icon(Icons.lock_reset), onPressed: () => reset(s)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ]);
        },
      ),
    );
  }
}

/// Add one student into a class section.
class StudentFormScreen extends StatefulWidget {
  const StudentFormScreen({super.key, required this.api});
  final Api api;

  @override
  State<StudentFormScreen> createState() => _StudentFormScreenState();
}

class _StudentFormScreenState extends State<StudentFormScreen> {
  final name = TextEditingController();
  final roll = TextEditingController();
  final phone = TextEditingController();
  final password = TextEditingController();
  List<Map<String, dynamic>>? classes;
  int? classId;
  int? sectionId;
  String? error;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    widget.api.classes().then((c) {
      if (mounted) {
        setState(() {
          classes = c;
          _pickClass(c.isEmpty ? null : c.first['id'] as int);
        });
      }
    }).catchError((Object e) {
      if (mounted) setState(() => error = errorMessage(e));
    });
  }

  List<Map<String, dynamic>> get sections {
    if (classes == null || classId == null) return const [];
    final c = classes!.firstWhere((x) => x['id'] == classId, orElse: () => <String, dynamic>{});
    return ((c['sections'] as List?) ?? const []).cast<Map<String, dynamic>>();
  }

  void _pickClass(int? id) {
    classId = id;
    final s = sections;
    sectionId = s.isEmpty ? null : s.first['id'] as int;
  }

  Future<void> save() async {
    String? problem;
    if (name.text.trim().length < 3) {
      problem = 'নাম অন্তত ৩ অক্ষরের হতে হবে';
    } else if (!RegExp(r'^\d{2,8}$').hasMatch(roll.text.trim())) {
      problem = 'রোল ২–৮ অঙ্কের সংখ্যা হতে হবে';
    } else if (phone.text.trim().isNotEmpty && !RegExp(r'^\d{6,15}$').hasMatch(phone.text.trim())) {
      problem = 'ফোন নম্বর ৬–১৫ অঙ্কের হতে হবে (ফাঁকাও রাখা যায়)';
    } else if (sectionId == null) {
      problem = 'শ্রেণি ও শাখা বাছুন (শাখা না থাকলে "শ্রেণি" ট্যাবে আগে শাখা বানান)';
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
      final r = await widget.api.createStudent({
        'name': name.text.trim(),
        'roll': roll.text.trim(),
        if (phone.text.trim().isNotEmpty) 'phone': phone.text.trim(),
        'sectionId': sectionId,
        if (password.text.isNotEmpty) 'password': password.text,
      });
      if (!mounted) return;
      final student = r['student'] as Map<String, dynamic>;
      await showSecret(context, title: '${student['name']} যোগ হয়েছে', loginId: student['roll'] as String, password: r['password'] as String);
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
      appBar: AppBar(title: const Text('নতুন শিক্ষার্থী')),
      body: classes == null && error == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                field(name, 'নাম'),
                field(roll, 'রোল (২–৮ অঙ্ক)', number: true),
                field(phone, 'ফোন (ঐচ্ছিক)', number: true),
                if (classes != null) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: DropdownButtonFormField<int>(
                      initialValue: classId,
                      decoration: const InputDecoration(labelText: 'শ্রেণি', border: OutlineInputBorder()),
                      items: [for (final c in classes!) DropdownMenuItem(value: c['id'] as int, child: Text(c['name'] as String))],
                      onChanged: (v) => setState(() => _pickClass(v)),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: DropdownButtonFormField<int>(
                      key: ValueKey('sec-$classId'),
                      initialValue: sectionId,
                      decoration: const InputDecoration(labelText: 'শাখা', border: OutlineInputBorder()),
                      items: [for (final s in sections) DropdownMenuItem(value: s['id'] as int, child: Text(s['name'] as String))],
                      onChanged: (v) => setState(() => sectionId = v),
                    ),
                  ),
                ],
                field(password, 'পাসওয়ার্ড (ফাঁকা রাখলে নিজে তৈরি হবে)', helper: 'তৈরির পর একবার দেখানো হবে'),
                if (error != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
                FilledButton(onPressed: busy ? null : save, child: Text(busy ? 'সংরক্ষণ হচ্ছে…' : 'যোগ করুন')),
              ],
            ),
    );
  }
}
