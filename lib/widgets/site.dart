import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme.dart';
import 'logo.dart';

const double kSiteMaxWidth = 1120;

bool isWide(BuildContext context) => MediaQuery.sizeOf(context).width >= 900;

/// Full-width band with centred, max-width content.
class SiteBand extends StatelessWidget {
  const SiteBand({super.key, required this.child, this.color, this.padding});
  final Widget child;
  final Color? color;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final wide = isWide(context);
    return Container(
      width: double.infinity,
      color: color,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kSiteMaxWidth),
          child: Padding(
            padding: padding ?? EdgeInsets.symmetric(horizontal: 24, vertical: wide ? 88 : 56),
            child: child,
          ),
        ),
      ),
    );
  }
}

class PillButton extends StatelessWidget {
  const PillButton({super.key, required this.label, required this.onTap, this.filled = true, this.icon});
  final String label;
  final VoidCallback onTap;
  final bool filled;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? C.accent : Colors.transparent,
      shape: StadiumBorder(side: filled ? BorderSide.none : const BorderSide(color: C.line2)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(label, style: T.body(16, color: filled ? C.onAccent : C.text, weight: FontWeight.w700)),
            if (icon != null) ...[
              const SizedBox(width: 8),
              Icon(icon, size: 18, color: filled ? C.onAccent : C.text),
            ],
          ]),
        ),
      ),
    );
  }
}

class SiteNav extends StatelessWidget {
  const SiteNav({super.key, this.subtitle});
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final wide = isWide(context);
    return Container(
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.line))),
      child: SiteBand(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        child: Row(children: [
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => context.go('/'),
            child: Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Logo(size: wide ? 28 : 24)),
          ),
          if (subtitle != null) ...[
            const SizedBox(width: 10),
            Text(subtitle!, style: T.body(14, color: C.muted)),
          ],
          const Spacer(),
          if (wide) ...[
            TextButton(
              onPressed: () => context.go('/verify'),
              child: Text('Verify a sheet', style: T.body(15, color: C.text2)),
            ),
            const SizedBox(width: 12),
          ],
          PillButton(label: 'Open the app', onTap: () => context.go('/app')),
        ]),
      ),
    );
  }
}

class SiteFooter extends StatelessWidget {
  const SiteFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final wide = isWide(context);
    final links = Wrap(spacing: 20, runSpacing: 8, children: [
      TextButton(onPressed: () => context.go('/app'), child: Text('Open the app', style: T.body(14, color: C.text2))),
      TextButton(onPressed: () => context.go('/verify'), child: Text('Verify a sheet', style: T.body(14, color: C.text2))),
    ]);
    final about = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Logo(size: 24),
      const SizedBox(height: 12),
      Text('A record of your agreement, not legal advice.', style: T.body(13, color: C.muted)),
      const SizedBox(height: 4),
      Text('Built for the BLI Legal Tech Hackathon 2.', style: T.body(13, color: C.faint)),
    ]);
    return Container(
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: C.line))),
      child: SiteBand(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
        child: wide
            ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: about), links])
            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [about, const SizedBox(height: 16), links]),
      ),
    );
  }
}
