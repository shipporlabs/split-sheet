import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../utils/splits.dart';
import 'hashing.dart';

class ChainException implements Exception {
  ChainException(this.message);
  final String message;
  @override
  String toString() => message;
}

class LedgerSignature {
  const LedgerSignature({required this.wallet, required this.signature, required this.at, required this.txHash});
  final String wallet;
  final String signature;
  final DateTime at;
  final String txHash;
}

class LedgerEvent {
  const LedgerEvent({required this.type, required this.at, required this.txHash, this.detail = ''});
  final String type;
  final DateTime at;
  final String txHash;
  final String detail;
}

/// What the chain knows about a sheet: hashes, shares and signatures. No names.
class LedgerRecord {
  LedgerRecord({
    required this.sheetId,
    required this.docHash,
    required this.audioHash,
    required this.previousId,
    required this.partyCount,
    required this.compositionBps,
    required this.masterBps,
    required this.status,
    required this.signatures,
    required this.events,
  });

  final String sheetId;
  final String docHash;
  final String? audioHash;
  final String? previousId;
  final int partyCount;
  final List<int> compositionBps;
  final List<int> masterBps;
  String status;
  final Map<int, LedgerSignature> signatures;
  final List<LedgerEvent> events;

  Map<String, dynamic> toJson() => {
        'sheetId': sheetId,
        'docHash': docHash,
        'audioHash': audioHash,
        'previousId': previousId,
        'partyCount': partyCount,
        'compositionBps': compositionBps,
        'masterBps': masterBps,
        'status': status,
        'signatures': [
          for (final e in signatures.entries)
            {
              'index': e.key,
              'wallet': e.value.wallet,
              'signature': e.value.signature,
              'at': e.value.at.toUtc().toIso8601String(),
              'txHash': e.value.txHash,
            }
        ],
        'events': [
          for (final e in events)
            {'type': e.type, 'at': e.at.toUtc().toIso8601String(), 'txHash': e.txHash, 'detail': e.detail}
        ],
      };

  factory LedgerRecord.fromJson(Map<String, dynamic> j) {
    int n(Object? v) => (v as num).toInt();
    final sigs = <int, LedgerSignature>{};
    for (final raw in (j['signatures'] as List)) {
      final s = Map<String, dynamic>.from(raw as Map);
      sigs[n(s['index'])] = LedgerSignature(
        wallet: s['wallet'] as String,
        signature: s['signature'] as String,
        at: DateTime.parse(s['at'] as String).toLocal(),
        txHash: s['txHash'] as String,
      );
    }
    return LedgerRecord(
      sheetId: j['sheetId'] as String,
      docHash: j['docHash'] as String,
      audioHash: j['audioHash'] as String?,
      previousId: j['previousId'] as String?,
      partyCount: n(j['partyCount']),
      compositionBps: (j['compositionBps'] as List).map(n).toList(),
      masterBps: (j['masterBps'] as List).map(n).toList(),
      status: j['status'] as String,
      signatures: sigs,
      events: [
        for (final raw in (j['events'] as List))
          () {
            final e = Map<String, dynamic>.from(raw as Map);
            return LedgerEvent(
              type: e['type'] as String,
              at: DateTime.parse(e['at'] as String).toLocal(),
              txHash: e['txHash'] as String,
              detail: (e['detail'] ?? '') as String,
            );
          }(),
      ],
    );
  }

  /// Applies the contract's rules for a new signature. Returns true when this was the last one.
  bool addSignature(int partyIndex, LedgerSignature sig, String docHash) {
    if (status != 'pending') throw ChainException('This sheet is no longer open for signing');
    if (this.docHash != docHash) throw ChainException('You are signing different terms from the recorded version');
    if (partyIndex < 0 || partyIndex >= partyCount) throw ChainException('Not a party to this sheet');
    if (signatures.containsKey(partyIndex)) throw ChainException('Already signed');
    signatures[partyIndex] = sig;
    events.add(LedgerEvent(type: 'Signed', at: sig.at, txHash: sig.txHash, detail: 'party $partyIndex'));
    if (signatures.length == partyCount) {
      status = 'executed';
      events.add(LedgerEvent(type: 'Executed', at: sig.at, txHash: sig.txHash));
      return true;
    }
    return false;
  }
}

void validateNewSheet(int partyCount, List<int> compositionBps, List<int> masterBps) {
  if (partyCount < 2) throw ChainException('A sheet needs at least two parties');
  if (compositionBps.length != partyCount || masterBps.length != partyCount) {
    throw ChainException('Every party needs a share on both splits');
  }
  if (sumBps(compositionBps) != fullBps || sumBps(masterBps) != fullBps) {
    throw ChainException('Each split must total exactly 100%');
  }
}

/// Mirrors the SplitRegistry contract interface in the PRD.
/// Replace [MockChainService] with an EVM implementation without touching the UI.
abstract class ChainService {
  String get networkName;

  Future<String> createSheet({
    required String sheetId,
    required String docHash,
    required String? audioHash,
    required String? previousId,
    required int partyCount,
    required List<int> compositionBps,
    required List<int> masterBps,
  });

  Future<String> sign({
    required String sheetId,
    required int partyIndex,
    required String wallet,
    required String signature,
    required String docHash,
  });

  Future<String> cancel(String sheetId);

  Future<String> deposit({required String sheetId, required SplitType splitType, required int amountMicros});

  Future<LedgerRecord?> getSheet(String sheetId);

  Future<void> reset();
}

/// Local, persistent stand-in for the chain. Enforces the same rules the contract will.
class MockChainService implements ChainService {
  MockChainService({this.latency = const Duration(milliseconds: 650)});

  static const _key = 'ss_mock_ledger_v1';
  Duration latency;
  Map<String, LedgerRecord>? _cache;

  @override
  String get networkName => 'Mock chain (testnet stand-in)';

  Future<Map<String, LedgerRecord>> _load() async {
    if (_cache != null) return _cache!;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    final map = <String, LedgerRecord>{};
    if (raw != null) {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      decoded.forEach((k, v) => map[k] = LedgerRecord.fromJson(v as Map<String, dynamic>));
    }
    _cache = map;
    return map;
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final map = _cache ?? <String, LedgerRecord>{};
    await prefs.setString(_key, jsonEncode(map.map((k, v) => MapEntry(k, v.toJson()))));
  }

  Future<void> _wait() async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
  }

  String _tx() => '0x${randomHex(32)}';

  @override
  Future<String> createSheet({
    required String sheetId,
    required String docHash,
    required String? audioHash,
    required String? previousId,
    required int partyCount,
    required List<int> compositionBps,
    required List<int> masterBps,
  }) async {
    await _wait();
    final ledger = await _load();
    if (ledger.containsKey(sheetId)) throw ChainException('Sheet already exists');
    validateNewSheet(partyCount, compositionBps, masterBps);
    final tx = _tx();
    ledger[sheetId] = LedgerRecord(
      sheetId: sheetId,
      docHash: docHash,
      audioHash: audioHash,
      previousId: previousId,
      partyCount: partyCount,
      compositionBps: List.of(compositionBps),
      masterBps: List.of(masterBps),
      status: 'pending',
      signatures: <int, LedgerSignature>{},
      events: [LedgerEvent(type: 'SheetCreated', at: DateTime.now(), txHash: tx)],
    );
    await _save();
    return tx;
  }

  @override
  Future<String> sign({
    required String sheetId,
    required int partyIndex,
    required String wallet,
    required String signature,
    required String docHash,
  }) async {
    await _wait();
    final ledger = await _load();
    final r = ledger[sheetId];
    if (r == null) throw ChainException('Sheet not found');
    final now = DateTime.now();
    final tx = _tx();
    final done = r.addSignature(partyIndex, LedgerSignature(wallet: wallet, signature: signature, at: now, txHash: tx), docHash);
    if (done) {
      final prev = r.previousId == null ? null : ledger[r.previousId!];
      if (prev != null && prev.status == 'executed') {
        prev.status = 'superseded';
        prev.events.add(LedgerEvent(type: 'Superseded', at: now, txHash: tx, detail: sheetId));
      }
    }
    await _save();
    return tx;
  }

  @override
  Future<String> cancel(String sheetId) async {
    await _wait();
    final ledger = await _load();
    final r = ledger[sheetId];
    if (r == null) throw ChainException('Sheet not found');
    if (r.status != 'pending') throw ChainException('Only an unsigned sheet can be cancelled');
    final tx = _tx();
    r.status = 'cancelled';
    r.events.add(LedgerEvent(type: 'Cancelled', at: DateTime.now(), txHash: tx));
    await _save();
    return tx;
  }

  @override
  Future<String> deposit({required String sheetId, required SplitType splitType, required int amountMicros}) async {
    await _wait();
    final ledger = await _load();
    final r = ledger[sheetId];
    if (r == null) throw ChainException('Sheet not found');
    if (r.status != 'executed') throw ChainException('Royalties can only be paid into a fully signed sheet');
    if (amountMicros <= 0) throw ChainException('Enter an amount above zero');
    final tx = _tx();
    r.events.add(LedgerEvent(type: 'PaidOut', at: DateTime.now(), txHash: tx, detail: '${splitType.name}:$amountMicros'));
    await _save();
    return tx;
  }

  @override
  Future<LedgerRecord?> getSheet(String sheetId) async {
    final ledger = await _load();
    return ledger[sheetId];
  }

  @override
  Future<void> reset() async {
    _cache = <String, LedgerRecord>{};
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
