import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/models.dart';
import 'chain_service.dart';
import 'hashing.dart';

/// The ledger kept in Firestore at `ledger/{sheetId}`, readable by anyone so the verify page
/// works without an account. Every change runs in a transaction and applies the same rules as
/// `contracts/SplitRegistry.sol`; firestore.rules blocks edits to hashes and shares.
///
/// This is a stand-in for the chain on the free Firebase plan. Swap it for an EVM
/// implementation of [ChainService] to anchor records on-chain.
class FirestoreChainService implements ChainService {
  FirestoreChainService(this.db);

  final FirebaseFirestore db;

  CollectionReference<Map<String, dynamic>> get _ledger => db.collection('ledger');

  @override
  String get networkName => 'Firestore ledger (testnet stand-in)';

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
    validateNewSheet(partyCount, compositionBps, masterBps);
    final ref = _ledger.doc(sheetId);
    final tx = _tx();
    await db.runTransaction((t) async {
      final snap = await t.get(ref);
      if (snap.exists) throw ChainException('Sheet already exists');
      final record = LedgerRecord(
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
      t.set(ref, record.toJson());
    });
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
    final ref = _ledger.doc(sheetId);
    final tx = _tx();
    await db.runTransaction((t) async {
      final snap = await t.get(ref);
      final data = snap.data();
      if (data == null) throw ChainException('Sheet not found on the ledger');
      final r = LedgerRecord.fromJson(data);

      // All reads happen before any write in a Firestore transaction.
      LedgerRecord? prev;
      DocumentReference<Map<String, dynamic>>? prevRef;
      final pid = r.previousId;
      if (pid != null) {
        prevRef = _ledger.doc(pid);
        final p = (await t.get(prevRef)).data();
        if (p != null) prev = LedgerRecord.fromJson(p);
      }

      final done = r.addSignature(
        partyIndex,
        LedgerSignature(wallet: wallet, signature: signature, at: DateTime.now(), txHash: tx),
        docHash,
      );
      t.set(ref, r.toJson());
      if (done && prev != null && prevRef != null && prev.status == 'executed') {
        prev.status = 'superseded';
        prev.events.add(LedgerEvent(type: 'Superseded', at: DateTime.now(), txHash: tx, detail: sheetId));
        t.set(prevRef, prev.toJson());
      }
    });
    return tx;
  }

  @override
  Future<String> cancel(String sheetId) async {
    final ref = _ledger.doc(sheetId);
    final tx = _tx();
    await db.runTransaction((t) async {
      final data = (await t.get(ref)).data();
      if (data == null) throw ChainException('Sheet not found on the ledger');
      final r = LedgerRecord.fromJson(data);
      if (r.status != 'pending') throw ChainException('Only an unsigned sheet can be cancelled');
      r.status = 'cancelled';
      r.events.add(LedgerEvent(type: 'Cancelled', at: DateTime.now(), txHash: tx));
      t.set(ref, r.toJson());
    });
    return tx;
  }

  @override
  Future<String> deposit({required String sheetId, required SplitType splitType, required int amountMicros}) async {
    if (amountMicros <= 0) throw ChainException('Enter an amount above zero');
    final ref = _ledger.doc(sheetId);
    final tx = _tx();
    await db.runTransaction((t) async {
      final data = (await t.get(ref)).data();
      if (data == null) throw ChainException('Sheet not found on the ledger');
      final r = LedgerRecord.fromJson(data);
      if (r.status != 'executed') throw ChainException('Royalties can only be paid into a fully signed sheet');
      r.events.add(LedgerEvent(type: 'PaidOut', at: DateTime.now(), txHash: tx, detail: '${splitType.name}:$amountMicros'));
      t.set(ref, r.toJson());
    });
    return tx;
  }

  @override
  Future<LedgerRecord?> getSheet(String sheetId) async {
    final snap = await _ledger.doc(sheetId).get();
    final data = snap.data();
    return data == null ? null : LedgerRecord.fromJson(data);
  }

  @override
  Future<void> reset() async {}
}
