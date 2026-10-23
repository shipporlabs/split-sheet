import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../utils/splits.dart';
import 'common.dart';

/// Percent inputs for one split, with a live total and bar.
class SplitEditor extends StatefulWidget {
  const SplitEditor({
    super.key,
    required this.contributors,
    required this.initial,
    required this.onChanged,
    this.subtitleFor,
  });

  final List<Contributor> contributors;
  final List<int> initial;
  final ValueChanged<List<int>> onChanged;
  final String Function(int index)? subtitleFor;

  @override
  State<SplitEditor> createState() => _SplitEditorState();
}

class _SplitEditorState extends State<SplitEditor> {
  late List<int> _values;
  late List<TextEditingController> _ctls;

  @override
  void initState() {
    super.initState();
    _values = List<int>.of(widget.initial);
    _ctls = [for (final v in _values) TextEditingController(text: fmtPctPlain(v))];
  }

  @override
  void dispose() {
    for (final c in _ctls) {
      c.dispose();
    }
    super.dispose();
  }

  void _onText(int i, String text) {
    final d = double.tryParse(text.replaceAll('%', '').replaceAll(',', '.').trim()) ?? 0;
    setState(() => _values[i] = (d * 100).round().clamp(0, fullBps).toInt());
    widget.onChanged(List<int>.of(_values));
  }

  void _setAll(List<int> values) {
    setState(() {
      _values = List<int>.of(values);
      for (var i = 0; i < _ctls.length; i++) {
        _ctls[i].text = fmtPctPlain(_values[i]);
      }
    });
    widget.onChanged(List<int>.of(_values));
  }

  void _giveRemainder(int i) {
    final rest = fullBps - sumBps(_values);
    if (rest <= 0) return;
    final next = List<int>.of(_values);
    next[i] += rest;
    _setAll(next);
  }

  @override
  Widget build(BuildContext context) {
    final total = sumBps(_values);
    final rest = fullBps - total;
    final ok = total == fullBps;
    final statusColor = ok ? C.green : (rest < 0 ? C.red : C.accentSoft);
    final statusText = ok ? 'ready' : (rest < 0 ? '${fmtPct(-rest)} over' : '${fmtPct(rest)} left');

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Text('Total', style: T.body(14, color: C.text2)),
        const Spacer(),
        Text(fmtPct(total), style: T.mono(15, color: statusColor, weight: FontWeight.w500)),
        Text('  ·  $statusText', style: T.body(13, color: statusColor)),
      ]),
      const SizedBox(height: 10),
      SplitBar(bps: _values, height: 12),
      const SizedBox(height: 16),
      for (var i = 0; i < widget.contributors.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: SurfaceCard(
            padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
            child: Row(children: [
              Dot(color: _values[i] > 0 ? C.split(i) : C.line2, ring: _values[i] == 0),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.contributors[i].displayName,
                      overflow: TextOverflow.ellipsis, style: T.body(15, weight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(
                    widget.subtitleFor?.call(i) ?? widget.contributors[i].rolesLabel,
                    overflow: TextOverflow.ellipsis,
                    style: T.body(12, color: C.muted),
                  ),
                ]),
              ),
              if (rest > 0)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Tooltip(
                    message: 'Give the remaining ${fmtPct(rest)}',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => _giveRemainder(i),
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(Icons.add_circle_outline_rounded, size: 20, color: C.muted),
                      ),
                    ),
                  ),
                ),
              SizedBox(
                width: 96,
                child: TextField(
                  controller: _ctls[i],
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.right,
                  style: T.mono(16),
                  onChanged: (t) => _onText(i, t),
                  decoration: InputDecoration(
                    isDense: true,
                    fillColor: C.bg,
                    suffixText: '%',
                    suffixStyle: T.mono(15, color: C.muted),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
              ),
            ]),
          ),
        ),
      Align(
        alignment: Alignment.centerLeft,
        child: Wrap(spacing: 8, runSpacing: 8, children: [
          SelectChip(
            label: 'Split equally',
            selected: false,
            onTap: () => _setAll(equalSplit(widget.contributors.length)),
          ),
          SelectChip(
            label: 'Clear',
            selected: false,
            onTap: () => _setAll(List<int>.filled(widget.contributors.length, 0)),
          ),
        ]),
      ),
    ]);
  }
}
