import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme.dart';
import 'common.dart';

BoxConstraints get _sheetConstraints => const BoxConstraints(maxWidth: 440);

/// Bottom sheet to add or edit a contributor.
Future<Contributor?> showContributorSheet(BuildContext context, {Contributor? initial}) {
  return showModalBottomSheet<Contributor>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: _sheetConstraints,
    builder: (c) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(c).bottom),
      child: _ContributorForm(initial: initial),
    ),
  );
}

class _ContributorForm extends StatefulWidget {
  const _ContributorForm({this.initial});
  final Contributor? initial;

  @override
  State<_ContributorForm> createState() => _ContributorFormState();
}

class _ContributorFormState extends State<_ContributorForm> {
  late final TextEditingController _name = TextEditingController(text: widget.initial?.name ?? '');
  late final TextEditingController _stage = TextEditingController(text: widget.initial?.stageName ?? '');
  late final Set<String> _roles = {...(widget.initial?.roles ?? const <String>[])};
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _stage.dispose();
    super.dispose();
  }

  void _save() {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Add their legal name');
      return;
    }
    if (_roles.isEmpty) {
      setState(() => _error = 'Pick at least one role');
      return;
    }
    final base = widget.initial;
    final roles = [for (final r in kRoles) if (_roles.contains(r)) r];
    final next = base == null
        ? Contributor(name: _name.text.trim(), stageName: _stage.text.trim(), roles: roles)
        : base.copyWith(name: _name.text.trim(), stageName: _stage.text.trim(), roles: roles);
    Navigator.of(context).pop(next);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: C.line2, borderRadius: BorderRadius.circular(999)),
          ),
        ),
        const SizedBox(height: 18),
        Text(widget.initial == null ? 'Add a contributor' : 'Edit contributor', style: T.display(24)),
        const SizedBox(height: 6),
        Text('Use the name on their ID. The stage name is what people know them by.',
            style: T.body(14, color: C.muted, height: 1.4)),
        const SizedBox(height: 18),
        TextField(
          controller: _name,
          autofocus: widget.initial == null,
          textCapitalization: TextCapitalization.words,
          style: T.body(16),
          decoration: const InputDecoration(labelText: 'Legal name'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _stage,
          textCapitalization: TextCapitalization.words,
          style: T.body(16),
          decoration: const InputDecoration(labelText: 'Stage name (optional)'),
        ),
        const SizedBox(height: 18),
        Text('Role in this song', style: T.body(14, color: C.muted)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final r in kRoles)
            SelectChip(
              label: r,
              selected: _roles.contains(r),
              onTap: () => setState(() {
                if (!_roles.remove(r)) _roles.add(r);
                _error = null;
              }),
            ),
        ]),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: T.body(13, color: C.red)),
        ],
        const SizedBox(height: 22),
        PrimaryButton(label: widget.initial == null ? 'Add to sheet' : 'Save changes', onPressed: _save),
      ]),
    );
  }
}

/// PIN entry sheet. With [validate], a wrong PIN shows an error. With [createNew], the PIN is
/// entered twice and returned (used by collaborators signing on someone else's phone).
Future<String?> showPinSheet(
  BuildContext context, {
  required String title,
  String? subtitle,
  String? summary,
  bool Function(String pin)? validate,
  bool createNew = false,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: _sheetConstraints,
    builder: (c) => _PinSheet(
      title: title,
      subtitle: subtitle,
      summary: summary,
      validate: validate,
      createNew: createNew,
    ),
  );
}

class _PinSheet extends StatefulWidget {
  const _PinSheet({required this.title, this.subtitle, this.summary, this.validate, required this.createNew});
  final String title;
  final String? subtitle;
  final String? summary;
  final bool Function(String pin)? validate;
  final bool createNew;

  @override
  State<_PinSheet> createState() => _PinSheetState();
}

class _PinSheetState extends State<_PinSheet> {
  String _pin = '';
  String? _first;
  String? _error;
  bool _locked = false;

  String get _heading {
    if (widget.createNew) return _first == null ? widget.title : 'Enter it again';
    return widget.title;
  }

  void _tap(String d) {
    if (_locked || _pin.length >= 4) return;
    setState(() {
      _pin += d;
      _error = null;
    });
    if (_pin.length == 4) {
      _locked = true;
      Future<void>.delayed(const Duration(milliseconds: 140), _complete);
    }
  }

  void _back() {
    if (_locked || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  void _complete() {
    if (!mounted) return;
    final pin = _pin;
    if (widget.createNew) {
      if (_first == null) {
        setState(() {
          _first = pin;
          _pin = '';
          _locked = false;
        });
        return;
      }
      if (_first != pin) {
        setState(() {
          _first = null;
          _pin = '';
          _locked = false;
          _error = 'Those PINs did not match. Start again.';
        });
        return;
      }
      Navigator.of(context).pop(pin);
      return;
    }
    final v = widget.validate;
    if (v != null && !v(pin)) {
      setState(() {
        _pin = '';
        _locked = false;
        _error = 'Wrong PIN. Try again.';
      });
      return;
    }
    Navigator.of(context).pop(pin);
  }

  Widget _key(String label) => Expanded(
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Material(
            color: C.surface2,
            borderRadius: BorderRadius.circular(14),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _tap(label),
              child: SizedBox(height: 56, child: Center(child: Text(label, style: T.body(22)))),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: C.line2, borderRadius: BorderRadius.circular(999)),
          ),
        ),
        const SizedBox(height: 18),
        Text(_heading, textAlign: TextAlign.center, style: T.display(24)),
        if (widget.subtitle != null) ...[
          const SizedBox(height: 6),
          Text(widget.subtitle!, textAlign: TextAlign.center, style: T.body(14, color: C.muted)),
        ],
        if (widget.summary != null) ...[
          const SizedBox(height: 16),
          SurfaceCard(
            color: C.surfaceWarm,
            borderColor: C.lineWarm,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Text(widget.summary!, textAlign: TextAlign.center, style: T.body(14, weight: FontWeight.w700)),
          ),
        ],
        const SizedBox(height: 22),
        Semantics(
          label: '${_pin.length} of 4 digits entered',
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 0; i < 4; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Dot(color: i < _pin.length ? C.accent : C.faint, size: 16, ring: i >= _pin.length),
              ),
          ]),
        ),
        SizedBox(
          height: 28,
          child: Center(child: Text(_error ?? '', style: T.body(13, color: C.red))),
        ),
        Row(children: [_key('1'), _key('2'), _key('3')]),
        Row(children: [_key('4'), _key('5'), _key('6')]),
        Row(children: [_key('7'), _key('8'), _key('9')]),
        Row(children: [
          const Expanded(child: SizedBox(height: 66)),
          _key('0'),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(5),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _back,
                child: const SizedBox(
                  height: 56,
                  child: Center(child: Icon(Icons.backspace_outlined, color: C.text, semanticLabel: 'Delete')),
                ),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel', style: T.body(15, color: C.muted)),
        ),
      ]),
    );
  }
}
