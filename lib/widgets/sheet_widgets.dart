import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../utils/format.dart';
import 'common.dart';

/// Dots per person, filled when signed.
class ProgressDots extends StatelessWidget {
  const ProgressDots({super.key, required this.sheet, this.awaitingMe = false});
  final SplitSheet sheet;
  final bool awaitingMe;

  @override
  Widget build(BuildContext context) {
    final n = sheet.contributors.length;
    final text = sheet.status == SheetStatus.executed
        ? '$n of $n signed'
        : '${sheet.signedCount} of $n signed${awaitingMe ? ' · you are next' : ''}';
    return Row(children: [
      for (var i = 0; i < n && i < 8; i++)
        Padding(
          padding: const EdgeInsets.only(right: 5),
          child: Dot(color: sheet.isSigned(i) ? C.green : C.faint, ring: !sheet.isSigned(i)),
        ),
      const SizedBox(width: 4),
      Flexible(child: Text(text, overflow: TextOverflow.ellipsis, style: T.body(13, color: C.text2))),
    ]);
  }
}

/// List row for a sheet on the home screen.
class SheetTile extends StatelessWidget {
  const SheetTile({super.key, required this.sheet});
  final SplitSheet sheet;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final me = state.myIndex(sheet);
    final awaiting = state.awaitingMe(sheet);
    final subtitle = state.isCreator(sheet)
        ? 'Created by you · ${relDay(sheet.createdAt)}'
        : 'Invited by ${sheet.creator.displayName} · ${relDay(sheet.createdAt)}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SurfaceCard(
        borderColor: awaiting ? C.lineWarm : C.line,
        padding: const EdgeInsets.all(12),
        onTap: () {
          if (awaiting && me != null) {
            context.push('/sheet/${sheet.id}/sign/$me');
          } else {
            context.push('/sheet/${sheet.id}');
          }
        },
        child: Row(children: [
          CoverArt(sheet.title, size: 56, radius: 10),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(sheet.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.body(16, weight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.body(13, color: C.muted)),
              const SizedBox(height: 8),
              ProgressDots(sheet: sheet, awaitingMe: awaiting),
            ]),
          ),
          const SizedBox(width: 8),
          awaiting ? const Pill('Sign now', background: C.accent, foreground: C.onAccent) : StatusPill(sheet.status),
        ]),
      ),
    );
  }
}

/// Read-only table of both splits.
class SplitTable extends StatelessWidget {
  const SplitTable({super.key, required this.sheet, this.highlight});
  final SplitSheet sheet;
  final int? highlight;

  @override
  Widget build(BuildContext context) {
    Widget row(List<Widget> cells, {Color? color}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: DefaultTextStyle.merge(
            style: TextStyle(color: color),
            child: Row(children: [
              Expanded(flex: 5, child: cells[0]),
              Expanded(flex: 2, child: Align(alignment: Alignment.centerRight, child: cells[1])),
              Expanded(flex: 2, child: Align(alignment: Alignment.centerRight, child: cells[2])),
            ]),
          ),
        );

    final comp = sheet.bpsFor(SplitType.composition);
    final master = sheet.bpsFor(SplitType.master);
    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Column(children: [
        row([
          Text('Contributor', style: T.body(12, color: C.muted)),
          Text('Comp.', style: T.body(12, color: C.muted)),
          Text('Master', style: T.body(12, color: C.muted)),
        ]),
        for (var i = 0; i < sheet.contributors.length; i++)
          row([
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                i == highlight ? '${sheet.contributors[i].displayName} (you)' : sheet.contributors[i].displayName,
                overflow: TextOverflow.ellipsis,
                style: T.body(14, color: i == highlight ? C.accentSoft : C.text, weight: FontWeight.w500),
              ),
              Text(sheet.contributors[i].rolesLabel,
                  overflow: TextOverflow.ellipsis, style: T.body(12, color: C.muted)),
            ]),
            Text(fmtPct(comp[i]), style: T.mono(14, color: i == highlight ? C.accentSoft : C.text)),
            Text(fmtPct(master[i]), style: T.mono(14, color: i == highlight ? C.accentSoft : C.text)),
          ]),
        const Divider(height: 14),
        row([
          Text('Total', style: T.body(14, color: C.text2)),
          Text('100%', style: T.mono(14, color: C.green)),
          Text('100%', style: T.mono(14, color: C.green)),
        ]),
      ]),
    );
  }
}

/// File name plus fingerprint of the recording.
class AudioCard extends StatelessWidget {
  const AudioCard({super.key, required this.sheet, this.trailing});
  final SplitSheet sheet;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: C.accentBg, borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.graphic_eq_rounded, color: C.accent, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(sheet.audioName ?? 'No recording attached',
                overflow: TextOverflow.ellipsis, style: T.body(14, weight: FontWeight.w500)),
            const SizedBox(height: 2),
            Text(groupedHash(sheet.audioHash), overflow: TextOverflow.ellipsis, style: T.mono(12, color: C.muted)),
          ]),
        ),
        if (trailing != null) trailing!,
      ]),
    );
  }
}

class TimelineItem {
  const TimelineItem({required this.title, this.subtitle, this.done = false, this.warn = false, this.action});
  final String title;
  final String? subtitle;
  final bool done;
  final bool warn;
  final Widget? action;
}

/// Vertical tracker, like following a delivery: each step with a line to the next.
class Timeline extends StatelessWidget {
  const Timeline({super.key, required this.items});
  final List<TimelineItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      for (var i = 0; i < items.length; i++)
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(
              width: 28,
              child: Column(children: [
                _mark(items[i]),
                if (i < items.length - 1)
                  Expanded(
                    child: Center(
                      child: Container(width: 2, color: items[i].done && items[i + 1].done ? C.green : C.line2),
                    ),
                  ),
              ]),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(top: 3, bottom: i < items.length - 1 ? 18 : 0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(items[i].title, style: T.body(15, weight: FontWeight.w500)),
                  if (items[i].subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(items[i].subtitle!,
                        style: T.body(13, color: items[i].warn ? C.accentSoft : C.muted)),
                  ],
                  if (items[i].action != null) ...[
                    const SizedBox(height: 8),
                    items[i].action!,
                  ],
                ]),
              ),
            ),
          ]),
        ),
    ]);
  }

  Widget _mark(TimelineItem it) {
    if (it.done) return const SignedMark(signed: true);
    if (it.warn) {
      return Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: C.accent, width: 2)),
        child: const Icon(Icons.priority_high_rounded, size: 16, color: C.accent),
      );
    }
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: C.line2, width: 2)),
      child: Center(child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: C.faint, shape: BoxShape.circle))),
    );
  }
}

/// Composition / master toggle.
class SplitTabs extends StatelessWidget {
  const SplitTabs({super.key, required this.value, required this.onChanged, this.doneComposition = false});
  final SplitType value;
  final ValueChanged<SplitType> onChanged;
  final bool doneComposition;

  @override
  Widget build(BuildContext context) {
    Widget tab(SplitType t) {
      final selected = value == t;
      return Expanded(
        child: Semantics(
          selected: selected,
          button: true,
          child: Material(
            color: selected ? C.surface2 : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => onChanged(t),
              child: SizedBox(
                height: 40,
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  if (t == SplitType.composition && doneComposition && !selected) ...[
                    const Icon(Icons.check_rounded, size: 15, color: C.green),
                    const SizedBox(width: 6),
                  ],
                  Text(t.label,
                      style: T.body(14,
                          color: selected ? C.text : C.muted,
                          weight: selected ? FontWeight.w700 : FontWeight.w500)),
                ]),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: C.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: C.line),
      ),
      child: Row(children: [tab(SplitType.composition), const SizedBox(width: 4), tab(SplitType.master)]),
    );
  }
}
