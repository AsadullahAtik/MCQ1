import 'package:flutter/material.dart';

import '../../messages.dart';

/// Loads once (and again on demand); shows a spinner, the error with a retry button, or the content.
/// `builder` also receives `reload`, to refresh after the user changed something or pulled down.
class LoadView<T> extends StatefulWidget {
  const LoadView({super.key, required this.load, required this.builder});

  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data, Future<void> Function() reload) builder;

  @override
  State<LoadView<T>> createState() => LoadViewState<T>();
}

class LoadViewState<T> extends State<LoadView<T>> {
  T? data;
  String? error;

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
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
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(error!, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            FilledButton(onPressed: reload, child: const Text('আবার চেষ্টা')),
          ]),
        ),
      );
    }
    if (data == null) return const Center(child: CircularProgressIndicator());
    return widget.builder(context, data as T, reload);
  }
}

void showMessage(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

Future<bool> confirmDialog(BuildContext context, String title, String body, {String yes = 'হ্যাঁ'}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('না')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(yes)),
      ],
    ),
  );
  return r == true;
}

/// A password that is shown ONCE (after creating or resetting an account). Plain ASCII, selectable so it can be copied.
Future<void> showSecret(BuildContext context, {required String title, String? loginId, required String password}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (loginId != null) ...[const Text('লগইন আইডি / রোল'), SelectableText(loginId, style: Theme.of(c).textTheme.titleMedium), const SizedBox(height: 8)],
        const Text('পাসওয়ার্ড'),
        SelectableText(password, style: Theme.of(c).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text('এই পাসওয়ার্ড শুধু এখন একবার দেখানো হচ্ছে। এখনই জানিয়ে দিন।'),
      ]),
      actions: [FilledButton(onPressed: () => Navigator.pop(c), child: const Text('ঠিক আছে'))],
    ),
  );
}

/// One text prompt (new class name, new section name ...). Returns null when cancelled.
Future<String?> promptText(BuildContext context, String title, {String label = 'নাম'}) {
  final ctrl = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: TextField(controller: ctrl, autofocus: true, decoration: InputDecoration(labelText: label)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('বাদ')),
        FilledButton(onPressed: () => Navigator.pop(c, ctrl.text.trim()), child: const Text('ঠিক আছে')),
      ],
    ),
  );
}

Widget field(TextEditingController c, String label, {bool number = false, bool obscure = false, String? helper}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: c,
      obscureText: obscure,
      keyboardType: number ? TextInputType.number : TextInputType.text,
      autocorrect: false,
      decoration: InputDecoration(labelText: label, helperText: helper, border: const OutlineInputBorder()),
    ),
  );
}
