import '../utils/format.dart';

int _int(Object? v, [int fallback = 0]) => v is num ? v.toInt() : fallback;
int? _intN(Object? v) => v is num ? v.toInt() : null;
String _iso(DateTime d) => d.toUtc().toIso8601String();
DateTime _date(Object? v) => DateTime.parse(v as String).toLocal();
DateTime? _dateN(Object? v) => v is String ? DateTime.parse(v).toLocal() : null;

enum SheetStatus { draft, pending, executed, superseded, cancelled }

enum SplitType { composition, master }

extension SplitTypeLabel on SplitType {
  String get label => this == SplitType.composition ? 'Composition' : 'Master';
}

const kRoles = ['Producer', 'Writer', 'Artist', 'Featured artist', 'Topliner', 'Engineer', 'Label'];

class Contributor {
  const Contributor({
    required this.name,
    this.stageName = '',
    this.roles = const [],
    this.compositionBps = 0,
    this.masterBps = 0,
    this.wallet,
    this.isCreator = false,
  });

  final String name;
  final String stageName;
  final List<String> roles;
  final int compositionBps;
  final int masterBps;

  /// Address of the key that signed (or will sign) for this person. Not part of the signed terms.
  final String? wallet;
  final bool isCreator;

  String get displayName => stageName.trim().isNotEmpty ? stageName.trim() : name.trim();
  String get rolesLabel => roles.isEmpty ? 'Contributor' : roles.join(', ');

  int bps(SplitType t) => t == SplitType.composition ? compositionBps : masterBps;

  Contributor copyWith({
    String? name,
    String? stageName,
    List<String>? roles,
    int? compositionBps,
    int? masterBps,
  }) =>
      Contributor(
        name: name ?? this.name,
        stageName: stageName ?? this.stageName,
        roles: roles ?? this.roles,
        compositionBps: compositionBps ?? this.compositionBps,
        masterBps: masterBps ?? this.masterBps,
        wallet: wallet,
        isCreator: isCreator,
      );

  Contributor withWallet(String? w, {bool? isCreator}) => Contributor(
        name: name,
        stageName: stageName,
        roles: roles,
        compositionBps: compositionBps,
        masterBps: masterBps,
        wallet: w,
        isCreator: isCreator ?? this.isCreator,
      );

  /// Only the parts that are signed.
  Map<String, dynamic> termsJson() => {
        'name': name,
        'stageName': stageName,
        'roles': roles,
        'compositionBps': compositionBps,
        'masterBps': masterBps,
      };

  Map<String, dynamic> toJson() => {
        ...termsJson(),
        'wallet': wallet,
        'isCreator': isCreator,
      };

  factory Contributor.fromJson(Map<String, dynamic> j) => Contributor(
        name: j['name'] as String,
        stageName: (j['stageName'] ?? '') as String,
        roles: ((j['roles'] ?? const []) as List).map((e) => e.toString()).toList(),
        compositionBps: _int(j['compositionBps']),
        masterBps: _int(j['masterBps']),
        wallet: j['wallet'] as String?,
        isCreator: (j['isCreator'] ?? false) as bool,
      );
}

class SheetSignature {
  const SheetSignature({
    required this.contributorIndex,
    required this.wallet,
    required this.signature,
    required this.signedAt,
    required this.txHash,
    this.signedByUid,
  });

  final int contributorIndex;
  final String wallet;
  final String signature;
  final DateTime signedAt;
  final String txHash;

  /// The account that submitted the signature (the signer, or the phone it was signed on).
  final String? signedByUid;

  Map<String, dynamic> toJson() => {
        'contributorIndex': contributorIndex,
        'wallet': wallet,
        'signature': signature,
        'signedAt': _iso(signedAt),
        'txHash': txHash,
        'signedByUid': signedByUid,
      };

  factory SheetSignature.fromJson(Map<String, dynamic> j) => SheetSignature(
        contributorIndex: _int(j['contributorIndex']),
        wallet: j['wallet'] as String,
        signature: j['signature'] as String,
        signedAt: _date(j['signedAt']),
        txHash: j['txHash'] as String,
        signedByUid: j['signedByUid'] as String?,
      );
}

class ChangeRequest {
  ChangeRequest({
    required this.contributorIndex,
    required this.reason,
    required this.note,
    required this.createdAt,
    this.suggestedCompositionBps,
    this.declined = false,
    this.resolved = false,
  });

  final int contributorIndex;
  final String reason;
  final String note;
  final DateTime createdAt;
  final int? suggestedCompositionBps;
  final bool declined;
  bool resolved;

  Map<String, dynamic> toJson() => {
        'contributorIndex': contributorIndex,
        'reason': reason,
        'note': note,
        'createdAt': _iso(createdAt),
        'suggestedCompositionBps': suggestedCompositionBps,
        'declined': declined,
        'resolved': resolved,
      };

  factory ChangeRequest.fromJson(Map<String, dynamic> j) => ChangeRequest(
        contributorIndex: _int(j['contributorIndex']),
        reason: j['reason'] as String,
        note: (j['note'] ?? '') as String,
        createdAt: _date(j['createdAt']),
        suggestedCompositionBps: _intN(j['suggestedCompositionBps']),
        declined: (j['declined'] ?? false) as bool,
        resolved: (j['resolved'] ?? false) as bool,
      );
}

class SplitSheet {
  SplitSheet({
    required this.id,
    required this.version,
    required this.title,
    required this.sessionDate,
    required this.studio,
    required this.genre,
    required this.inviteCode,
    required this.contributors,
    required this.creatorAddress,
    required this.createdAt,
    this.creatorUid = '',
    this.previousId,
    this.audioName,
    this.audioHash,
    this.audioBytes,
    this.docHash = '',
    this.status = SheetStatus.draft,
    List<SheetSignature>? signatures,
    List<ChangeRequest>? changeRequests,
    Map<int, String>? claims,
    List<String>? memberUids,
    this.executedAt,
    this.createdTxHash,
    this.supersededBy,
  })  : signatures = signatures ?? <SheetSignature>[],
        changeRequests = changeRequests ?? <ChangeRequest>[],
        claims = claims ?? <int, String>{},
        memberUids = memberUids ?? <String>[];

  final String id;
  final int version;
  final String? previousId;
  final String title;
  final DateTime sessionDate;
  final String studio;
  final String genre;
  final String inviteCode;
  final List<Contributor> contributors;
  final String? audioName;
  final String? audioHash;
  final int? audioBytes;
  final String creatorAddress;

  /// Account that created the document (may differ from the named creator for demo data).
  final String creatorUid;
  final DateTime createdAt;

  String docHash;
  SheetStatus status;
  final List<SheetSignature> signatures;
  final List<ChangeRequest> changeRequests;

  /// Which account has joined as which contributor: index -> user id.
  final Map<int, String> claims;

  /// Accounts that can see and act on the sheet.
  final List<String> memberUids;
  DateTime? executedAt;
  String? createdTxHash;
  String? supersededBy;

  Contributor get creator => contributors.first;

  SheetSignature? signatureFor(int index) {
    for (final s in signatures) {
      if (s.contributorIndex == index) return s;
    }
    return null;
  }

  bool isSigned(int index) => signatureFor(index) != null;
  int get signedCount => signatures.length;
  bool get allSigned => contributors.isNotEmpty && signatures.length >= contributors.length;

  List<int> bpsFor(SplitType t) => [for (final c in contributors) c.bps(t)];

  List<ChangeRequest> get openRequests => changeRequests.where((r) => !r.resolved).toList();

  /// The terms every party signs. Wallets, status and signatures are deliberately excluded,
  /// so the hash stays the same while people sign.
  Map<String, dynamic> canonicalTerms() => {
        'schema': 'splitsheet/v1',
        'sheetId': id,
        'version': version,
        'previousVersion': previousId,
        'song': {
          'title': title,
          'sessionDate': isoDate(sessionDate),
          'studio': studio,
          'genre': genre,
        },
        'audio': audioHash == null
            ? null
            : {'sha256': audioHash, 'fileName': audioName, 'bytes': audioBytes},
        'contributors': [for (final c in contributors) c.termsJson()],
        'createdAt': _iso(createdAt),
      };

  Map<String, dynamic> toJson() => {
        'id': id,
        'version': version,
        'previousId': previousId,
        'title': title,
        'sessionDate': isoDate(sessionDate),
        'studio': studio,
        'genre': genre,
        'inviteCode': inviteCode,
        'contributors': contributors.map((c) => c.toJson()).toList(),
        'creatorAddress': creatorAddress,
        'creatorUid': creatorUid,
        'createdAt': _iso(createdAt),
        'audioName': audioName,
        'audioHash': audioHash,
        'audioBytes': audioBytes,
        'docHash': docHash,
        'status': status.name,
        'signatures': signatures.map((s) => s.toJson()).toList(),
        'changeRequests': changeRequests.map((r) => r.toJson()).toList(),
        'claims': {for (final e in claims.entries) '${e.key}': e.value},
        'memberUids': memberUids,
        'executedAt': executedAt == null ? null : _iso(executedAt!),
        'createdTxHash': createdTxHash,
        'supersededBy': supersededBy,
      };

  factory SplitSheet.fromJson(Map<String, dynamic> j) => SplitSheet(
        id: j['id'] as String,
        version: _int(j['version'], 1),
        previousId: j['previousId'] as String?,
        title: j['title'] as String,
        sessionDate: DateTime.parse(j['sessionDate'] as String),
        studio: (j['studio'] ?? '') as String,
        genre: (j['genre'] ?? '') as String,
        inviteCode: j['inviteCode'] as String,
        contributors: (j['contributors'] as List)
            .map((e) => Contributor.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        creatorAddress: j['creatorAddress'] as String,
        creatorUid: (j['creatorUid'] ?? '') as String,
        createdAt: _date(j['createdAt']),
        audioName: j['audioName'] as String?,
        audioHash: j['audioHash'] as String?,
        audioBytes: _intN(j['audioBytes']),
        docHash: (j['docHash'] ?? '') as String,
        status: SheetStatus.values.byName(j['status'] as String),
        signatures: ((j['signatures'] ?? const []) as List)
            .map((e) => SheetSignature.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        changeRequests: ((j['changeRequests'] ?? const []) as List)
            .map((e) => ChangeRequest.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        claims: {
          for (final e in ((j['claims'] ?? const {}) as Map).entries) int.parse(e.key.toString()): e.value as String,
        },
        memberUids: ((j['memberUids'] ?? const []) as List).map((e) => e.toString()).toList(),
        executedAt: _dateN(j['executedAt']),
        createdTxHash: j['createdTxHash'] as String?,
        supersededBy: j['supersededBy'] as String?,
      );
}

/// What the create wizard edits before a sheet is published.
class SheetDraft {
  SheetDraft({
    this.title = '',
    DateTime? sessionDate,
    this.studio = '',
    this.genre = '',
    List<Contributor>? contributors,
    this.audioName,
    this.audioHash,
    this.audioBytes,
    this.version = 1,
    this.previousId,
    this.createdAt,
  })  : sessionDate = sessionDate ?? DateTime.now(),
        contributors = contributors ?? <Contributor>[];

  String title;
  DateTime sessionDate;
  String studio;
  String genre;
  List<Contributor> contributors;
  String? audioName;
  String? audioHash;
  int? audioBytes;
  int version;
  String? previousId;
  DateTime? createdAt;
}

class Payout {
  const Payout({
    required this.id,
    required this.sheetId,
    required this.splitType,
    required this.amountMicros,
    required this.shares,
    required this.createdAt,
    required this.txHash,
    this.memberUids = const [],
  });

  final String id;
  final String sheetId;
  final SplitType splitType;
  final int amountMicros;
  final List<int> shares;
  final DateTime createdAt;
  final String txHash;
  final List<String> memberUids;

  Map<String, dynamic> toJson() => {
        'id': id,
        'sheetId': sheetId,
        'splitType': splitType.name,
        'amountMicros': amountMicros,
        'shares': shares,
        'createdAt': _iso(createdAt),
        'txHash': txHash,
        'memberUids': memberUids,
      };

  factory Payout.fromJson(Map<String, dynamic> j) => Payout(
        id: j['id'] as String,
        sheetId: j['sheetId'] as String,
        splitType: SplitType.values.byName(j['splitType'] as String),
        amountMicros: _int(j['amountMicros']),
        shares: (j['shares'] as List).map((e) => _int(e)).toList(),
        createdAt: _date(j['createdAt']),
        txHash: j['txHash'] as String,
        memberUids: ((j['memberUids'] ?? const []) as List).map((e) => e.toString()).toList(),
      );
}

class UserProfile {
  const UserProfile({
    required this.uid,
    required this.email,
    required this.legalName,
    required this.stageName,
    required this.pinHash,
    required this.secret,
    required this.address,
    required this.createdAt,
    this.societyId = '',
  });

  final String uid;
  final String email;
  final String legalName;
  final String stageName;
  final String pinHash;

  /// Mock signing secret, kept in an owner-only document. A production build keeps the key
  /// inside an embedded wallet SDK instead.
  final String secret;
  final String address;
  final String societyId;
  final DateTime createdAt;

  String get displayName => stageName.trim().isNotEmpty ? stageName.trim() : legalName.trim();

  UserProfile copyWith({String? legalName, String? stageName, String? pinHash, String? societyId}) =>
      UserProfile(
        uid: uid,
        email: email,
        legalName: legalName ?? this.legalName,
        stageName: stageName ?? this.stageName,
        pinHash: pinHash ?? this.pinHash,
        secret: secret,
        address: address,
        createdAt: createdAt,
        societyId: societyId ?? this.societyId,
      );

  /// Public part, stored at users/{uid}.
  Map<String, dynamic> publicJson() => {
        'email': email,
        'legalName': legalName,
        'stageName': stageName,
        'societyId': societyId,
        'address': address,
        'createdAt': _iso(createdAt),
      };

  /// Private part, stored at users/{uid}/private/keys and readable only by the owner.
  Map<String, dynamic> privateJson() => {'secret': secret, 'pinHash': pinHash};

  factory UserProfile.fromDocs(String uid, Map<String, dynamic> pub, Map<String, dynamic> priv) => UserProfile(
        uid: uid,
        email: (pub['email'] ?? '') as String,
        legalName: (pub['legalName'] ?? '') as String,
        stageName: (pub['stageName'] ?? '') as String,
        societyId: (pub['societyId'] ?? '') as String,
        address: (pub['address'] ?? '') as String,
        createdAt: _dateN(pub['createdAt']) ?? DateTime.now(),
        secret: priv['secret'] as String,
        pinHash: priv['pinHash'] as String,
      );
}

/// Firestore layout of a sheet: the signed terms in one immutable map, and the parts that change
/// while people sign beside it. Security rules forbid any change to `terms`.
Map<String, dynamic> sheetToDoc(SplitSheet s) => {
      'terms': s.canonicalTerms(),
      'docHash': s.docHash,
      'status': s.status.name,
      'inviteCode': s.inviteCode,
      'creatorUid': s.creatorUid,
      'creatorAddress': s.creatorAddress,
      'memberUids': s.memberUids,
      'claims': {for (final e in s.claims.entries) '${e.key}': e.value},
      'wallets': {
        for (var i = 0; i < s.contributors.length; i++)
          if (s.contributors[i].wallet != null) '$i': s.contributors[i].wallet,
      },
      'signatures': s.signatures.map((x) => x.toJson()).toList(),
      'changeRequests': s.changeRequests.map((x) => x.toJson()).toList(),
      'executedAt': s.executedAt == null ? null : _iso(s.executedAt!),
      'createdTxHash': s.createdTxHash,
      'supersededBy': s.supersededBy,
    };

SplitSheet sheetFromDoc(String id, Map<String, dynamic> d) {
  final terms = Map<String, dynamic>.from(d['terms'] as Map);
  final song = Map<String, dynamic>.from(terms['song'] as Map);
  final audio = terms['audio'] == null ? null : Map<String, dynamic>.from(terms['audio'] as Map);
  final wallets = Map<String, dynamic>.from((d['wallets'] ?? const {}) as Map);
  final people = (terms['contributors'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  return SplitSheet(
    id: id,
    version: _int(terms['version'], 1),
    previousId: terms['previousVersion'] as String?,
    title: (song['title'] ?? '') as String,
    sessionDate: DateTime.parse(song['sessionDate'] as String),
    studio: (song['studio'] ?? '') as String,
    genre: (song['genre'] ?? '') as String,
    inviteCode: (d['inviteCode'] ?? '') as String,
    contributors: [
      for (var i = 0; i < people.length; i++)
        Contributor.fromJson(people[i]).withWallet(wallets['$i'] as String?, isCreator: i == 0),
    ],
    creatorAddress: (d['creatorAddress'] ?? '') as String,
    creatorUid: (d['creatorUid'] ?? '') as String,
    createdAt: _date(terms['createdAt']),
    audioName: audio?['fileName'] as String?,
    audioHash: audio?['sha256'] as String?,
    audioBytes: _intN(audio?['bytes']),
    docHash: (d['docHash'] ?? '') as String,
    status: SheetStatus.values.byName((d['status'] ?? 'pending') as String),
    signatures: ((d['signatures'] ?? const []) as List)
        .map((e) => SheetSignature.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
    changeRequests: ((d['changeRequests'] ?? const []) as List)
        .map((e) => ChangeRequest.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
    claims: {
      for (final e in ((d['claims'] ?? const {}) as Map).entries) int.parse(e.key.toString()): e.value as String,
    },
    memberUids: ((d['memberUids'] ?? const []) as List).map((e) => e.toString()).toList(),
    executedAt: _dateN(d['executedAt']),
    createdTxHash: d['createdTxHash'] as String?,
    supersededBy: d['supersededBy'] as String?,
  );
}
