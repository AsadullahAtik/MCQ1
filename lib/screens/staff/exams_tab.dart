import 'package:flutter/material.dart';

import '../../api.dart';
import '../../bn.dart';
import 'exam_detail.dart';
import 'exam_form.dart';
import 'widgets.dart';

/// All exams of the institution, with a button to create a new one.
class ExamsTab extends StatefulWidget {
  const ExamsTab({super.key, required this.api});
  final Api api;

  @override
  State<ExamsTab> createState() => _ExamsTabState();
}

class _ExamsTabState extends State<ExamsTab> {
  final key = GlobalKey<LoadViewState<List<Map<String, dynamic>>>>();

  String state(Map<String, dynamic> e) {
    if (e['published'] == true) return 'ফলাফল প্রকাশিত';
    if (e['released'] == true) return 'শিক্ষার্থীরা দিতে পারছে';
    return 'খসড়া';
  }

  Future<void> create() async {
    final created = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => ExamFormScreen(api: widget.api)));
    if (created == true) key.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(onPressed: create, icon: const Icon(Icons.add), label: const Text('নতুন পরীক্ষা')),
      body: LoadView<List<Map<String, dynamic>>>(
        key: key,
        load: widget.api.adminExams,
        builder: (context, exams, reload) => RefreshIndicator(
          onRefresh: reload,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
            children: [
              if (exams.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('এখনও কোনো পরীক্ষা নেই। "নতুন পরীক্ষা" চাপুন।')),
              for (final e in exams)
                Card(
                  child: ListTile(
                    title: Text(e['title'] as String),
                    subtitle: Text('${e['className']} · ${state(e)}\n${bn(e['questionCount'])}টি প্রশ্ন · ${bn(e['durationMinutes'])} মিনিট · অংশগ্রহণ ${bn(e['attempts'])}'),
                    isThreeLine: true,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ExamDetailScreen(api: widget.api, examId: e['id'] as int)));
                      reload();
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
