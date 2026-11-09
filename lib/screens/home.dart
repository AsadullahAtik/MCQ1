import 'package:flutter/material.dart';

import '../api.dart';
import '../bn.dart';
import '../messages.dart';
import 'board.dart';
import 'exam.dart';
import 'profile.dart';
import 'result.dart';

/// Three tabs: exams, overall leaderboard, profile.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.api, required this.user, required this.onLoggedOut});

  final Api api;
  final Map<String, dynamic> user;
  final VoidCallback onLoggedOut;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      ExamList(api: widget.api),
      OverallBoardView(api: widget.api),
      ProfileView(api: widget.api, user: widget.user, onLoggedOut: widget.onLoggedOut),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(widget.user['institution']['name'] as String)),
      body: SafeArea(child: pages[tab]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.assignment_outlined), label: 'পরীক্ষা'),
          NavigationDestination(icon: Icon(Icons.emoji_events_outlined), label: 'মেধাতালিকা'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'প্রোফাইল'),
        ],
      ),
    );
  }
}

/// The student's exams, grouped by what they can do with each right now.
class ExamList extends StatefulWidget {
  const ExamList({super.key, required this.api});
  final Api api;

  @override
  State<ExamList> createState() => _ExamListState();
}

class _ExamListState extends State<ExamList> {
  List<Map<String, dynamic>>? exams;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final list = await widget.api.exams();
      if (mounted) {
        setState(() {
          exams = list;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = errorMessage(e));
    }
  }

  List<Map<String, dynamic>> where(bool Function(Map<String, dynamic>) f) => exams!.where(f).toList();

  Future<void> open(Map<String, dynamic> e) async {
    final status = e['status'] as String;
    final id = e['id'] as int;
    if (status == 'AVAILABLE' || status == 'IN_PROGRESS') {
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ExamScreen(api: widget.api, examId: id, title: e['title'] as String)));
    } else if (status == 'SUBMITTED' && e['published'] == true) {
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ResultScreen(api: widget.api, examId: id)));
    }
    load();
  }

  Widget section(String title, List<Map<String, dynamic>> items, String Function(Map<String, dynamic>) subtitle, {bool tappable = true}) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 4), child: Text(title, style: Theme.of(context).textTheme.titleSmall)),
        for (final e in items)
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: ListTile(
              title: Text(e['title'] as String),
              subtitle: Text(subtitle(e)),
              trailing: tappable ? const Icon(Icons.chevron_right) : null,
              onTap: tappable ? () => open(e) : null,
            ),
          ),
      ],
    );
  }

  String info(Map<String, dynamic> e) =>
      '${bn(e['questionCount'])}টি প্রশ্ন · ${bn(e['durationMinutes'])} মিনিট · পূর্ণমান ${marks(e['fullMarks'] as num)}';

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(error!, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          FilledButton(onPressed: load, child: const Text('আবার চেষ্টা')),
        ]),
      );
    }
    if (exams == null) return const Center(child: CircularProgressIndicator());
    final open = where((e) => e['status'] == 'AVAILABLE' || e['status'] == 'IN_PROGRESS');
    final upcoming = where((e) => e['status'] == 'UPCOMING');
    final waiting = where((e) => e['status'] == 'SUBMITTED' && e['published'] != true);
    final done = where((e) => e['status'] == 'SUBMITTED' && e['published'] == true);
    final missed = where((e) => e['status'] == 'MISSED' || e['status'] == 'EXPIRED' || e['status'] == 'CLOSED');
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (exams!.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Text('এখনও কোনো পরীক্ষা নেই।')),
          section('এখন দিতে পারবেন', open, (e) => '${e['status'] == 'IN_PROGRESS' ? 'চলছে, ফিরে গিয়ে শেষ করুন · ' : ''}${info(e)}'),
          section('শীঘ্রই শুরু হবে', upcoming, (e) => info(e), tappable: false),
          section('জমা দেওয়া হয়েছে, ফলাফলের অপেক্ষায়', waiting, (e) => 'শিক্ষক ফলাফল প্রকাশ করলে দেখতে পাবেন', tappable: false),
          section('ফলাফল', done, (e) => info(e)),
          section('অংশ নেননি', missed, (e) => info(e), tappable: false),
        ],
      ),
    );
  }
}
