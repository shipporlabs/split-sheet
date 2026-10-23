import 'package:flutter/material.dart';

import '../theme.dart';

class Logo extends StatelessWidget {
  const Logo({super.key, this.size = 28, this.withText = true});
  final double size;
  final bool withText;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Split Sheet',
      excludeSemantics: true,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(width: size, height: size, child: CustomPaint(painter: _LogoPainter())),
        if (withText) ...[
          SizedBox(width: size * 0.36),
          Text('Split Sheet', style: T.display(size * 0.72)),
        ],
      ]),
    );
  }
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 28;
    final fill = Paint()..color = C.accent;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(2 * s, 4 * s, 10 * s, 20 * s), Radius.circular(3 * s)),
      fill,
    );
    final outline = Paint()
      ..color = C.text
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * s;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(16 * s, 5 * s, 9 * s, 10 * s), Radius.circular(2.5 * s)),
      outline,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(15 * s, 19 * s, 11 * s, 5 * s), Radius.circular(2.5 * s)),
      Paint()..color = C.text,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
