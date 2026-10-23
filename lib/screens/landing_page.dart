import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/site.dart';

/// Public website shown at "/" on the web build.
class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SingleChildScrollView(
        child: Column(children: [
          SiteNav(),
          _Hero(),
          _HowItWorks(),
          _TwoSplits(),
          _Proof(),
          _Payouts(),
          _Faq(),
          _FinalCta(),
          SiteFooter(),
        ]),
      ),
    );
  }
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: T.body(12, color: C.accent, weight: FontWeight.w700).copyWith(letterSpacing: 1.6),
      );
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    final wide = isWide(context);
    final copy = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Pill('For producers, writers and artists', background: C.accentBg, foreground: C.accentSoft, border: C.lineWarm),
      const SizedBox(height: 22),
      Text('Who wrote that hook? Settle it before you leave the studio.',
          style: T.display(wide ? 62 : 40, height: 1.02)),
      const SizedBox(height: 20),
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Text(
          'Split Sheet records who owns what share of a song, gets everyone to sign on their phone, and ties the deal to the exact recording. Proof anyone can check, years later.',
          style: T.body(wide ? 19 : 17, color: C.text2, height: 1.5),
        ),
      ),
      const SizedBox(height: 28),
      Wrap(spacing: 12, runSpacing: 12, children: [
        PillButton(label: 'Start a split sheet', icon: Icons.arrow_forward_rounded, onTap: () => context.go('/app')),
        PillButton(label: 'Verify a sheet', filled: false, onTap: () => context.go('/verify')),
      ]),
      const SizedBox(height: 18),
      Text('An email, a password and a PIN. No crypto wallet needed.', style: T.body(14, color: C.muted)),
    ]);

    return SiteBand(
      child: wide
          ? Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Expanded(flex: 6, child: copy),
              const SizedBox(width: 56),
              const Expanded(flex: 5, child: _HeroVisual()),
            ])
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              copy,
              const SizedBox(height: 44),
              const Center(child: SizedBox(width: 420, child: _HeroVisual())),
            ]),
    );
  }
}

class _HeroVisual extends StatelessWidget {
  const _HeroVisual();

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: C.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: C.line),
        boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 40, offset: Offset(0, 20))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          const CoverArt('Lagos Summer', size: 56, radius: 10),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Lagos Summer', style: T.body(17, weight: FontWeight.w700)),
              Text('Session 24 Oct 2026', style: T.body(13, color: C.muted)),
            ]),
          ),
        ]),
        const SizedBox(height: 20),
        Text('Composition split', style: T.body(13, color: C.muted)),
        const SizedBox(height: 10),
        const SplitBar(bps: [4000, 3500, 2500], height: 12),
        const SizedBox(height: 14),
        for (final row in const [
          ['Tobi Beats', 'Producer, Writer', '40%'],
          ['Ada Okon', 'Artist, Writer', '35%'],
          ['Kemi E.', 'Topliner', '25%'],
        ])
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(row[0], style: T.body(14, weight: FontWeight.w500)),
                  Text(row[1], style: T.body(12, color: C.muted)),
                ]),
              ),
              Text(row[2], style: T.mono(14)),
              const SizedBox(width: 12),
              const SignedMark(signed: true, size: 22),
            ]),
          ),
        const Divider(height: 26),
        Row(children: [
          Text('Audio fingerprint', style: T.body(13, color: C.muted)),
          const Spacer(),
          Text('9b1c 4e07 … a2f1', style: T.mono(12, color: C.text2)),
        ]),
      ]),
    );

    return Stack(clipBehavior: Clip.none, children: [
      Padding(padding: const EdgeInsets.only(top: 26, right: 26, bottom: 40), child: card),
      const Positioned(
        right: 0,
        top: 0,
        child: _FloatChip(icon: Icons.verified_rounded, iconColor: C.green, title: 'Genuine', subtitle: 'All 3 signed'),
      ),
      const Positioned(
        left: 18,
        bottom: 0,
        child: _FloatChip(
          icon: Icons.south_west_rounded,
          iconColor: C.accent,
          title: '+175.00 USDC',
          subtitle: 'Royalties to Ada',
        ),
      ),
    ]);
  }
}

class _FloatChip extends StatelessWidget {
  const _FloatChip({required this.icon, required this.iconColor, required this.title, required this.subtitle});
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 16, 10),
      decoration: BoxDecoration(
        color: C.surface2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: C.line2),
        boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 24, offset: Offset(0, 10))],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(color: withA(iconColor, 0.16), shape: BoxShape.circle),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(title, style: T.body(14, weight: FontWeight.w700)),
          Text(subtitle, style: T.body(12, color: C.muted)),
        ]),
      ]),
    );
  }
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  @override
  Widget build(BuildContext context) {
    const steps = [
      ['01', 'Create it in the studio', 'Add the song, the people in the room and their roles. Set the composition and master splits. It takes about three minutes.'],
      ['02', 'Everyone signs on their phone', 'Collaborators scan a QR code, check their share and confirm with a PIN. Or pass one phone around the room.'],
      ['03', 'Proof that lasts', 'The signed terms and the audio fingerprint are timestamped on a public record. Change one byte and it no longer matches.'],
    ];
    return SiteBand(
      color: C.bgDeep,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _Eyebrow('How it works'),
        const SizedBox(height: 12),
        Text('From the session to signed in three steps', style: T.display(isWide(context) ? 44 : 32, height: 1.1)),
        const SizedBox(height: 36),
        LayoutBuilder(builder: (context, c) {
          final cols = c.maxWidth >= 820 ? 3 : 1;
          final w = (c.maxWidth - 20 * (cols - 1)) / cols;
          return Wrap(spacing: 20, runSpacing: 20, children: [
            for (final s in steps)
              SizedBox(
                width: w,
                child: SurfaceCard(
                  padding: const EdgeInsets.all(24),
                  radius: 24,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s[0], style: T.mono(14, color: C.accent, weight: FontWeight.w500)),
                    const SizedBox(height: 18),
                    Text(s[1], style: T.display(22)),
                    const SizedBox(height: 10),
                    Text(s[2], style: T.body(15, color: C.text2, height: 1.5)),
                  ]),
                ),
              ),
          ]);
        }),
      ]),
    );
  }
}

class _TwoSplits extends StatelessWidget {
  const _TwoSplits();

  @override
  Widget build(BuildContext context) {
    final wide = isWide(context);
    Widget card(String title, String body, List<int> bps, List<String> names) => SurfaceCard(
          padding: const EdgeInsets.all(24),
          radius: 24,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(title, style: T.display(24)),
            const SizedBox(height: 8),
            Text(body, style: T.body(15, color: C.text2, height: 1.5)),
            const SizedBox(height: 20),
            SplitBar(bps: bps, height: 12),
            const SizedBox(height: 10),
            Wrap(spacing: 14, runSpacing: 6, children: [
              for (final n in names) Text(n, style: T.body(13, color: C.muted)),
            ]),
          ]),
        );

    final comp = card(
      'Composition',
      'The song itself: lyrics and melody. Usually shared between writers and producers.',
      const [4000, 3500, 2500],
      const ['Tobi 40%', 'Ada 35%', 'Kemi 25%'],
    );
    final master = card(
      'Master',
      'This specific recording. Usually the artist and whoever paid for the session.',
      const [5000, 5000],
      const ['Tobi 50%', 'Ada 50%'],
    );

    return SiteBand(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _Eyebrow('Two splits, done right'),
        const SizedBox(height: 12),
        Text('A song has two owners lists. We record both.', style: T.display(wide ? 44 : 32, height: 1.1)),
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Text(
            'Most disputes start because people mix these up. Split Sheet keeps them separate, and each one must add up to exactly 100% before anyone can sign.',
            style: T.body(17, color: C.text2, height: 1.5),
          ),
        ),
        const SizedBox(height: 32),
        wide
            ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: comp),
                const SizedBox(width: 20),
                Expanded(child: master),
              ])
            : Column(children: [comp, const SizedBox(height: 16), master]),
      ]),
    );
  }
}

class _Proof extends StatelessWidget {
  const _Proof();

  @override
  Widget build(BuildContext context) {
    final wide = isWide(context);
    const points = [
      [Icons.graphic_eq_rounded, 'Tied to the recording', 'The audio is fingerprinted on your phone. The file never leaves it.'],
      [Icons.schedule_rounded, 'Every signature timestamped', 'Each person signs separately, with their own key. Nobody signs for anyone else.'],
      [Icons.lock_outline_rounded, 'Tamper-evident', 'Edit one number in the PDF and the verify page shows it no longer matches.'],
      [Icons.visibility_off_outlined, 'Private by design', 'Only fingerprints go on the public record. Names and shares stay with the people on the sheet.'],
    ];
    final text = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _Eyebrow('Proof anyone can check'),
      const SizedBox(height: 12),
      Text('Scan the QR on the PDF. See the truth.', style: T.display(wide ? 44 : 32, height: 1.1)),
      const SizedBox(height: 28),
      for (final p in points)
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: C.accentBg, borderRadius: BorderRadius.circular(12)),
              child: Icon(p[0] as IconData, color: C.accent, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p[1] as String, style: T.body(16, weight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(p[2] as String, style: T.body(15, color: C.text2, height: 1.45)),
              ]),
            ),
          ]),
        ),
    ]);

    final mock = SurfaceCard(
      padding: const EdgeInsets.all(22),
      radius: 24,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: Pill('Genuine · Executed', background: C.green, foreground: C.onGreen),
        ),
        const SizedBox(height: 14),
        Text('Lagos Summer', style: T.display(30)),
        const SizedBox(height: 4),
        Text('Signed by all 3 parties. Unchanged since.', style: T.body(14, color: C.text2)),
        const SizedBox(height: 18),
        const InfoRow(label: 'Document hash', value: '0x71d0…3b9a'),
        const InfoRow(label: 'Audio fingerprint', value: '9b1c…a2f1'),
        const InfoRow(label: 'Last signature', value: '24 Oct 2026, 19:14', mono: false),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: C.greenBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: C.greenLine),
          ),
          child: Row(children: [
            const Icon(Icons.check_rounded, color: C.green, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text('Match. This recording is the one on the sheet.', style: T.body(14))),
          ]),
        ),
      ]),
    );

    return SiteBand(
      color: C.bgDeep,
      child: wide
          ? Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Expanded(child: text),
              const SizedBox(width: 56),
              Expanded(child: mock),
            ])
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [text, const SizedBox(height: 12), mock]),
    );
  }
}

class _Payouts extends StatelessWidget {
  const _Payouts();

  @override
  Widget build(BuildContext context) {
    final wide = isWide(context);
    final text = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _Eyebrow('Coming next · testnet demo today'),
      const SizedBox(height: 12),
      Text('Royalties that split themselves.', style: T.display(wide ? 44 : 32, height: 1.1)),
      const SizedBox(height: 14),
      Text(
        'Once a sheet is locked in, a label or distributor can pay into it in stablecoins. Every contributor receives their signed share in the same moment. No spreadsheets, no chasing.',
        style: T.body(17, color: C.text2, height: 1.5),
      ),
    ]);
    final wallet = Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3A2A0E), Color(0xFF1E1B14)],
        ),
        border: Border.all(color: C.lineWarm),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('500.00 USDC paid into Lagos Summer', style: T.body(14, color: C.accentSoft)),
        const SizedBox(height: 16),
        for (final r in const [
          ['Tobi Beats · 40%', '+200.00'],
          ['Ada Okon · 35%', '+175.00'],
          ['Kemi E. · 25%', '+125.00'],
        ])
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(children: [
              Expanded(child: Text(r[0], style: T.body(15))),
              Text(r[1], style: T.mono(15, color: C.green)),
            ]),
          ),
      ]),
    );
    return SiteBand(
      child: wide
          ? Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Expanded(child: text),
              const SizedBox(width: 56),
              Expanded(child: wallet),
            ])
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [text, const SizedBox(height: 28), wallet]),
    );
  }
}

class _Faq extends StatelessWidget {
  const _Faq();

  @override
  Widget build(BuildContext context) {
    const faqs = [
      [
        'Is a split sheet legally binding?',
        'A split sheet records what the parties agreed. Signed separately by each person and timestamped, it is strong evidence of that agreement. It is not legal advice and does not replace a publishing, label or distribution contract. Take legal advice for high-value works.',
      ],
      [
        'Do I need crypto or a wallet?',
        'No. You sign in with your email and password and confirm each signature with a 4-digit PIN. The signing key is created for you.',
      ],
      [
        'Who can see our splits?',
        'Names and shares are visible to the people on the sheet. The public record only holds fingerprints, shares and timestamps, which reveal nothing about who is who.',
      ],
      [
        'What if we change the deal later?',
        'Anyone on the sheet can propose an amendment. Everyone signs the new version and the old one is marked as replaced. Nothing is ever deleted.',
      ],
      [
        'What is the difference between composition and master?',
        'Composition is the song: lyrics and melody. Master is one recording of it. They are often owned by different people, so we record both.',
      ],
    ];
    return SiteBand(
      color: C.bgDeep,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _Eyebrow('Questions'),
          const SizedBox(height: 12),
          Text('Good to know', style: T.display(isWide(context) ? 44 : 32)),
          const SizedBox(height: 24),
          for (final f in faqs)
            Container(
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.line))),
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(vertical: 6),
                  childrenPadding: const EdgeInsets.only(bottom: 18),
                  iconColor: C.accent,
                  collapsedIconColor: C.muted,
                  expandedAlignment: Alignment.centerLeft,
                  title: Text(f[0], style: T.body(17, weight: FontWeight.w700)),
                  children: [Text(f[1], style: T.body(15, color: C.text2, height: 1.55))],
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

class _FinalCta extends StatelessWidget {
  const _FinalCta();

  @override
  Widget build(BuildContext context) {
    final wide = isWide(context);
    return SiteBand(
      child: Container(
        padding: EdgeInsets.all(wide ? 56 : 28),
        decoration: BoxDecoration(color: C.accent, borderRadius: BorderRadius.circular(32)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Your next session deserves a paper trail.',
              style: T.display(wide ? 48 : 32, color: C.onAccent, height: 1.05)),
          const SizedBox(height: 14),
          Text('Free while in beta. Works on any phone or laptop.', style: T.body(17, color: const Color(0xFF4A3510))),
          const SizedBox(height: 26),
          Material(
            color: C.onAccent,
            shape: const StadiumBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => context.go('/app'),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Text('Create your first sheet', style: T.body(16, color: C.text, weight: FontWeight.w700)),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
