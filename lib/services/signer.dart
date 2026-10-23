import 'hashing.dart';

/// Stand-in for the embedded wallet. Swap for an EIP-712 signer (Privy, Web3Auth or similar)
/// in a real build; the rest of the app only uses [addressFor] and [sign].
class MockSigner {
  static String addressFor(String secret) => '0x${sha256Of('address:$secret').substring(0, 40)}';

  static String sign(String secret, String docHash) => '0x${sha256Of('sign:$secret:$docHash')}';

  /// Key for someone signing on another person's phone ("pass the phone" in the studio).
  static String guestSecret(String sheetId, int index, String pin) =>
      sha256Of('guest:$sheetId:$index:$pin');
}
