import 'package:flutter_test/flutter_test.dart';
import 'package:split_sheet/models/models.dart';
import 'package:split_sheet/services/hashing.dart';
import 'package:split_sheet/utils/format.dart';
import 'package:split_sheet/utils/splits.dart';

SplitSheet _sheet({List<Contributor>? people}) => SplitSheet(
      id: 'ss_test',
      version: 1,
      title: 'Lagos Summer',
      sessionDate: DateTime(2026, 10, 24),
      studio: 'Studio B',
      genre: 'Afropop',
      inviteCode: 'ABC-1234',
      contributors: people ??
          [
            Contributor(name: 'Tobi', roles: ['Producer'], compositionBps: 4000, masterBps: 5000),
            Contributor(name: 'Ada', roles: ['Artist'], compositionBps: 3500, masterBps: 5000),
            Contributor(name: 'Kemi', roles: ['Topliner'], compositionBps: 2500, masterBps: 0),
          ],
      creatorAddress: '0xabc',
      createdAt: DateTime.utc(2026, 10, 24, 19, 2),
      audioHash: 'deadbeef',
      audioName: 'lagos.wav',
      audioBytes: 10,
    );

void main() {
  test('canonical JSON does not depend on key order', () {
    expect(canonicalJson({'b': 1, 'a': {'d': 2, 'c': 3}}), canonicalJson({'a': {'c': 3, 'd': 2}, 'b': 1}));
    expect(canonicalJson({'b': 1, 'a': 2}), '{"a":2,"b":1}');
  });

  test('document hash ignores wallets but changes with any share', () {
    final a = _sheet();
    final withWallet = _sheet(people: [
      for (final c in a.contributors) c.withWallet('0x123'),
    ]);
    expect(computeDocHash(a), computeDocHash(withWallet));

    final changed = _sheet(people: [
      a.contributors[0].copyWith(compositionBps: 4100),
      a.contributors[1].copyWith(compositionBps: 3400),
      a.contributors[2],
    ]);
    expect(computeDocHash(a) == computeDocHash(changed), isFalse);
  });

  test('sheet survives a JSON round trip with the same hash', () {
    final a = _sheet();
    a.docHash = computeDocHash(a);
    final b = SplitSheet.fromJson(a.toJson());
    expect(computeDocHash(b), a.docHash);
  });

  test('Firestore layout round trip keeps the signed hash, claims and wallets', () {
    final a = _sheet(people: [
      for (final c in _sheet().contributors) c,
    ]);
    a.contributors[1] = a.contributors[1].withWallet('0xada');
    a.claims[0] = 'uid-creator';
    a.memberUids.add('uid-creator');
    a.docHash = computeDocHash(a);
    final b = sheetFromDoc(a.id, sheetToDoc(a));
    expect(computeDocHash(b), a.docHash);
    expect(b.contributors[1].wallet, '0xada');
    expect(b.claims[0], 'uid-creator');
    expect(b.memberUids, ['uid-creator']);
    expect(b.title, 'Lagos Summer');
  });

  test('equal split always totals 100%', () {
    for (var n = 1; n <= 10; n++) {
      expect(sumBps(equalSplit(n)), fullBps);
    }
    expect(equalSplit(3), [3334, 3333, 3333]);
  });

  test('payout shares add up exactly, dust to the creator', () {
    final shares = splitAmount(100, [3333, 3333, 3334]);
    expect(shares.reduce((a, b) => a + b), 100);
    final big = splitAmount(500000000, [4000, 3500, 2500]);
    expect(big, [200000000, 175000000, 125000000]);
  });

  test('formatting helpers', () {
    expect(fmtPct(3500), '35%');
    expect(fmtPct(3333), '33.33%');
    expect(fmtPct(3350), '33.5%');
    expect(fmtUsdc(1234567890), '1,234.57');
    expect(parseUsdc('1,250.50'), 1250500000);
    expect(extractInviteCode('https://x.app/#/join/lgs-7q4k'), 'LGS-7Q4K');
  });
}
