import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import '../widgets/sheet_widgets.dart';

enum _Filter { all, me, others, executed }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  _Filter _filter = _Filter.all;
  bool _seeding = false;

  Future<void> _seed() async {
    setState(() => _seeding = true);
    try {
      await context.read<AppState>().seedDemo();
    } catch (e) {
      if (mounted) showSnack(context, 'Could not load the demo: $e');
    }
    if (mounted) setState(() => _seeding = false);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final user = state.user;
    if (user == null) return const SizedBox.shrink();

    final all = state.allSheets;
    final mine = all.where(state.awaitingMe).toList();
    final others = all.where(state.awaitingOthers).toList();
    final done = all.where((s) => s.status == SheetStatus.executed).toList();
    final List<SplitSheet> shown;
    switch (_filter) {
      case _Filter.all:
        shown = all;
        break;
      case _Filter.me:
        shown = mine;
        break;
      case _Filter.others:
        shown = others;
        break;
      case _Filter.executed:
        shown = done;
        break;
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(greeting(), style: T.body(14, color: C.muted)),
              const SizedBox(height: 2),
              Text(user.displayName, overflow: TextOverflow.ellipsis, style: T.display(28)),
            ]),
          ),
          InkWell(
            customBorder: const CircleBorder(),
            onTap: () => context.go('/profile'),
            child: Avatar(user.displayName, size: 44),
          ),
        ]),
        const SizedBox(height: 20),
        if (all.isEmpty)
          _EmptyState(seeding: _seeding, onSeed: _seed)
        else ...[
          PrimaryButton(label: 'New split sheet', icon: Icons.add_rounded, onPressed: () => context.push('/new')),
          const SizedBox(height: 18),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              SelectChip(label: 'All', selected: _filter == _Filter.all, onTap: () => setState(() => _filter = _Filter.all)),
              const SizedBox(width: 8),
              SelectChip(label: 'Awaiting me · ${mine.length}', selected: _filter == _Filter.me, onTap: () => setState(() => _filter = _Filter.me)),
              const SizedBox(width: 8),
              SelectChip(label: 'Others · ${others.length}', selected: _filter == _Filter.others, onTap: () => setState(() => _filter = _Filter.others)),
              const SizedBox(width: 8),
              SelectChip(label: 'Executed · ${done.length}', selected: _filter == _Filter.executed, onTap: () => setState(() => _filter = _Filter.executed)),
            ]),
          ),
          const SizedBox(height: 20),
          if (_filter == _Filter.all && all.length >= 2) ...[
            Text('Jump back in', style: T.display(20)),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 3.0,
              children: [for (final s in all.take(4)) _CompactTile(sheet: s)],
            ),
            const SizedBox(height: 24),
          ],
          if (_filter == _Filter.all && mine.isNotEmpty) ...[
            Text('Waiting on you', style: T.display(20)),
            const SizedBox(height: 12),
            SizedBox(
              height: 214,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: mine.length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (c, i) => _ShelfCard(sheet: mine[i], index: state.myIndex(mine[i]) ?? 0),
              ),
            ),
            const SizedBox(height: 12),
          ],
          SectionHeader(_filter == _Filter.all ? 'All sheets' : 'Sheets'),
          const SizedBox(height: 12),
          if (shown.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text('Nothing in this list yet.', textAlign: TextAlign.center, style: T.body(14, color: C.muted)),
            ),
          for (final s in shown) SheetTile(sheet: s),
        ],
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.seeding, required this.onSeed});
  final bool seeding;
  final VoidCallback onSeed;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.all(20),
      radius: 24,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          height: 96,
          child: Stack(children: const [
            Positioned(left: 0, top: 8, child: CoverArt('Afro', size: 80, radius: 12)),
            Positioned(left: 56, top: 0, child: CoverArt('Lagos', size: 88, radius: 12)),
            Positioned(left: 120, top: 12, child: CoverArt('Gbedu', size: 76, radius: 12)),
          ]),
        ),
        const SizedBox(height: 18),
        Text('Your first split sheet takes about three minutes.', style: T.display(24, height: 1.1)),
        const SizedBox(height: 8),
        Text('Add the song and the people in the room, agree who owns what, and everyone signs on their phone.',
            style: T.body(14, color: C.muted, height: 1.45)),
        const SizedBox(height: 20),
        PrimaryButton(label: 'New split sheet', icon: Icons.add_rounded, onPressed: () => context.push('/new')),
        const SizedBox(height: 10),
        SecondaryButton(
          label: seeding ? 'Loading demo…' : 'Load demo sheets',
          icon: Icons.auto_awesome_rounded,
          onPressed: seeding ? null : onSeed,
        ),
      ]),
    );
  }
}

class _CompactTile extends StatelessWidget {
  const _CompactTile({required this.sheet});
  final SplitSheet sheet;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: C.surface2,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/sheet/${sheet.id}'),
        child: Row(children: [
          AspectRatio(aspectRatio: 1, child: CoverArt(sheet.title, radius: 0)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(sheet.title,
                maxLines: 2, overflow: TextOverflow.ellipsis, style: T.body(13, weight: FontWeight.w700, height: 1.2)),
          ),
          const SizedBox(width: 8),
        ]),
      ),
    );
  }
}

class _ShelfCard extends StatelessWidget {
  const _ShelfCard({required this.sheet, required this.index});
  final SplitSheet sheet;
  final int index;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/sheet/${sheet.id}/sign/$index'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Stack(children: [
            CoverArt(sheet.title, size: 150, radius: 12),
            const Positioned(right: 8, bottom: 8, child: Pill('Sign now', background: C.accent, foreground: C.onAccent)),
          ]),
          const SizedBox(height: 8),
          Text(sheet.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.body(14, weight: FontWeight.w700)),
          Text('From ${sheet.creator.displayName}', maxLines: 1, overflow: TextOverflow.ellipsis, style: T.body(12, color: C.muted)),
        ]),
      ),
    );
  }
}
