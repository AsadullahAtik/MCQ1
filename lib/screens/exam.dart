import 'dart:async';

import 'package:flutter/material.dart';

import '../api.dart';
import '../bn.dart';
import '../messages.dart';

/// Taking one exam. The SERVER owns the clock: we only count down from the seconds it reported when the paper was
/// opened. Answers are pushed to the server as drafts (1.5 s after each change), so a dead phone loses nothing:
/// the server submits the draft by itself when time runs out.
class ExamScreen extends StatefulWidget {
  const ExamScreen({super.key, required this.api, required this.examId, required this.title});

  final Api api;
  final int examId;
  final String title;

  @override
  State<ExamScreen> createState() => _ExamScreenState();
}

class _ExamScreenState extends State<ExamScreen> {
  Map<String, dynamic>? paper;
  String? error;
  List<int?> answers = [];
  int current = 0;
  int remaining = 0;
  final clock0 = Stopwatch();
  int remainingAtStart = 0;
  Timer? ticker;
  Timer? draftTimer;
  bool draftDirty = false;
  bool submitting = false;
  bool timeUp = false;

  @override
  void initState() {
    super.initState();
    open();
  }

  @override
  void dispose() {
    ticker?.cancel();
    draftTimer?.cancel();
    super.dispose();
  }

  Future<void> open() async {
    try {
      final p = await widget.api.start(widget.examId);
      final qs = (p['questions'] as List).length;
      final saved = (p['savedAnswers'] as List?)?.cast<int?>() ?? const <int?>[];
      if (!mounted) return;
      setState(() {
        paper = p;
        answers = List<int?>.generate(qs, (i) => i < saved.length ? saved[i] : null);
        remainingAtStart = p['remainingSeconds'] as int;
        remaining = remainingAtStart;
      });
      clock0.start();
      ticker = Timer.periodic(const Duration(seconds: 1), (_) => tick());
    } catch (e) {
      if (mounted) setState(() => error = errorMessage(e));
    }
  }

  void tick() {
    final left = remainingAtStart - clock0.elapsed.inSeconds;
    if (!mounted) return;
    setState(() => remaining = left < 0 ? 0 : left);
    if (left <= 0 && !timeUp && !submitting) {
      timeUp = true;
      submit(auto: true);
    } else if (draftDirty && draftTimer == null) {
      scheduleDraft(); // a previous push failed: try again
    }
  }

  void choose(int q, int option) {
    setState(() => answers[q] = answers[q] == option ? null : option); // tapping the chosen option again clears it
    draftDirty = true;
    scheduleDraft();
  }

  void scheduleDraft() {
    draftTimer?.cancel();
    draftTimer = Timer(const Duration(milliseconds: 1500), () async {
      draftTimer = null;
      final snapshot = List<int?>.from(answers);
      try {
        await widget.api.saveDraft(widget.examId, snapshot);
        if (_same(snapshot, answers)) draftDirty = false;
      } catch (_) {
        // keep draftDirty = true: the ticker retries within a second
      }
    });
  }

  bool _same(List<int?> a, List<int?> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  int get answered => answers.where((a) => a != null).length;

  Future<void> submit({bool auto = false}) async {
    if (submitting) return;
    if (!auto) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('জমা দেবেন?'),
          content: Text('${bn(answered)}টি উত্তর দিয়েছেন, ${bn(answers.length - answered)}টি বাকি। জমা দিলে আর বদলানো যাবে না।'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('না, ফিরে যাই')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('জমা দিন')),
          ],
        ),
      );
      if (ok != true) return;
    }
    setState(() => submitting = true);
    draftTimer?.cancel();
    try {
      await widget.api.submit(widget.examId, answers);
      ticker?.cancel();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (c) => AlertDialog(
          title: Text(auto ? 'সময় শেষ, জমা হয়েছে' : 'জমা হয়েছে'),
          content: const Text('শিক্ষক ফলাফল প্রকাশ করলে এখান থেকেই দেখতে পাবেন।'),
          actions: [FilledButton(onPressed: () => Navigator.pop(c), child: const Text('ঠিক আছে'))],
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => submitting = false);
      // ALREADY_SUBMITTED means the server auto-submitted the saved draft: nothing is lost, just leave.
      if (e is ApiException && e.code == 'ALREADY_SUBMITTED') {
        Navigator.of(context).pop();
        return;
      }
      timeUp = false;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return Scaffold(appBar: AppBar(title: Text(widget.title)), body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(error!, textAlign: TextAlign.center))));
    }
    if (paper == null) return Scaffold(appBar: AppBar(title: Text(widget.title)), body: const Center(child: CircularProgressIndicator()));

    final questions = (paper!['questions'] as List).cast<Map<String, dynamic>>();
    final q = questions[current];
    final options = (q['options'] as List).cast<String>();
    final low = remaining <= 60;
    return PopScope(
      canPop: false, // leaving mid-exam must be a deliberate act: the timer keeps running on the server anyway
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = Navigator.of(context); // taken BEFORE the awaits: a BuildContext must not be used after an async gap
        final leave = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('বাইরে যাবেন?'),
            content: const Text('সময় থামবে না। পরে ফিরে এসে আপনার উত্তরগুলো সহ চালিয়ে যেতে পারবেন, তবে সময় শেষ হলে সেভ করা উত্তর নিজে থেকে জমা হয়ে যাবে।'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('থাকি')),
              FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('বাইরে যাই')),
            ],
          ),
        );
        if (leave == true) {
          if (draftDirty) {
            try {
              await widget.api.saveDraft(widget.examId, answers);
            } catch (_) {}
          }
          nav.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.title, overflow: TextOverflow.ellipsis),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(clock(remaining),
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: low ? Theme.of(context).colorScheme.error : null)),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            LinearProgressIndicator(value: answers.isEmpty ? 0 : answered / answers.length),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text('প্রশ্ন ${bn(current + 1)} / ${bn(questions.length)} · উত্তর দেওয়া ${bn(answered)}টি'),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  Text(q['body'] as String, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  for (var i = 0; i < options.length; i++)
                    Card(
                      color: answers[current] == i ? Theme.of(context).colorScheme.primaryContainer : null,
                      child: ListTile(
                        leading: CircleAvatar(radius: 14, child: Text(['ক', 'খ', 'গ', 'ঘ'][i % 4])),
                        title: Text(options[i]),
                        onTap: submitting ? null : () => choose(current, i),
                      ),
                    ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    OutlinedButton(onPressed: current > 0 ? () => setState(() => current--) : null, child: const Text('আগের')),
                    const SizedBox(width: 8),
                    if (current < questions.length - 1)
                      FilledButton.tonal(onPressed: () => setState(() => current++), child: const Text('পরের'))
                    else
                      const SizedBox.shrink(),
                    const Spacer(),
                    FilledButton(onPressed: submitting ? null : () => submit(), child: const Text('জমা দিন')),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
