import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../config.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import '../widgets/sheet_widgets.dart';

/// QR invite plus a live tracker of who has signed, like following an order.
class InviteScreen extends StatelessWidget {
  const InviteScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = state.byId(id);
    if (s == null) return const NotFoundView();
    final link = AppConfig.joinUrl(s.inviteCode);
    final executed = s.status == SheetStatus.executed;

    final items = <TimelineItem>[
      TimelineItem(
        title: 'Sheet created',
        subtitle: '${s.creator.displayName} · ${fmtTime(s.createdAt)}',
        done: true,
      ),
      for (var i = 1; i < s.contributors.length; i++) _itemFor(context, state, s, i),
      TimelineItem(
        title: executed ? 'Locked in' : 'Locked in when everyone signs',
        subtitle: executed ? 'Recorded ${fmtDateTime(s.executedAt!)}' : null,
        done: executed,
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          children: [
            TopBar(
              icon: Icons.close_rounded,
              onBack: () => context.go('/home'),
              label: s.title,
              trailing: IconBox(
                icon: Icons.description_outlined,
                tooltip: 'Open sheet',
                onTap: () => context.push('/sheet/${s.id}'),
              ),
            ),
            const SizedBox(height: 18),
            if (executed) ...[
              _LockedBanner(sheet: s),
              const SizedBox(height: 20),
            ] else ...[
              Text('Get everyone to sign', textAlign: TextAlign.center, style: T.display(28)),
              const SizedBox(height: 6),
              Text('They scan this with their phone and sign there, or you pass this phone around the room.',
                  textAlign: TextAlign.center, style: T.body(14, color: C.muted)),
              const SizedBox(height: 18),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(color: C.text, borderRadius: BorderRadius.circular(24)),
                  child: Column(children: [
                    QrImageView(
                      data: link,
                      version: QrVersions.auto,
                      size: 196,
                      backgroundColor: C.text,
                      eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: C.bg),
                      dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: C.bg),
                      semanticsLabel: 'Invite QR code',
                    ),
                    const SizedBox(height: 8),
                    Text('Code: ${s.inviteCode}', style: T.mono(14, color: const Color(0xFF3A372F))),
                  ]),
                ),
              ),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  child: SecondaryButton(
                    label: 'Copy link',
                    icon: Icons.link_rounded,
                    onPressed: () => copyText(context, link, 'Invite link'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SecondaryButton(
                    label: 'Copy code',
                    icon: Icons.copy_rounded,
                    onPressed: () => copyText(context, s.inviteCode, 'Code'),
                  ),
                ),
              ]),
              const SizedBox(height: 20),
            ],
            SurfaceCard(
              padding: const EdgeInsets.all(18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Expanded(child: Text('Signatures', style: T.body(16, weight: FontWeight.w700))),
                  Text('${s.signedCount} of ${s.contributors.length}', style: T.body(13, color: C.muted)),
                ]),
                const SizedBox(height: 16),
                Timeline(items: items),
              ]),
            ),
            if (!executed) ...[
              const SizedBox(height: 14),
              Text(
                'Signatures appear here live. No app on their phone? Hand yours over: each person checks their share and confirms with a PIN of their own.',
                textAlign: TextAlign.center,
                style: T.body(12, color: C.faint, height: 1.45),
              ),
            ],
          ],
        ),
      ),
    );
  }

  TimelineItem _itemFor(BuildContext context, AppState state, SplitSheet s, int i) {
    final c = s.contributors[i];
    final sig = s.signatureFor(i);
    if (sig != null) {
      return TimelineItem(title: '${c.displayName} signed', subtitle: fmtTime(sig.signedAt), done: true);
    }
    ChangeRequest? request;
    for (final r in s.openRequests) {
      if (r.contributorIndex == i) request = r;
    }
    if (request != null) {
      return TimelineItem(
        title: c.displayName,
        subtitle: request.declined ? 'Declined: ${request.note}' : 'Asked for a change: ${request.reason}',
        warn: true,
        action: state.isCreator(s)
            ? TextButton(
                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32)),
                onPressed: () => context.push('/sheet/${s.id}'),
                child: Text('Review the request', style: T.body(14, color: C.accent, weight: FontWeight.w700)),
              )
            : null,
      );
    }
    if (s.status != SheetStatus.pending) {
      return TimelineItem(title: c.displayName, subtitle: 'Did not sign');
    }
    final holder = s.claims[i];
    final isMeSlot = holder != null && holder == state.uid;
    if (holder != null && !isMeSlot) {
      return TimelineItem(
        title: c.displayName,
        subtitle: 'Joined on their phone · reviewing ${fmtPct(c.compositionBps)} comp · ${fmtPct(c.masterBps)} master',
      );
    }
    return TimelineItem(
      title: c.displayName,
      subtitle: 'Waiting to sign · ${fmtPct(c.compositionBps)} comp · ${fmtPct(c.masterBps)} master',
      action: _SignHereButton(
        label: isMeSlot ? 'Review and sign' : 'Sign on this phone',
        onTap: () => context.push('/sheet/${s.id}/sign/$i'),
      ),
    );
  }
}

class _SignHereButton extends StatelessWidget {
  const _SignHereButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: C.accentBg,
      shape: const StadiumBorder(side: BorderSide(color: C.lineWarm)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.draw_rounded, size: 16, color: C.accent),
            const SizedBox(width: 6),
            Text(label, style: T.body(13, color: C.accentSoft, weight: FontWeight.w700)),
          ]),
        ),
      ),
    );
  }
}

class _LockedBanner extends StatelessWidget {
  const _LockedBanner({required this.sheet});
  final SplitSheet sheet;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: C.greenBg,
          shape: BoxShape.circle,
          border: Border.all(color: C.green, width: 2),
        ),
        child: const Icon(Icons.check_rounded, color: C.green, size: 40),
      ),
      const SizedBox(height: 14),
      Text('${sheet.title} is locked in', textAlign: TextAlign.center, style: T.display(28)),
      const SizedBox(height: 6),
      Text('All ${sheet.contributors.length} signed · ${fmtDateTime(sheet.executedAt!)}',
          textAlign: TextAlign.center, style: T.body(14, color: C.muted)),
      const SizedBox(height: 18),
      PrimaryButton(
        label: 'View signed sheet',
        icon: Icons.description_rounded,
        onPressed: () => context.go('/sheet/${sheet.id}'),
      ),
    ]);
  }
}
