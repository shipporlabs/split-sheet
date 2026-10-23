import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../theme.dart';
import '../utils/format.dart';

void showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

void goBack(BuildContext context, String fallback) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(fallback);
  }
}

Future<void> copyText(BuildContext context, String text, String what) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) showSnack(context, '$what copied');
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      backgroundColor: C.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title, style: T.display(20)),
      content: Text(message, style: T.body(15, color: C.text2, height: 1.45)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(c).pop(false),
          child: Text('Not now', style: T.body(15, color: C.muted)),
        ),
        TextButton(
          onPressed: () => Navigator.of(c).pop(true),
          child: Text(confirmLabel,
              style: T.body(15, color: destructive ? C.red : C.accent, weight: FontWeight.w700)),
        ),
      ],
    ),
  );
  return ok ?? false;
}

Future<String?> promptText(
  BuildContext context, {
  required String title,
  String initial = '',
  String? hint,
  int maxLines = 1,
}) {
  final ctl = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      backgroundColor: C.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title, style: T.display(20)),
      content: TextField(
        controller: ctl,
        autofocus: true,
        maxLines: maxLines,
        style: T.body(16),
        decoration: InputDecoration(hintText: hint),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(c).pop(),
          child: Text('Cancel', style: T.body(15, color: C.muted)),
        ),
        TextButton(
          onPressed: () => Navigator.of(c).pop(ctl.text.trim()),
          child: Text('Save', style: T.body(15, color: C.accent, weight: FontWeight.w700)),
        ),
      ],
    ),
  );
}

/// Centres the app in a phone-sized column on wide screens, so the web build feels like the app.
class PhoneFrame extends StatelessWidget {
  const PhoneFrame({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth < 600) return child;
      return ColoredBox(
        color: C.bgDeep,
        child: Center(
          child: Container(
            width: 440,
            height: double.infinity,
            margin: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: C.bg,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: C.line),
            ),
            clipBehavior: Clip.antiAlias,
            child: child,
          ),
        ),
      );
    });
  }
}

/// A column that fills the screen but scrolls when the keyboard is up.
class FillScroll extends StatelessWidget {
  const FillScroll({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.fromLTRB(24, 16, 24, 24),
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
  });

  final List<Widget> children;
  final EdgeInsets padding;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) => SingleChildScrollView(
        padding: padding,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: math.max(0.0, c.maxHeight - padding.vertical)),
          child: IntrinsicHeight(
            child: Column(crossAxisAlignment: crossAxisAlignment, children: children),
          ),
        ),
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.background = C.accent,
    this.foreground = C.onAccent,
    this.height = 56,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final Color background;
  final Color foreground;
  final double height;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: Opacity(
        opacity: enabled || loading ? 1 : 0.4,
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: Material(
            color: background,
            borderRadius: BorderRadius.circular(18),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: enabled ? onPressed : null,
              child: Center(
                child: loading
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: foreground),
                      )
                    : Row(mainAxisSize: MainAxisSize.min, children: [
                        if (icon != null) ...[
                          Icon(icon, color: foreground, size: 20),
                          const SizedBox(width: 10),
                        ],
                        Flexible(
                          child: Text(
                            label,
                            overflow: TextOverflow.ellipsis,
                            style: T.body(17, color: foreground, weight: FontWeight.w700),
                          ),
                        ),
                      ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.foreground = C.text,
    this.borderColor = C.line2,
    this.height = 52,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color foreground;
  final Color borderColor;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onPressed == null ? 0.4 : 1,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Material(
          color: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: borderColor),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: Center(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (icon != null) ...[
                  Icon(icon, color: foreground, size: 19),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: T.body(15, color: foreground, weight: FontWeight.w500),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class IconBox extends StatelessWidget {
  const IconBox({super.key, required this.icon, required this.onTap, required this.tooltip});
  final IconData icon;
  final VoidCallback? onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: C.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(width: 44, height: 44, child: Icon(icon, size: 20, color: C.text)),
        ),
      ),
    );
  }
}

/// Back button, centred label, optional trailing widget.
class TopBar extends StatelessWidget {
  const TopBar({super.key, this.onBack, this.label, this.trailing, this.icon = Icons.arrow_back_rounded});
  final VoidCallback? onBack;
  final String? label;
  final Widget? trailing;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      if (onBack != null)
        IconBox(icon: icon, onTap: onBack, tooltip: icon == Icons.close_rounded ? 'Close' : 'Back')
      else
        const SizedBox(width: 44),
      Expanded(
        child: Text(
          label ?? '',
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: T.body(13, color: C.muted),
        ),
      ),
      trailing ?? const SizedBox(width: 44),
    ]);
  }
}

class StepBar extends StatelessWidget {
  const StepBar({super.key, required this.filled, this.total = 4});
  final int filled;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      for (var i = 0; i < total; i++) ...[
        if (i > 0) const SizedBox(width: 6),
        Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            height: 4,
            decoration: BoxDecoration(
              color: i < filled ? C.accent : C.line,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
      ],
    ]);
  }
}

class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color = C.surface,
    this.borderColor = C.line,
    this.radius = 18,
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color color;
  final Color borderColor;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(padding: padding, child: child);
    return Material(
      color: color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: BorderSide(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );
  }
}

class Pill extends StatelessWidget {
  const Pill(this.label, {super.key, this.background = C.surface2, this.foreground = C.text, this.border});
  final String label;
  final Color background;
  final Color foreground;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: border == null ? null : Border.all(color: border!),
      ),
      child: Text(label, style: T.body(12, color: foreground, weight: FontWeight.w700)),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill(this.status, {super.key});
  final SheetStatus status;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case SheetStatus.executed:
        return const Pill('Executed', background: C.green, foreground: C.onGreen);
      case SheetStatus.pending:
        return const Pill('Pending');
      case SheetStatus.superseded:
        return const Pill('Superseded', background: C.line, foreground: C.muted);
      case SheetStatus.cancelled:
        return const Pill('Cancelled', background: C.redBg, foreground: C.red, border: C.redLine);
      case SheetStatus.draft:
        return const Pill('Draft');
    }
  }
}

/// Horizontal bar showing each person's share.
class SplitBar extends StatelessWidget {
  const SplitBar({super.key, required this.bps, this.height = 12});
  final List<int> bps;
  final double height;

  @override
  Widget build(BuildContext context) {
    final total = bps.fold<int>(0, (a, b) => a + b);
    final indices = [for (var i = 0; i < bps.length; i++) if (bps[i] > 0) i];
    final rest = 10000 - total;
    return Semantics(
      label: 'Split: ${[for (final i in indices) fmtPct(bps[i])].join(', ')}',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: SizedBox(
          height: height,
          child: Row(children: [
            for (var k = 0; k < indices.length; k++)
              Expanded(
                flex: bps[indices[k]],
                child: Container(
                  margin: EdgeInsets.only(left: k == 0 ? 0 : 3),
                  color: C.split(indices[k]),
                ),
              ),
            if (rest > 0)
              Expanded(
                flex: rest,
                child: Container(margin: EdgeInsets.only(left: indices.isEmpty ? 0 : 3), color: C.line),
              ),
            if (indices.isEmpty && rest <= 0) Expanded(child: Container(color: C.line)),
          ]),
        ),
      ),
    );
  }
}

/// Generated "album art" for a song: a gradient picked from the title, Spotify-style.
class CoverArt extends StatelessWidget {
  const CoverArt(this.title, {super.key, this.size, this.radius = 10});
  final String title;
  final double? size;
  final double radius;

  static const List<List<Color>> _pairs = [
    [Color(0xFFF4B740), Color(0xFF6B2F10)],
    [Color(0xFF5FD3A6), Color(0xFF103844)],
    [Color(0xFF9CC3FF), Color(0xFF271B57)],
    [Color(0xFFF08A5D), Color(0xFF45122C)],
    [Color(0xFFE8C98F), Color(0xFF3B2A12)],
    [Color(0xFFB79CFF), Color(0xFF1C2747)],
  ];

  static List<Color> colorsFor(String title) {
    final h = title.codeUnits.fold<int>(7, (a, b) => (a * 31 + b) & 0x7fffffff);
    return _pairs[h % _pairs.length];
  }

  @override
  Widget build(BuildContext context) {
    final colors = colorsFor(title);
    final t = title.trim();
    final letter = t.isEmpty ? '?' : t.substring(0, 1).toUpperCase();
    Widget art(double s) => Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(children: [
            Positioned(
              right: -s * 0.08,
              bottom: -s * 0.32,
              child: Text(letter, style: T.display(s * 1.0, color: const Color(0x33000000), height: 1)),
            ),
            Positioned(
              left: s * 0.12,
              top: s * 0.12,
              child: Icon(Icons.graphic_eq_rounded, size: s * 0.24, color: const Color(0xDDFFFFFF)),
            ),
          ]),
        );

    final fixed = size;
    if (fixed != null) return SizedBox(width: fixed, height: fixed, child: art(fixed));
    return LayoutBuilder(builder: (context, c) {
      final s = c.maxWidth.isFinite ? c.maxWidth : 56.0;
      return SizedBox(width: s, height: c.maxHeight.isFinite ? c.maxHeight : s, child: art(s));
    });
  }
}

class Avatar extends StatelessWidget {
  const Avatar(this.name, {super.key, this.size = 40, this.foreground = C.accent, this.background = C.accentBg});
  final String name;
  final double size;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: Text(initials(name), style: T.body(size * 0.36, color: foreground, weight: FontWeight.w700)),
    );
  }
}

class Dot extends StatelessWidget {
  const Dot({super.key, required this.color, this.size = 10, this.ring = false});
  final Color color;
  final double size;
  final bool ring;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: ring ? null : color,
        border: ring ? Border.all(color: color, width: 2) : null,
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Expanded(child: Text(title, style: T.display(20))),
      if (trailing != null) trailing!,
    ]);
  }
}

class SelectChip extends StatelessWidget {
  const SelectChip({super.key, required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? C.accentBg : Colors.transparent,
        shape: StadiumBorder(side: BorderSide(color: selected ? C.accent : C.line2)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Text(
              label,
              style: T.body(14, color: selected ? C.text : C.text2, weight: selected ? FontWeight.w700 : FontWeight.w400),
            ),
          ),
        ),
      ),
    );
  }
}

/// Label on the left, value on the right; mono for hashes. Optional copy action.
class InfoRow extends StatelessWidget {
  const InfoRow({super.key, required this.label, required this.value, this.mono = true, this.copyValue});
  final String label;
  final String value;
  final bool mono;
  final String? copyValue;

  @override
  Widget build(BuildContext context) {
    final valueText = Text(
      value,
      textAlign: TextAlign.right,
      overflow: TextOverflow.ellipsis,
      style: mono ? T.mono(13) : T.body(14),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Text(label, style: T.body(14, color: C.muted)),
        const SizedBox(width: 12),
        Expanded(child: Align(alignment: Alignment.centerRight, child: valueText)),
        if (copyValue != null) ...[
          const SizedBox(width: 4),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => copyText(context, copyValue!, label),
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.copy_rounded, size: 16, color: C.muted),
            ),
          ),
        ],
      ]),
    );
  }
}

/// Small coloured check / ring used in signature lists.
class SignedMark extends StatelessWidget {
  const SignedMark({super.key, required this.signed, this.size = 28});
  final bool signed;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (signed) {
      return Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(color: C.green, shape: BoxShape.circle),
        child: Icon(Icons.check_rounded, size: size * 0.55, color: C.onGreen),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: C.line2, width: 2)),
    );
  }
}

class NotFoundView extends StatelessWidget {
  const NotFoundView({super.key, this.message = 'We could not find that sheet on this device.'});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TopBar(onBack: () => goBack(context, '/home')),
            const Spacer(),
            const Icon(Icons.search_off_rounded, size: 48, color: C.muted),
            const SizedBox(height: 16),
            Text('Nothing here', textAlign: TextAlign.center, style: T.display(26)),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: T.body(15, color: C.muted)),
            const Spacer(),
            PrimaryButton(label: 'Go to my sheets', onPressed: () => context.go('/home')),
          ]),
        ),
      ),
    );
  }
}
