import 'package:flutter/material.dart';

import '../../api.dart';
import '../../bn.dart';
import '../../messages.dart';
import 'widgets.dart';

class _QuestionEditor {
  final body = TextEditingController();
  final options = List.generate(4, (_) => TextEditingController());
  int correct = 0;

  bool get complete => body.text.trim().isNotEmpty && options.every((o) => o.text.trim().isNotEmpty);

  Map<String, dynamic> toJson() => {
        'body': body.text.trim(),
        'options': options.map((o) => o.text.trim()).toList(),
        'correctIdx': correct,
      };
}

/// Create an exam with its questions. It starts as a draft: it is released to students from the exam's own page.
class ExamFormScreen extends StatefulWidget {
  const ExamFormScreen({super.key, required this.api});
  final Api api;

  @override
  State<ExamFormScreen> createState() => _ExamFormScreenState();
}

class _ExamFormScreenState extends State<ExamFormScreen> {
  final title = TextEditingController();
  final duration = TextEditingController(text: '30');
  final perQuestion = TextEditingController(text: '1');
  final negative = TextEditingController(text: '0.25');
  final questions = <_QuestionEditor>[_QuestionEditor()];
  List<Map<String, dynamic>>? classes;
  int? classId;
  String? error;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    widget.api.classes().then((c) {
      if (mounted) {
        setState(() {
          classes = c;
          if (c.isNotEmpty) classId = c.first['id'] as int;
        });
      }
    }).catchError((Object e) {
      if (mounted) setState(() => error = errorMessage(e));
    });
  }

  Future<void> save() async {
    final d = int.tryParse(duration.text.trim());
    final m = double.tryParse(perQuestion.text.trim());
    final n = double.tryParse(negative.text.trim());
    String? problem;
    if (title.text.trim().length < 3) {
      problem = 'পরীক্ষার নাম অন্তত ৩ অক্ষরের হতে হবে';
    } else if (classId == null) {
      problem = 'আগে একটি শ্রেণি তৈরি করুন';
    } else if (d == null || d < 1) {
      problem = 'সময় (মিনিট) ১ বা তার বেশি হতে হবে';
    } else if (m == null || m <= 0) {
      problem = 'প্রতি প্রশ্নের নম্বর ০ এর বেশি হতে হবে';
    } else if (n == null || n < 0) {
      problem = 'ভুলে কাটা নম্বর ০ বা তার বেশি হতে হবে';
    } else if (questions.any((q) => !q.complete)) {
      problem = 'প্রতিটি প্রশ্নে প্রশ্ন ও চারটি অপশনই লিখুন';
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
      await widget.api.createExam({
        'title': title.text.trim(),
        'classId': classId,
        'durationMinutes': d,
        'marksPerQuestion': m,
        'negativeMarks': n,
        'questions': questions.map((q) => q.toJson()).toList(),
      });
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
      appBar: AppBar(title: const Text('নতুন পরীক্ষা')),
      body: classes == null && error == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                field(title, 'পরীক্ষার নাম'),
                if (classes != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: DropdownButtonFormField<int>(
                      initialValue: classId,
                      decoration: const InputDecoration(labelText: 'শ্রেণি', border: OutlineInputBorder()),
                      items: [for (final c in classes!) DropdownMenuItem(value: c['id'] as int, child: Text(c['name'] as String))],
                      onChanged: (v) => setState(() => classId = v),
                    ),
                  ),
                Row(children: [
                  Expanded(child: field(duration, 'সময় (মিনিট)', number: true)),
                  const SizedBox(width: 8),
                  Expanded(child: field(perQuestion, 'প্রতি প্রশ্নে নম্বর', number: true)),
                ]),
                field(negative, 'ভুল উত্তরে কাটা নম্বর', number: true),
                const Divider(),
                for (var i = 0; i < questions.length; i++) _editor(i),
                OutlinedButton.icon(onPressed: () => setState(() => questions.add(_QuestionEditor())), icon: const Icon(Icons.add), label: const Text('আরেকটি প্রশ্ন')),
                if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
                const SizedBox(height: 12),
                FilledButton(onPressed: busy ? null : save, child: Text(busy ? 'সংরক্ষণ হচ্ছে…' : 'খসড়া হিসেবে সংরক্ষণ করুন')),
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  Widget _editor(int i) {
    final q = questions[i];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('প্রশ্ন ${bn(i + 1)}', style: Theme.of(context).textTheme.titleSmall)),
            if (questions.length > 1) IconButton(tooltip: 'প্রশ্নটি বাদ দিন', icon: const Icon(Icons.delete_outline), onPressed: () => setState(() => questions.removeAt(i))),
          ]),
          field(q.body, 'প্রশ্ন'),
          for (var k = 0; k < 4; k++)
            Row(children: [
              IconButton(
                tooltip: 'এটাই সঠিক উত্তর',
                icon: Icon(q.correct == k ? Icons.check_circle : Icons.circle_outlined, color: q.correct == k ? Colors.green : null),
                onPressed: () => setState(() => q.correct = k),
              ),
              Expanded(child: field(q.options[k], 'অপশন ${['ক', 'খ', 'গ', 'ঘ'][k]}')),
            ]),
          const Text('সঠিক উত্তরের পাশের গোল চিহ্ন চাপুন (সবুজ টিক মানে সঠিক)।', style: TextStyle(fontSize: 12)),
        ]),
      ),
    );
  }
}
