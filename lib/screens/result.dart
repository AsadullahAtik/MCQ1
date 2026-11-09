import 'package:flutter/material.dart';

import '../api.dart';
import '../bn.dart';
import '../messages.dart';
import 'board.dart';

/// My result for one published exam: score, rank, and every question with the right answer.
class ResultScreen extends StatefulWidget {
  const ResultScreen({super.key, required this.api, required this.examId});
  final Api api;
  final int examId;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  Map<String, dynamic>? data;
  String? error;

  @override
  void initState() {
    super.initState();
    widget.api.result(widget.examId).then((r) {
      if (mounted) setState(() => data = r);
    }).catchError((Object e) {
      if (mounted) setState(() => error = errorMessage(e));
    });
  }

  @override
  Widget build(BuildContext context) {
    final d = data;
    return Scaffold(
      appBar: AppBar(title: Text(d == null ? 'ফলাফল' : (d['exam'] as Map)['title'] as String)),
      body: error != null
          ? Center(child: Text(error!))
          : d == null
              ? const Center(child: CircularProgressIndicator())
              : _body(context, d),
    );
  }

  Widget _body(BuildContext context, Map<String, dynamic> d) {
    final exam = d['exam'] as Map<String, dynamic>;
    final score = d['score'] as Map<String, dynamic>;
    final review = (d['review'] as List).cast<Map<String, dynamic>>();
    final cs = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              Text('${marks(score['marks'] as num)} / ${marks(exam['fullMarks'] as num)}', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 4),
              Text('মেধাক্রম ${bn(d['rank'])} (মোট ${bn(d['participants'])} জনের মধ্যে)'),
              const SizedBox(height: 8),
              Text('সঠিক ${bn(score['correct'])} · ভুল ${bn(score['wrong'])} · ফাঁকা ${bn(score['blank'])}'),
              if ((score['bonus'] as num) > 0) Text('বোনাস ${marks(score['bonus'] as num)}'),
              Text('সময় ${clock(score['timeSec'] as int)}'),
            ]),
          ),
        ),
        OutlinedButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ExamBoardScreen(api: widget.api, examId: widget.examId))),
          child: const Text('এই পরীক্ষার মেধাতালিকা'),
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < review.length; i++) _reviewCard(context, i, review[i], cs),
      ],
    );
  }

  Widget _reviewCard(BuildContext context, int i, Map<String, dynamic> r, ColorScheme cs) {
    final options = (r['options'] as List).cast<String>();
    final correct = r['correctIdx'] as int;
    final chosen = r['chosenIdx'] as int?;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${bn(i + 1)}. ${r['body']}', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          for (var k = 0; k < options.length; k++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(children: [
                Icon(k == correct ? Icons.check_circle : (k == chosen ? Icons.cancel : Icons.circle_outlined),
                    size: 18, color: k == correct ? Colors.green : (k == chosen ? cs.error : null)),
                const SizedBox(width: 8),
                Expanded(child: Text(options[k])),
              ]),
            ),
          if (chosen == null) const Text('উত্তর দেননি', style: TextStyle(fontStyle: FontStyle.italic)),
        ]),
      ),
    );
  }
}
