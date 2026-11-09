import 'package:flutter/material.dart';

import '../../api.dart';
import '../../bn.dart';
import '../../messages.dart';
import 'widgets.dart';

/// Classes and their sections, with add buttons. (Rename and delete are on the website.)
class ClassesTab extends StatelessWidget {
  const ClassesTab({super.key, required this.api});
  final Api api;

  @override
  Widget build(BuildContext context) {
    return LoadView<List<Map<String, dynamic>>>(
      load: api.classes,
      builder: (context, classes, reload) => Scaffold(
        floatingActionButton: FloatingActionButton.extended(
          icon: const Icon(Icons.add),
          label: const Text('নতুন শ্রেণি'),
          onPressed: () async {
            final name = await promptText(context, 'নতুন শ্রেণি', label: 'শ্রেণির নাম (যেমন নবম)');
            if (name == null || name.isEmpty) return;
            try {
              await api.createClass(name);
              await reload();
            } catch (e) {
              if (context.mounted) showMessage(context, errorMessage(e));
            }
          },
        ),
        body: RefreshIndicator(
          onRefresh: reload,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
            children: [
              if (classes.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('এখনও কোনো শ্রেণি নেই। "নতুন শ্রেণি" চাপুন।')),
              for (final c in classes)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(c['name'] as String, style: Theme.of(context).textTheme.titleMedium),
                      Text('শিক্ষার্থী ${bn(c['studentCount'])} · পরীক্ষা ${bn(c['examCount'])}'),
                      const SizedBox(height: 6),
                      Wrap(spacing: 6, runSpacing: 4, children: [
                        for (final s in (c['sections'] as List).cast<Map<String, dynamic>>()) Chip(label: Text('${s['name']} (${bn(s['studentCount'])})')),
                        ActionChip(
                          avatar: const Icon(Icons.add, size: 18),
                          label: const Text('শাখা'),
                          onPressed: () async {
                            final name = await promptText(context, '${c['name']}: নতুন শাখা', label: 'শাখার নাম');
                            if (name == null || name.isEmpty) return;
                            try {
                              await api.createSection(c['id'] as int, name);
                              await reload();
                            } catch (e) {
                              if (context.mounted) showMessage(context, errorMessage(e));
                            }
                          },
                        ),
                      ]),
                    ]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
