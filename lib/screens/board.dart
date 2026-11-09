import 'package:flutter/material.dart';

import '../api.dart';
import '../bn.dart';
import '../messages.dart';

/// One row of a leaderboard (my own row is highlighted).
Widget boardRow(BuildContext context, {required int rank, required String name, required String roll, required num marks_, required int timeSec, required bool me, String? extra}) {
  final cs = Theme.of(context).colorScheme;
  return Card(
    color: me ? cs.primaryContainer : null,
    child: ListTile(
      leading: CircleAvatar(child: Text(bn(rank))),
      title: Text(me ? '$name (আপনি)' : name),
      subtitle: Text('রোল $roll · ${clock(timeSec)}${extra == null ? '' : ' · $extra'}'),
      trailing: Text(marks(marks_), style: Theme.of(context).textTheme.titleMedium),
    ),
  );
}

class ExamBoardScreen extends StatelessWidget {
  const ExamBoardScreen({super.key, required this.api, required this.examId});
  final Api api;
  final int examId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('মেধাতালিকা')),
      body: _Loader<Map<String, dynamic>>(
        load: () => api.leaderboard(examId),
        builder: (context, d, reload) {
          final rows = (d['rows'] as List).cast<Map<String, dynamic>>();
          return ListView(padding: const EdgeInsets.all(12), children: [
            Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('মোট অংশগ্রহণ ${bn(d['participants'])} জন')),
            for (final r in rows)
              boardRow(context, rank: r['rank'] as int, name: r['name'] as String, roll: r['roll'] as String, marks_: r['marks'] as num,
                  timeSec: r['timeSec'] as int, me: r['me'] == true),
          ]);
        },
      ),
    );
  }
}

/// The class's overall ranking across all published exams.
class OverallBoardView extends StatelessWidget {
  const OverallBoardView({super.key, required this.api});
  final Api api;

  @override
  Widget build(BuildContext context) {
    return _Loader<Map<String, dynamic>>(
      load: api.overall,
      builder: (context, d, reload) {
        final rows = (d['rows'] as List).cast<Map<String, dynamic>>();
        return RefreshIndicator(
          onRefresh: reload, // really reloads from the server (it used to be an empty function)
          child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(12), children: [
            Text('${d['className']} · সব পরীক্ষা মিলিয়ে (${bn(d['examCount'])}টি, পূর্ণমান ${marks(d['fullMarks'] as num)})'),
            const SizedBox(height: 8),
            if (rows.isEmpty) const Text('এখনও কোনো ফলাফল প্রকাশ হয়নি।'),
            for (final r in rows)
              boardRow(context, rank: r['rank'] as int, name: r['name'] as String, roll: r['roll'] as String, marks_: r['marks'] as num,
                  timeSec: r['timeSec'] as int, me: r['me'] == true, extra: '${bn(r['taken'])}টি পরীক্ষা'),
          ]),
        );
      },
    );
  }
}

/// Small helper: load once, show a spinner / the error with a retry / the content.
class _Loader<T> extends StatefulWidget {
  const _Loader({required this.load, required this.builder});
  final Future<T> Function() load;
  /// builder gets the data and a reload function (for pull-to-refresh).
  final Widget Function(BuildContext, T, Future<void> Function()) builder;

  @override
  State<_Loader<T>> createState() => _LoaderState<T>();
}

class _LoaderState<T> extends State<_Loader<T>> {
  T? data;
  String? error;

  @override
  void initState() {
    super.initState();
    run();
  }

  Future<void> run() async {
    try {
      final d = await widget.load();
      if (mounted) {
        setState(() {
          data = d;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = errorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(error!, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          FilledButton(onPressed: run, child: const Text('আবার চেষ্টা')),
        ]),
      );
    }
    if (data == null) return const Center(child: CircularProgressIndicator());
    return widget.builder(context, data as T, run);
  }
}
