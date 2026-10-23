import 'dart:collection';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import '../models/models.dart';

dynamic _canon(dynamic v) {
  if (v is Map) {
    final m = SplayTreeMap<String, dynamic>();
    v.forEach((k, val) => m[k.toString()] = _canon(val));
    return m;
  }
  if (v is List) return v.map(_canon).toList();
  return v;
}

/// Keys sorted at every level, no whitespace. The app and the verify page must use this same routine.
String canonicalJson(Map<String, dynamic> m) => jsonEncode(_canon(m));

/// Top-level so it can run through `compute`.
String sha256Hex(List<int> bytes) => sha256.convert(bytes).toString();

String sha256Of(String s) => sha256Hex(utf8.encode(s));

/// Hash of the signed terms. The real contract would use keccak256 over the same canonical JSON.
String computeDocHash(SplitSheet s) => '0x${sha256Of(canonicalJson(s.canonicalTerms()))}';

final Random _rng = Random.secure();

String randomHex(int bytes) =>
    List.generate(bytes, (_) => _rng.nextInt(256).toRadixString(16).padLeft(2, '0')).join();

/// Short invite code such as "LGS-7Q4K" (no 0/O/1/I to avoid confusion when read aloud).
String randomCode() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  String pick(int n) => List.generate(n, (_) => chars[_rng.nextInt(chars.length)]).join();
  return '${pick(3)}-${pick(4)}';
}

/// Finds an invite code inside a scanned link or typed text.
String? extractInviteCode(String raw) {
  final m = RegExp(r'([A-Z0-9]{3}-[A-Z0-9]{4})').firstMatch(raw.toUpperCase());
  return m?.group(1);
}
