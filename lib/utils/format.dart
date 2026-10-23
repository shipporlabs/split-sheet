const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String two(int n) => n.toString().padLeft(2, '0');

String fmtDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

String fmtTime(DateTime d) => '${two(d.hour)}:${two(d.minute)}';

String fmtDateTime(DateTime d) => '${fmtDate(d)}, ${fmtTime(d)}';

String isoDate(DateTime d) => '${d.year}-${two(d.month)}-${two(d.day)}';

String relDay(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  return fmtDate(d);
}

/// Basis points to a percentage without trailing zeros: 3500 -> "35", 3333 -> "33.33".
String fmtPctPlain(int bps) {
  if (bps % 100 == 0) return '${bps ~/ 100}';
  var s = (bps / 100).toStringAsFixed(2);
  if (s.endsWith('0')) s = s.substring(0, s.length - 1);
  return s;
}

String fmtPct(int bps) => '${fmtPctPlain(bps)}%';

/// USDC has 6 decimals; amounts are kept as integer micro-units.
String fmtUsdc(int micros) {
  final neg = micros < 0;
  final cents = (micros.abs() + 5000) ~/ 10000;
  final whole = (cents ~/ 100).toString();
  final buf = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    if (i > 0 && (whole.length - i) % 3 == 0) buf.write(',');
    buf.write(whole[i]);
  }
  return '${neg ? '-' : ''}$buf.${two(cents % 100)}';
}

/// Parses "1,250.50" into micro-units. Returns null when invalid.
int? parseUsdc(String text) {
  final d = double.tryParse(text.replaceAll(',', '').trim());
  if (d == null || d.isNaN || d.isInfinite) return null;
  return (d * 1000000).round();
}

String shortHex(String? h, {int head = 6, int tail = 4}) {
  if (h == null || h.isEmpty) return '-';
  if (h.length <= head + tail + 1) return h;
  return '${h.substring(0, head)}…${h.substring(h.length - tail)}';
}

/// "9b1c 4e07 d2a8 … 77f0 a2f1"
String groupedHash(String? h) {
  if (h == null || h.isEmpty) return '-';
  final s = h.startsWith('0x') ? h.substring(2) : h;
  if (s.length < 24) return s;
  String g(String x) {
    final parts = <String>[];
    for (var i = 0; i < x.length; i += 4) {
      parts.add(x.substring(i, i + 4 > x.length ? x.length : i + 4));
    }
    return parts.join(' ');
  }

  return '${g(s.substring(0, 12))} … ${g(s.substring(s.length - 8))}';
}

String initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
}

String firstName(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  return parts.isEmpty || parts.first.isEmpty ? name : parts.first;
}

String greeting() {
  final h = DateTime.now().hour;
  if (h < 12) return 'Good morning';
  if (h < 17) return 'Good afternoon';
  return 'Good evening';
}

String slug(String s) {
  final out = s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  return out.replaceAll(RegExp(r'^-+|-+$'), '');
}

String fmtBytes(int? b) {
  if (b == null) return '';
  if (b >= 1024 * 1024) return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
  if (b >= 1024) return '${(b / 1024).toStringAsFixed(0)} KB';
  return '$b B';
}
