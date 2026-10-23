/// 10,000 basis points = 100%.
const int fullBps = 10000;

int sumBps(List<int> values) => values.fold<int>(0, (a, b) => a + b);

/// Equal split; any remainder goes to the first person so the total is exactly 100%.
List<int> equalSplit(int n) {
  if (n <= 0) return <int>[];
  final base = fullBps ~/ n;
  final list = List<int>.generate(n, (_) => base);
  list[0] += fullBps - base * n;
  return list;
}

/// Splits an amount (integer micro-units) by basis points. Rounding dust goes to index 0
/// (the creator), so the shares always add up to the amount exactly.
/// Written to stay inside 2^53 so it is exact on the web as well.
List<int> splitAmount(int amount, List<int> bps) {
  final shares = <int>[
    for (final b in bps) (amount ~/ fullBps) * b + (amount % fullBps) * b ~/ fullBps,
  ];
  final total = shares.fold<int>(0, (a, b) => a + b);
  if (shares.isNotEmpty) shares[0] += amount - total;
  return shares;
}
