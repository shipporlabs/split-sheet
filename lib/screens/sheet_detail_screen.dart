import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/pdf_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import '../widgets/sheet_widgets.dart';

/// Album-page style view of one sheet: cover, status, splits, proof and history.
class SheetDetailScreen extends StatefulWidget {
  const SheetDetailScreen({super.key, required this.id});
  final String id;

  @override
  State<SheetDetailScreen> createState() => _SheetDetailScreenState();
}

class _SheetDetailScreenState extends State<SheetDetailScreen> {
  SplitType _tab = SplitType.composition;
  bool _pdfBusy = false;

  Future<void> _pdf(AppState state, SplitSheet s) async {
    setState(() => _pdfBusy = true);
    try {
      await PdfService.share(s, networkName: state.chain.networkName);
    } catch (e) {
      if (mounted) showSnack(context, 'Could not create the PDF: $e');
    }
    if (mounted) setState(() => _pdfBusy = false);
  }

  Future<void> _cancel(AppState state, SplitSheet s) async {
    final ok = await confirmDialog(
      context,
      title: 'Cancel this sheet?',
      message: 'Signatures collected so far will no longer count. You can start a new version any time.',
      confirmLabel: 'Cancel sheet',
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await state.cancelSheet(s.id);
      if (mounted) showSnack(context, 'Sheet cancelled');
    } catch (e) {
      if (mounted) showSnack(context, '$e');
    }
  }

  void _amend(AppState state, SplitSheet s) {
    context.push('/new', extra: state.draftFromSheet(s));
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = state.byId(widget.id);
    if (s == null) return const NotFoundView();
    final isCreator = state.isCreator(s);
    final me = state.myIndex(s);
    final awaitingMe = state.awaitingMe(s);
    final colors = CoverArt.colorsFor(s.title);
    final meta = [fmtDate(s.sessionDate), if (s.studio.isNotEmpty) s.studio, if (s.genre.isNotEmpty) s.genre];
    final payouts = state.payoutsFor(s.id);
    final isParty = me != null;

    return Scaffold(
      body: CustomScrollView(slivers: [
        SliverToBoxAdapter(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [withA(colors.first, 0.38), C.bg],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  TopBar(onBack: () => goBack(context, '/home'), label: 'Version ${s.version}'),
                  const SizedBox(height: 18),
                  Center(child: CoverArt(s.title, size: 176, radius: 16)),
                  const SizedBox(height: 22),
                  Text(s.title, style: T.display(30)),
                  const SizedBox(height: 4),
                  Text(meta.join(' · '), style: T.body(13, color: C.text2)),
                  const SizedBox(height: 12),
                  Row(children: [
                    StatusPill(s.status),
                    const SizedBox(width: 10),
                    Expanded(child: ProgressDots(sheet: s, awaitingMe: awaitingMe)),
                  ]),
                ]),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
          sliver: SliverToBoxAdapter(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              ..._statusSection(state, s, isCreator, me, awaitingMe),
              ..._requestsSection(state, s, isCreator),
              const SizedBox(height: 24),
              SectionHeader('Splits'),
              const SizedBox(height: 12),
              SplitTabs(value: _tab, onChanged: (t) => setState(() => _tab = t)),
              const SizedBox(height: 14),
              SplitBar(bps: s.bpsFor(_tab)),
              const SizedBox(height: 12),
              for (var i = 0; i < s.contributors.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(children: [
                    Dot(color: s.contributors[i].bps(_tab) > 0 ? C.split(i) : C.line2, ring: s.contributors[i].bps(_tab) == 0),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(i == me ? '${s.contributors[i].displayName} (you)' : s.contributors[i].displayName,
                            overflow: TextOverflow.ellipsis, style: T.body(15, weight: FontWeight.w500)),
                        Text(s.contributors[i].rolesLabel, overflow: TextOverflow.ellipsis, style: T.body(12, color: C.muted)),
                      ]),
                    ),
                    Text(fmtPct(s.contributors[i].bps(_tab)), style: T.mono(15)),
                    const SizedBox(width: 12),
                    SignedMark(signed: s.isSigned(i), size: 22),
                  ]),
                ),
              const SizedBox(height: 24),
              SectionHeader('Recording'),
              const SizedBox(height: 12),
              AudioCard(sheet: s),
              const SizedBox(height: 24),
              SectionHeader('Proof'),
              const SizedBox(height: 8),
              SurfaceCard(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                child: Column(children: [
                  InfoRow(label: 'Sheet ID', value: s.id, copyValue: s.id),
                  InfoRow(label: 'Document hash', value: shortHex(s.docHash, head: 8, tail: 6), copyValue: s.docHash),
                  InfoRow(label: 'Audio fingerprint', value: shortHex(s.audioHash, head: 8, tail: 6), copyValue: s.audioHash),
                  InfoRow(label: 'Creation record', value: shortHex(s.createdTxHash, head: 8, tail: 6), copyValue: s.createdTxHash),
                  InfoRow(label: 'Network', value: state.chain.networkName, mono: false),
                ]),
              ),
              const SizedBox(height: 24),
              SectionHeader('History'),
              const SizedBox(height: 14),
              Timeline(items: _history(s, payouts)),
              const SizedBox(height: 28),
              if (isParty && (s.status == SheetStatus.executed || (s.status == SheetStatus.pending && isCreator)))
                TextButton(
                  onPressed: () => _amend(state, s),
                  child: Text('Propose an amendment', style: T.body(15, color: C.text2)),
                ),
              if (s.status == SheetStatus.pending && isCreator)
                TextButton(
                  onPressed: () => _cancel(state, s),
                  child: Text('Cancel this sheet', style: T.body(15, color: C.red)),
                ),
            ]),
          ),
        ),
      ]),
    );
  }

  List<Widget> _statusSection(AppState state, SplitSheet s, bool isCreator, int? me, bool awaitingMe) {
    switch (s.status) {
      case SheetStatus.executed:
        return [
          SurfaceCard(
            color: C.greenBg,
            borderColor: C.greenLine,
            child: Row(children: [
              const Icon(Icons.verified_rounded, color: C.green, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Locked in', style: T.body(16, weight: FontWeight.w700)),
                  Text('All ${s.contributors.length} signed · ${fmtDateTime(s.executedAt!)}',
                      style: T.body(13, color: C.text2)),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 14),
          PrimaryButton(
            label: 'Download signed PDF',
            icon: Icons.download_rounded,
            loading: _pdfBusy,
            onPressed: () => _pdf(state, s),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: SecondaryButton(
                label: 'Verify page',
                icon: Icons.travel_explore_rounded,
                onPressed: () => context.push('/verify/${s.id}'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SecondaryButton(
                label: 'Pay royalties',
                icon: Icons.payments_outlined,
                onPressed: () => context.push('/deposit/${s.id}'),
              ),
            ),
          ]),
        ];
      case SheetStatus.pending:
        return [
          SurfaceCard(
            color: C.surfaceWarm,
            borderColor: C.lineWarm,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(awaitingMe ? 'Waiting on your signature' : 'Collecting signatures',
                  style: T.body(16, weight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('${s.signedCount} of ${s.contributors.length} signed. Code ${s.inviteCode}',
                  style: T.body(13, color: C.text2)),
              const SizedBox(height: 14),
              if (awaitingMe && me != null)
                PrimaryButton(
                  label: 'Review and sign',
                  icon: Icons.draw_rounded,
                  onPressed: () => context.push('/sheet/${s.id}/sign/$me'),
                )
              else
                PrimaryButton(
                  label: 'Collect signatures',
                  icon: Icons.qr_code_2_rounded,
                  onPressed: () => context.push('/sheet/${s.id}/invite'),
                ),
            ]),
          ),
        ];
      case SheetStatus.superseded:
      case SheetStatus.cancelled:
        final next = s.supersededBy == null ? null : state.byId(s.supersededBy!);
        return [
          SurfaceCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(s.status == SheetStatus.superseded ? 'Replaced by a newer version' : 'Cancelled',
                  style: T.body(16, weight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                s.status == SheetStatus.superseded
                    ? 'Kept for the record. The newer signed version is the one that counts.'
                    : 'This version was never fully signed and does not count.',
                style: T.body(13, color: C.text2, height: 1.4),
              ),
              if (next != null) ...[
                const SizedBox(height: 12),
                SecondaryButton(
                  label: 'Open version ${next.version}',
                  onPressed: () => context.push('/sheet/${next.id}'),
                ),
              ],
            ]),
          ),
        ];
      case SheetStatus.draft:
        return const [];
    }
  }

  List<Widget> _requestsSection(AppState state, SplitSheet s, bool isCreator) {
    final open = s.openRequests;
    if (open.isEmpty || s.status != SheetStatus.pending) return const [];
    return [
      const SizedBox(height: 14),
      SurfaceCard(
        color: C.surfaceWarm,
        borderColor: C.accent,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const Icon(Icons.feedback_outlined, color: C.accent, size: 20),
            const SizedBox(width: 8),
            Text(open.length == 1 ? 'A change was requested' : '${open.length} changes requested',
                style: T.body(15, weight: FontWeight.w700)),
          ]),
          const SizedBox(height: 10),
          for (final r in open)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${s.contributors[r.contributorIndex].displayName} · ${r.declined ? 'Declined' : r.reason}',
                    style: T.body(14, color: C.accentSoft, weight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(r.note, style: T.body(14, color: C.text2, height: 1.4)),
                if (r.suggestedCompositionBps != null)
                  Text('Suggests ${fmtPct(r.suggestedCompositionBps!)} of the composition',
                      style: T.body(13, color: C.muted)),
              ]),
            ),
          if (isCreator)
            PrimaryButton(
              label: 'Issue an updated version',
              icon: Icons.edit_note_rounded,
              onPressed: () => _amend(state, s),
            ),
        ]),
      ),
    ];
  }

  List<TimelineItem> _history(SplitSheet s, List<Payout> payouts) {
    final events = <MapEntry<DateTime, TimelineItem>>[
      MapEntry(
        s.createdAt,
        TimelineItem(
          title: s.version > 1 ? 'Version ${s.version} created' : 'Sheet created',
          subtitle: '${s.creator.displayName} · ${fmtDateTime(s.createdAt)}',
          done: true,
        ),
      ),
      for (final sig in s.signatures)
        if (sig.contributorIndex != 0)
          MapEntry(
            sig.signedAt,
            TimelineItem(
              title: '${s.contributors[sig.contributorIndex].displayName} signed',
              subtitle: fmtDateTime(sig.signedAt),
              done: true,
            ),
          ),
      for (final r in s.changeRequests)
        MapEntry(
          r.createdAt,
          TimelineItem(
            title: '${s.contributors[r.contributorIndex].displayName} ${r.declined ? 'declined' : 'asked for a change'}',
            subtitle: fmtDateTime(r.createdAt),
            warn: !r.resolved,
          ),
        ),
      if (s.executedAt != null)
        MapEntry(
          s.executedAt!,
          TimelineItem(title: 'Locked in', subtitle: fmtDateTime(s.executedAt!), done: true),
        ),
      for (final p in payouts)
        MapEntry(
          p.createdAt,
          TimelineItem(
            title: 'Royalties paid · ${fmtUsdc(p.amountMicros)} USDC',
            subtitle: '${p.splitType.label} split · ${fmtDateTime(p.createdAt)}',
            done: true,
          ),
        ),
    ];
    events.sort((a, b) => a.key.compareTo(b.key));
    return [for (final e in events) e.value];
  }
}
