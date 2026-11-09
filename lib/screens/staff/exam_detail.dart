import 'package:flutter/material.dart';

import '../../api.dart';
import '../../bn.dart';
import '../../messages.dart';
import '../board.dart';
import 'widgets.dart';

/// One exam: its state, its questions with the right answers, and the teacher's actions.
class ExamDetailScreen extends StatefulWidget {
  const ExamDetailScreen({super.key, required this.api, required this.examId});
  final Api api;
  final int examId;

  @override
  State<ExamDetailScreen> createState() => _ExamDetailScreenState();
}

class _ExamDetailScreenState extends State<ExamDetailScreen> {
  final key = GlobalKey<LoadViewState<Map<String, dynamic>>>();
  bool busy = false;

  Future<void> run(Future<void> Function() action, String ok) async {
    setState(() => busy = true);
    try {
      await action();
      if (mounted) showMessage(context, ok);
      await key.currentState?.reload();
    } catch (e) {
      if (mounted) showMessage(context, errorMessage(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> delete(Map<String, dynamic> exam) async {
    if (!await confirmDialog(context, 'পরীক্ষা মুছবেন?', '"${exam['title']}" চিরতরে মুছে যাবে।', yes: 'মুছুন')) return;
    try {
      await widget.api.deleteExam(widget.examId);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) showMessage(context, errorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('পরীক্ষা')),
      body: LoadView<Map<String, dynamic>>(
        key: key,
        load: () => widget.api.adminExam(widget.examId),
        builder: (context, d, reload) {
          final exam = d['exam'] as Map<String, dynamic>;
          final questions = (d['questions'] as List).cast<Map<String, dynamic>>();
          final released = exam['released'] == true;
          final published = exam['published'] == true;
          final attempts = exam['attempts'] as int;
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                Text(exam['title'] as String, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 4),
                Text('${exam['className']} · ${bn(exam['questionCount'])}টি প্রশ্ন · ${bn(exam['durationMinutes'])} মিনিট'),
                Text('প্রতি প্রশ্ন ${marks(exam['marksPerQuestion'] as num)} · ভুলে কাটা ${marks(exam['negativeMarks'] as num)} · পূর্ণমান ${marks(exam['fullMarks'] as num)}'),
                Text('অংশগ্রহণ ${bn(attempts)} জন'),
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 4, children: [
                  Chip(label: Text(released ? 'চালু' : 'খসড়া')),
                  if (published) const Chip(label: Text('ফলাফল প্রকাশিত')),
                ]),
                const SizedBox(height: 8),
                if (!published)
                  FilledButton(
                    onPressed: busy ? null : () => run(() => widget.api.setReleased(widget.examId, !released), released ? 'বন্ধ করা হয়েছে' : 'শিক্ষার্থীদের জন্য চালু হয়েছে'),
                    child: Text(released ? 'শিক্ষার্থীদের জন্য বন্ধ করুন' : 'শিক্ষার্থীদের জন্য চালু করুন'),
                  ),
                if (released || published) ...[
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: busy
                        ? null
                        : () async {
                            if (!published && !await confirmDialog(context, 'ফলাফল প্রকাশ করবেন?', 'শিক্ষার্থীরা নিজেদের ফলাফল, সঠিক উত্তর ও মেধাতালিকা দেখতে পাবে। এরপর প্রশ্ন বদলানো যাবে না।', yes: 'প্রকাশ করুন')) return;
                            await run(() => widget.api.setPublished(widget.examId, !published), published ? 'প্রকাশ বন্ধ করা হয়েছে' : 'ফলাফল প্রকাশিত হয়েছে');
                          },
                    child: Text(published ? 'ফলাফল প্রকাশ তুলে নিন' : 'ফলাফল প্রকাশ করুন'),
                  ),
                ],
                if (attempts > 0) ...[
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AdminBoardScreen(api: widget.api, examId: widget.examId))),
                    child: const Text('মেধাতালিকা দেখুন'),
                  ),
                ],
                if (attempts == 0 && !published) ...[
                  const SizedBox(height: 8),
                  TextButton(onPressed: busy ? null : () => delete(exam), child: Text('পরীক্ষা মুছুন', style: TextStyle(color: Theme.of(context).colorScheme.error))),
                ],
                const Divider(height: 32),
                Text('প্রশ্ন', style: Theme.of(context).textTheme.titleMedium),
                for (var i = 0; i < questions.length; i++) _question(context, i, questions[i]),
                const SizedBox(height: 16),
                const Text('প্রশ্ন সম্পাদনা, সময়সূচি ও প্রশ্নভিত্তিক বিশ্লেষণ ওয়েবসাইটে আছে।', style: TextStyle(fontStyle: FontStyle.italic)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _question(BuildContext context, int i, Map<String, dynamic> q) {
    final options = (q['options'] as List).cast<String>();
    final correct = q['correctIdx'] as int;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${bn(i + 1)}. ${q['body']}', style: Theme.of(context).textTheme.titleSmall),
          for (var k = 0; k < options.length; k++)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(children: [
                Icon(k == correct ? Icons.check_circle : Icons.circle_outlined, size: 18, color: k == correct ? Colors.green : null),
                const SizedBox(width: 8),
                Expanded(child: Text(options[k])),
              ]),
            ),
        ]),
      ),
    );
  }
}

/// The teacher's view of an exam's ranking.
class AdminBoardScreen extends StatelessWidget {
  const AdminBoardScreen({super.key, required this.api, required this.examId});
  final Api api;
  final int examId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('মেধাতালিকা')),
      body: LoadView<Map<String, dynamic>>(
        load: () => api.adminLeaderboard(examId),
        builder: (context, d, reload) {
          final rows = (d['rows'] as List).cast<Map<String, dynamic>>();
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(12),
              children: [
                Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('মোট অংশগ্রহণ ${bn(d['participants'])} জন')),
                for (final r in rows)
                  boardRow(context, rank: r['rank'] as int, name: r['name'] as String, roll: r['roll'] as String, marks_: r['marks'] as num, timeSec: r['timeSec'] as int, me: false,
                      extra: 'সঠিক ${bn(r['correct'])} · ভুল ${bn(r['wrong'])}'),
              ],
            ),
          );
        },
      ),
    );
  }
}
