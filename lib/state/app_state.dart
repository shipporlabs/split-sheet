import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/chain_service.dart';
import '../services/hashing.dart';
import '../services/signer.dart';
import '../utils/splits.dart';

/// App-wide state on Firebase (free Spark plan): email/password accounts, Firestore for sheets,
/// invites and payouts, and the ledger behind [chain].
///
/// Collections:
///   users/{uid}                 profile (owner only)
///   users/{uid}/private/keys    signing secret + PIN hash (owner only)
///   sheets/{sheetId}            signed terms + signatures; members only (pending: anyone with the ID)
///   invites/{code}              invite code -> sheet ID
///   ledger/{sheetId}            hashes, shares, signature times; public read
///   payouts/{payoutId}          royalty payments; members only
class AppState extends ChangeNotifier {
  AppState({required this.auth, required this.db, required this.chain});

  final FirebaseAuth auth;
  final FirebaseFirestore db;
  final ChainService chain;

  User? authUser;
  UserProfile? user;
  bool profileLoaded = false;
  List<SplitSheet> sheets = [];
  List<Payout> payouts = [];

  /// Where to go once sign-up finishes (for example an invite link opened while signed out).
  String? afterAuthPath;

  /// Short live messages ("Ada signed Lagos Summer") shown by the app shell.
  final ValueNotifier<String?> toast = ValueNotifier<String?>(null);

  StreamSubscription<User?>? _authSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sheetsSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _payoutsSub;
  bool _sheetsReady = false;

  bool get signedOut => authUser == null;
  bool get signedIn => authUser != null && user != null;
  bool get needsProfile => authUser != null && profileLoaded && user == null;
  bool get emailVerified => authUser?.emailVerified ?? false;
  String? get uid => authUser?.uid;

  CollectionReference<Map<String, dynamic>> get _sheets => db.collection('sheets');
  CollectionReference<Map<String, dynamic>> get _invites => db.collection('invites');
  CollectionReference<Map<String, dynamic>> get _payouts => db.collection('payouts');
  DocumentReference<Map<String, dynamic>> _userDoc(String id) => db.collection('users').doc(id);
  DocumentReference<Map<String, dynamic>> _keysDoc(String id) => _userDoc(id).collection('private').doc('keys');

  Future<void> init() async {
    final first = Completer<void>();
    _authSub = auth.authStateChanges().listen((u) async {
      await _onAuth(u);
      if (!first.isCompleted) first.complete();
    });
    await first.future.timeout(const Duration(seconds: 10), onTimeout: () {});
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _sheetsSub?.cancel();
    _payoutsSub?.cancel();
    toast.dispose();
    super.dispose();
  }

  Future<void> _onAuth(User? u) async {
    await _sheetsSub?.cancel();
    await _payoutsSub?.cancel();
    _sheetsSub = null;
    _payoutsSub = null;
    _sheetsReady = false;
    sheets = [];
    payouts = [];
    user = null;
    profileLoaded = false;
    authUser = u;
    if (u != null) {
      await _loadProfile(u);
      _listen(u.uid);
    }
    profileLoaded = true;
    notifyListeners();
  }

  Future<void> _loadProfile(User u) async {
    try {
      final pub = await _userDoc(u.uid).get();
      final priv = await _keysDoc(u.uid).get();
      final p = pub.data();
      final k = priv.data();
      if (p != null && k != null && k['secret'] is String) {
        user = UserProfile.fromDocs(u.uid, p, k);
      }
    } catch (e) {
      debugPrint('Could not load profile: $e');
    }
  }

  void _listen(String id) {
    _sheetsSub = _sheets.where('memberUids', arrayContains: id).snapshots().listen((snap) {
      final next = <SplitSheet>[];
      for (final d in snap.docs) {
        try {
          next.add(sheetFromDoc(d.id, d.data()));
        } catch (e) {
          debugPrint('Skipping unreadable sheet ${d.id}: $e');
        }
      }
      if (_sheetsReady) _announce(next);
      _sheetsReady = true;
      sheets = next;
      notifyListeners();
    }, onError: (Object e) {
      debugPrint('Sheets listener: $e');
      toast.value = e is FirebaseException && e.code == 'permission-denied'
          ? 'Firestore refused access. Deploy firestore.rules (see README) and restart the app.'
          : 'Could not load your sheets. Check your connection.';
    });

    _payoutsSub = _payouts.where('memberUids', arrayContains: id).snapshots().listen((snap) {
      final next = <Payout>[];
      for (final d in snap.docs) {
        try {
          next.add(Payout.fromJson(d.data()));
        } catch (e) {
          debugPrint('Skipping unreadable payout ${d.id}: $e');
        }
      }
      payouts = next;
      notifyListeners();
    }, onError: (Object e) => debugPrint('Payouts listener: $e'));
  }

  /// Tells the user when someone else signs or a sheet locks in, live from Firestore.
  void _announce(List<SplitSheet> next) {
    for (final s in next) {
      final old = byId(s.id);
      if (old == null) continue;
      for (final sig in s.signatures) {
        if (old.isSigned(sig.contributorIndex)) continue;
        if (sig.signedByUid == uid) continue;
        toast.value = '${s.contributors[sig.contributorIndex].displayName} signed ${s.title}';
      }
      if (old.status != SheetStatus.executed && s.status == SheetStatus.executed) {
        toast.value = '${s.title} is locked in. Everyone has signed.';
      }
      for (final r in s.changeRequests) {
        final seen = old.changeRequests.any((o) => o.createdAt == r.createdAt && o.contributorIndex == r.contributorIndex);
        if (!seen && isCreator(s)) {
          toast.value = '${s.contributors[r.contributorIndex].displayName} ${r.declined ? 'declined' : 'asked for a change on'} ${s.title}';
        }
      }
    }
  }

  // ---------------------------------------------------------------- account

  Future<void> signUp(String email, String password) async {
    final cred = await auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
    try {
      await cred.user?.sendEmailVerification();
    } catch (e) {
      debugPrint('Verification email not sent: $e');
    }
  }

  Future<void> signIn(String email, String password) =>
      auth.signInWithEmailAndPassword(email: email.trim(), password: password);

  Future<void> sendPasswordReset(String email) => auth.sendPasswordResetEmail(email: email.trim());

  Future<void> resendVerification() async => authUser?.sendEmailVerification();

  Future<void> refreshAuthUser() async {
    await authUser?.reload();
    authUser = auth.currentUser;
    notifyListeners();
  }

  Future<void> signOut() => auth.signOut();

  /// Friendly text for Firebase Auth errors.
  static String authMessage(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'email-already-in-use':
          return 'An account already exists for that email. Sign in instead.';
        case 'invalid-email':
          return 'That email address does not look right.';
        case 'weak-password':
          return 'Use at least 6 characters for your password.';
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return 'Email or password is incorrect.';
        case 'user-disabled':
          return 'This account has been disabled.';
        case 'too-many-requests':
          return 'Too many attempts. Wait a minute and try again.';
        case 'network-request-failed':
          return 'No connection. Check your internet and try again.';
        case 'requires-recent-login':
          return 'For your security, enter your password again.';
        case 'operation-not-allowed':
          return 'Email sign-in is not enabled for this Firebase project yet.';
      }
      return e.message ?? 'Something went wrong (${e.code}).';
    }
    return '$e';
  }

  Future<void> completeProfile({required String legalName, required String stageName, required String pin}) async {
    final u = authUser;
    if (u == null) throw StateError('Not signed in');
    // Reuse an existing key so earlier signatures stay linked to this account.
    String secret;
    final existing = await _keysDoc(u.uid).get();
    final old = existing.data()?['secret'];
    secret = old is String && old.isNotEmpty ? old : randomHex(32);
    final profile = UserProfile(
      uid: u.uid,
      email: u.email ?? '',
      legalName: legalName.trim(),
      stageName: stageName.trim(),
      pinHash: _pinHash(pin, secret),
      secret: secret,
      address: MockSigner.addressFor(secret),
      createdAt: DateTime.now(),
    );
    final batch = db.batch()
      ..set(_userDoc(u.uid), profile.publicJson())
      ..set(_keysDoc(u.uid), profile.privateJson());
    await batch.commit();
    user = profile;
    notifyListeners();
  }

  String _pinHash(String pin, String salt) => sha256Of('pin:$salt:$pin');

  bool checkPin(String pin) {
    final u = user;
    return u != null && _pinHash(pin, u.secret) == u.pinHash;
  }

  Future<void> changePin(String pin) async {
    final u = user;
    if (u == null) return;
    final next = u.copyWith(pinHash: _pinHash(pin, u.secret));
    await _keysDoc(u.uid).update({'pinHash': next.pinHash});
    user = next;
    notifyListeners();
  }

  Future<void> updateProfile({String? legalName, String? stageName, String? societyId}) async {
    final u = user;
    if (u == null) return;
    final next = u.copyWith(legalName: legalName, stageName: stageName, societyId: societyId);
    await _userDoc(u.uid).set(next.publicJson(), SetOptions(merge: true));
    user = next;
    notifyListeners();
  }

  /// Deletes the profile and the login. Sheets stay, because other people signed them too.
  /// Pass [password] when Firebase asks for a recent sign-in.
  Future<void> deleteAccount({String? password}) async {
    final u = authUser;
    if (u == null) return;
    if (password != null && u.email != null) {
      await u.reauthenticateWithCredential(EmailAuthProvider.credential(email: u.email!, password: password));
    } else {
      // Firebase only deletes logins that signed in recently. Check first, so we never remove
      // the profile and signing key while the login itself survives.
      final last = u.metadata.lastSignInTime;
      if (last == null || DateTime.now().difference(last) > const Duration(minutes: 4)) {
        throw FirebaseAuthException(code: 'requires-recent-login');
      }
    }
    await _keysDoc(u.uid).delete();
    await _userDoc(u.uid).delete();
    await u.delete();
  }

  String? takeAfterAuthPath() {
    final p = afterAuthPath;
    afterAuthPath = null;
    return p;
  }

  String exportJson() => const JsonEncoder.withIndent('  ').convert({
        'sheets': sheets.map((s) => s.toJson()).toList(),
        'payouts': payouts.map((p) => p.toJson()).toList(),
      });

  // ---------------------------------------------------------------- queries

  List<SplitSheet> get allSheets {
    final list = List<SplitSheet>.of(sheets);
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  SplitSheet? byId(String id) {
    for (final s in sheets) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// Index of the contributor slot this account has joined as.
  int? myIndex(SplitSheet s) {
    final id = uid;
    if (id == null) return null;
    for (final e in s.claims.entries) {
      if (e.value == id) return e.key;
    }
    return null;
  }

  /// Who has joined a slot from their own account (null when nobody has).
  String? claimedBy(SplitSheet s, int index) => s.claims[index];

  bool isCreator(SplitSheet s) => user != null && s.creatorAddress == user!.address;

  bool awaitingMe(SplitSheet s) {
    final i = myIndex(s);
    return s.status == SheetStatus.pending && i != null && !s.isSigned(i);
  }

  bool awaitingOthers(SplitSheet s) => s.status == SheetStatus.pending && !awaitingMe(s);

  SplitSheet? get spotlight {
    final list = allSheets;
    for (final s in list) {
      if (awaitingMe(s)) return s;
    }
    for (final s in list) {
      if (s.status == SheetStatus.pending && isCreator(s)) return s;
    }
    return null;
  }

  int myShare(Payout p) {
    final s = byId(p.sheetId);
    if (s == null) return 0;
    final i = myIndex(s);
    if (i == null || i >= p.shares.length) return 0;
    return p.shares[i];
  }

  int get balanceMicros => payouts.fold<int>(0, (a, p) => a + myShare(p));

  List<Payout> payoutsFor(String sheetId) {
    final list = payouts.where((p) => p.sheetId == sheetId).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  List<Payout> get allPayouts {
    final list = List<Payout>.of(payouts);
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// Looks up an open sheet by its invite code, before joining it.
  Future<SplitSheet?> findByCode(String code) async {
    final c = code.trim().toUpperCase();
    if (c.isEmpty) return null;
    try {
      final invite = await _invites.doc(c).get();
      final sheetId = invite.data()?['sheetId'];
      if (sheetId is! String) return null;
      return await fetchSheet(sheetId);
    } catch (e) {
      debugPrint('Invite lookup failed: $e');
      return null;
    }
  }

  /// Reads one sheet. Works for members, and for anyone signed in while it is still open.
  Future<SplitSheet?> fetchSheet(String id) async {
    final local = byId(id);
    if (local != null) return local;
    try {
      final snap = await _sheets.doc(id).get();
      final data = snap.data();
      return data == null ? null : sheetFromDoc(snap.id, data);
    } catch (e) {
      return null;
    }
  }

  // ---------------------------------------------------------------- creating

  SheetDraft newDraft() {
    final u = user!;
    return SheetDraft(contributors: [
      Contributor(
        name: u.legalName,
        stageName: u.stageName,
        roles: const ['Producer'],
        wallet: u.address,
        isCreator: true,
      ),
    ]);
  }

  /// A new version of [s] for an amendment. Whoever proposes it becomes the creator of the new version.
  SheetDraft draftFromSheet(SplitSheet s) {
    final people = List<Contributor>.of(s.contributors);
    final me = myIndex(s);
    if (me != null && me != 0) {
      final mine = people.removeAt(me);
      people.insert(0, mine);
    }
    return SheetDraft(
      title: s.title,
      sessionDate: s.sessionDate,
      studio: s.studio,
      genre: s.genre,
      contributors: [
        for (var i = 0; i < people.length; i++) people[i].withWallet(i == 0 ? user?.address : null, isCreator: i == 0),
      ],
      audioName: s.audioName,
      audioHash: s.audioHash,
      audioBytes: s.audioBytes,
      version: s.version + 1,
      previousId: s.id,
    );
  }

  Future<SplitSheet> publish(SheetDraft d) async {
    final u = user!;
    return _create(d, creatorSecret: u.secret, creatorWallet: u.address, claims: {0: u.uid});
  }

  Future<SplitSheet> _create(
    SheetDraft d, {
    required String creatorSecret,
    required String creatorWallet,
    required Map<int, String> claims,
  }) async {
    final u = user!;
    final contributors = <Contributor>[
      for (var i = 0; i < d.contributors.length; i++)
        d.contributors[i].withWallet(
          i == 0 ? creatorWallet : (claims[i] == u.uid ? u.address : null),
          isCreator: i == 0,
        ),
    ];
    // Whole seconds, so the signed timestamp prints the same on phones and in browsers.
    final created = d.createdAt ?? DateTime.now();
    final createdAt = DateTime.fromMillisecondsSinceEpoch(created.millisecondsSinceEpoch ~/ 1000 * 1000);
    final id = 'ss_${randomHex(8)}';
    final sheet = SplitSheet(
      id: id,
      version: d.version,
      previousId: d.previousId,
      title: d.title.trim(),
      sessionDate: DateTime(d.sessionDate.year, d.sessionDate.month, d.sessionDate.day),
      studio: d.studio.trim(),
      genre: d.genre.trim(),
      inviteCode: randomCode(),
      contributors: contributors,
      creatorAddress: creatorWallet,
      creatorUid: u.uid,
      createdAt: createdAt,
      audioName: d.audioName,
      audioHash: d.audioHash,
      audioBytes: d.audioBytes,
      claims: Map<int, String>.of(claims),
      memberUids: [u.uid],
    );
    sheet.docHash = computeDocHash(sheet);

    // An amendment to a sheet that is still collecting signatures replaces it.
    final pid = d.previousId;
    if (pid != null) {
      final prev = byId(pid);
      if (prev != null && prev.status == SheetStatus.pending) {
        await chain.cancel(prev.id);
        for (final r in prev.changeRequests) {
          r.resolved = true;
        }
        await _sheets.doc(prev.id).update({
          'status': SheetStatus.cancelled.name,
          'supersededBy': id,
          'changeRequests': prev.changeRequests.map((r) => r.toJson()).toList(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }

    sheet.createdTxHash = await chain.createSheet(
      sheetId: id,
      docHash: sheet.docHash,
      audioHash: sheet.audioHash,
      previousId: d.previousId,
      partyCount: contributors.length,
      compositionBps: sheet.bpsFor(SplitType.composition),
      masterBps: sheet.bpsFor(SplitType.master),
    );
    sheet.status = SheetStatus.pending;

    final batch = db.batch()
      ..set(_sheets.doc(id), {...sheetToDoc(sheet), 'createdAtServer': FieldValue.serverTimestamp()})
      ..set(_invites.doc(sheet.inviteCode), {
        'sheetId': id,
        'creatorUid': u.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
    await batch.commit();
    _upsert(sheet);

    await _applySignature(sheet, 0, creatorSecret, creatorWallet, at: d.createdAt == null ? null : createdAt);
    return sheet;
  }

  void _upsert(SplitSheet s) {
    final i = sheets.indexWhere((x) => x.id == s.id);
    if (i >= 0) {
      sheets[i] = s;
    } else {
      sheets = [...sheets, s];
    }
    notifyListeners();
  }

  /// Records a signature on the ledger, then on the sheet in a transaction so two people
  /// signing at the same moment on different phones cannot overwrite each other.
  Future<SplitSheet> _applySignature(SplitSheet sheet, int index, String secret, String wallet, {DateTime? at}) async {
    final sig = MockSigner.sign(secret, sheet.docHash);
    final tx = await chain.sign(
      sheetId: sheet.id,
      partyIndex: index,
      wallet: wallet,
      signature: sig,
      docHash: sheet.docHash,
    );
    final when = at ?? DateTime.now();
    final signature = SheetSignature(
      contributorIndex: index,
      wallet: wallet,
      signature: sig,
      signedAt: when,
      txHash: tx,
      signedByUid: uid,
    );
    final ref = _sheets.doc(sheet.id);
    final updated = await db.runTransaction<SplitSheet>((t) async {
      final snap = await t.get(ref);
      final data = snap.data();
      if (data == null) throw ChainException('Sheet not found');
      final current = sheetFromDoc(snap.id, data);
      if (current.isSigned(index)) return current;
      current.signatures.add(signature);
      current.contributors[index] = current.contributors[index].withWallet(wallet);
      final update = <String, dynamic>{
        'signatures': current.signatures.map((s) => s.toJson()).toList(),
        'wallets.$index': wallet,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (current.allSigned) {
        current.status = SheetStatus.executed;
        current.executedAt = when;
        update['status'] = SheetStatus.executed.name;
        update['executedAt'] = when.toUtc().toIso8601String();
      }
      t.update(ref, update);
      return current;
    });

    // A newly executed version replaces the previous executed one.
    final pid = updated.previousId;
    if (updated.status == SheetStatus.executed && pid != null) {
      try {
        final prev = await fetchSheet(pid);
        if (prev != null && prev.status == SheetStatus.executed) {
          await _sheets.doc(pid).update({
            'status': SheetStatus.superseded.name,
            'supersededBy': updated.id,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      } catch (e) {
        debugPrint('Could not mark the previous version as replaced: $e');
      }
    }
    _upsert(updated);
    return updated;
  }

  // ---------------------------------------------------------------- joining and signing

  /// Joins an open sheet as contributor [index], from this account on this phone.
  Future<SplitSheet> claimSlot(String sheetId, int index) async {
    final u = user!;
    final ref = _sheets.doc(sheetId);
    await db.runTransaction((t) async {
      final snap = await t.get(ref);
      final data = snap.data();
      if (data == null) throw ChainException('Sheet not found');
      final s = sheetFromDoc(snap.id, data);
      if (s.status != SheetStatus.pending) throw ChainException('This sheet is no longer open');
      if (index < 0 || index >= s.contributors.length) throw ChainException('Not a slot on this sheet');
      if (s.isSigned(index)) throw ChainException('${s.contributors[index].displayName} has already signed');
      final holder = s.claims[index];
      if (holder != null && holder != u.uid) {
        throw ChainException('${s.contributors[index].displayName} already joined from another account');
      }
      final mine = myIndex(s);
      if (mine != null && mine != index) {
        throw ChainException('You already joined this sheet as ${s.contributors[mine].displayName}');
      }
      t.update(ref, {
        'memberUids': FieldValue.arrayUnion([u.uid]),
        'claims.$index': u.uid,
        'wallets.$index': u.address,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
    final fresh = await ref.get();
    final s = sheetFromDoc(fresh.id, fresh.data()!);
    _upsert(s);
    return s;
  }

  /// The signed-in user signs their own slot (PIN already checked by the caller).
  Future<SplitSheet> signAsMe(String sheetId, int index) async {
    final u = user!;
    final s = byId(sheetId);
    if (s == null) throw ChainException('Sheet not found');
    if (myIndex(s) != index) throw ChainException('This slot belongs to someone else');
    return _applySignature(s, index, u.secret, u.address);
  }

  /// Someone without the app signs on this phone with a PIN of their own ("pass the phone").
  Future<SplitSheet> signAsGuest(String sheetId, int index, String pin) async {
    final s = byId(sheetId);
    if (s == null) throw ChainException('Sheet not found');
    final holder = s.claims[index];
    if (holder != null) {
      throw ChainException(holder == uid
          ? 'This slot is yours. Sign with your own PIN.'
          : '${s.contributors[index].displayName} joined on their own phone and signs there.');
    }
    final secret = MockSigner.guestSecret(s.id, index, pin);
    return _applySignature(s, index, secret, MockSigner.addressFor(secret));
  }

  Future<void> requestChange(
    String sheetId,
    int index, {
    required String reason,
    required String note,
    int? suggestedCompositionBps,
    bool decline = false,
  }) async {
    final r = ChangeRequest(
      contributorIndex: index,
      reason: reason,
      note: note,
      createdAt: DateTime.now(),
      suggestedCompositionBps: suggestedCompositionBps,
      declined: decline,
    );
    await _sheets.doc(sheetId).update({
      'changeRequests': FieldValue.arrayUnion([r.toJson()]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> cancelSheet(String sheetId) async {
    await chain.cancel(sheetId);
    await _sheets.doc(sheetId).update({
      'status': SheetStatus.cancelled.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ---------------------------------------------------------------- payouts

  Future<Payout> deposit(String sheetId, SplitType type, int amountMicros) async {
    final s = byId(sheetId);
    if (s == null) throw ChainException('Sheet not found');
    return _deposit(s, type, amountMicros);
  }

  Future<Payout> _deposit(SplitSheet s, SplitType type, int amountMicros, {DateTime? at}) async {
    if (s.status != SheetStatus.executed) {
      throw ChainException('Royalties can only be paid into a fully signed sheet');
    }
    final tx = await chain.deposit(sheetId: s.id, splitType: type, amountMicros: amountMicros);
    final ref = _payouts.doc();
    final p = Payout(
      id: ref.id,
      sheetId: s.id,
      splitType: type,
      amountMicros: amountMicros,
      shares: splitAmount(amountMicros, s.bpsFor(type)),
      createdAt: at ?? DateTime.now(),
      txHash: tx,
      memberUids: s.memberUids.contains(uid) ? s.memberUids : [...s.memberUids, if (uid != null) uid!],
    );
    await ref.set(p.toJson());
    return p;
  }

  // ---------------------------------------------------------------- demo data

  /// Three example sheets so judges can explore every state without a studio session.
  Future<void> seedDemo() async {
    final u = user;
    if (u == null) return;
    final now = DateTime.now();
    Contributor me(List<String> roles, int comp, int master) => Contributor(
          name: u.legalName,
          stageName: u.stageName,
          roles: roles,
          compositionBps: comp,
          masterBps: master,
        );

    // 1. Fully signed, with a royalty payment.
    final created1 = now.subtract(const Duration(days: 17));
    var s1 = await _create(
      SheetDraft(
        title: 'No Wahala (Remix)',
        sessionDate: created1,
        studio: 'Studio A (demo)',
        genre: 'Afrobeats',
        contributors: [
          me(const ['Producer', 'Writer'], 3000, 4000),
          const Contributor(name: 'Ada Okon', roles: ['Artist', 'Writer'], compositionBps: 3000, masterBps: 4000),
          const Contributor(name: 'Kemi Eze', stageName: 'Kemi E.', roles: ['Topliner'], compositionBps: 2000, masterBps: 0),
          const Contributor(name: 'Dayo Bello', roles: ['Engineer'], compositionBps: 2000, masterBps: 2000),
        ],
        audioName: 'no-wahala-remix_master.wav',
        audioHash: sha256Of('split-sheet-demo-audio:no-wahala-remix'),
        audioBytes: 44100000,
        createdAt: created1,
      ),
      creatorSecret: u.secret,
      creatorWallet: u.address,
      claims: {0: u.uid},
    );
    for (var i = 1; i < 4; i++) {
      final secret = MockSigner.guestSecret(s1.id, i, '1234');
      s1 = await _applySignature(s1, i, secret, MockSigner.addressFor(secret), at: created1.add(Duration(minutes: 6 * i)));
    }
    await _deposit(s1, SplitType.composition, 500000000, at: now.subtract(const Duration(days: 3)));

    // 2. Mine, still collecting signatures.
    final created2 = now.subtract(const Duration(hours: 2));
    await _create(
      SheetDraft(
        title: 'Lagos Summer',
        sessionDate: created2,
        studio: 'Studio B (demo)',
        genre: 'Afropop',
        contributors: [
          me(const ['Producer', 'Writer'], 4000, 5000),
          const Contributor(name: 'Ada Okon', roles: ['Artist', 'Writer'], compositionBps: 3500, masterBps: 5000),
          const Contributor(name: 'Kemi Eze', stageName: 'Kemi E.', roles: ['Topliner'], compositionBps: 2500, masterBps: 0),
        ],
        audioName: 'lagos-summer_v3.wav',
        audioHash: sha256Of('split-sheet-demo-audio:lagos-summer'),
        audioBytes: 41200000,
        createdAt: created2,
      ),
      creatorSecret: u.secret,
      creatorWallet: u.address,
      claims: {0: u.uid},
    );

    // 3. Someone else's sheet: I am the last signature.
    final created3 = now.subtract(const Duration(days: 1, hours: 3));
    final adaSecret = MockSigner.guestSecret('demo-creator-${u.uid}', 0, 'ada');
    final s3 = await _create(
      SheetDraft(
        title: 'Gbedu Season',
        sessionDate: created3,
        studio: 'Studio C (demo)',
        genre: 'Amapiano',
        contributors: [
          const Contributor(name: 'Ada Okon', roles: ['Artist', 'Writer'], compositionBps: 4000, masterBps: 6000),
          me(const ['Producer'], 3500, 4000),
          const Contributor(name: 'Kemi Eze', stageName: 'Kemi E.', roles: ['Topliner'], compositionBps: 2500, masterBps: 0),
        ],
        audioName: 'gbedu-season_rough.wav',
        audioHash: sha256Of('split-sheet-demo-audio:gbedu-season'),
        audioBytes: 38600000,
        createdAt: created3,
      ),
      creatorSecret: adaSecret,
      creatorWallet: MockSigner.addressFor(adaSecret),
      claims: {1: u.uid},
    );
    final kemiSecret = MockSigner.guestSecret(s3.id, 2, '1234');
    await _applySignature(s3, 2, kemiSecret, MockSigner.addressFor(kemiSecret), at: created3.add(const Duration(minutes: 9)));
  }
}
