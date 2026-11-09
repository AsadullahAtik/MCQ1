/// Bengali digits for numbers shown to students. NEVER use this for passwords or ids that must be typed back.
const _digits = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];

String bn(Object? value) {
  final s = value.toString();
  final out = StringBuffer();
  for (final unit in s.codeUnits) {
    if (unit >= 0x30 && unit <= 0x39) {
      out.write(_digits[unit - 0x30]);
    } else {
      out.writeCharCode(unit);
    }
  }
  return out.toString();
}

/// 3725 -> "১:০২:০৫" ; 125 -> "০২:০৫"
String clock(int seconds) {
  final s = seconds < 0 ? 0 : seconds;
  final h = s ~/ 3600;
  final m = (s % 3600) ~/ 60;
  final sec = s % 60;
  String two(int n) => n.toString().padLeft(2, '0');
  return bn(h > 0 ? '$h:${two(m)}:${two(sec)}' : '${two(m)}:${two(sec)}');
}

/// 72.5 -> "৭২.৫", 3.0 -> "৩"
String marks(num value) {
  final r = (value * 100).round() / 100;
  return bn(r == r.roundToDouble() ? r.round().toString() : r.toString());
}
