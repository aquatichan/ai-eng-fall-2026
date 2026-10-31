import 'package:flutter/material.dart';

/// The AutoContact mark: two people (a crew) with a "+" badge (add to
/// Contacts) on a teal tile. Drawn in code so the sign-in screen and the
/// launcher icons (tool/render_icons_test.dart) come from one source.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 96});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'AutoContact',
      image: true,
      child: CustomPaint(size: Size.square(size), painter: const LogoPainter()),
    );
  }
}

class LogoPainter extends CustomPainter {
  const LogoPainter({this.tile = TileStyle.rounded, this.glyphScale = 1});

  final TileStyle tile;

  /// Shrinks the people and badge toward the center, for Android's adaptive
  /// icon, which crops the outer third.
  final double glyphScale;

  static const tealLight = Color(0xFF2DD4BF);
  static const tealDark = Color(0xFF0F766E);
  static const amber = Color(0xFFFBBF24);
  static const ink = Color(0xFF134E4A);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final rect = Offset.zero & Size.square(s);

    if (tile != TileStyle.none) {
      final paint = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [tealLight, tealDark],
        ).createShader(rect);
      tile == TileStyle.rounded
          ? canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(s * 0.225)), paint)
          : canvas.drawRect(rect, paint);
    }

    canvas.save();
    canvas.translate(s / 2, s / 2);
    canvas.scale(glyphScale);
    // The shapes below span x 0.21–0.90 and y 0.25–0.87; this centers them.
    canvas.translate(-s * 0.555, -s * 0.56);

    final white = Paint()..color = Colors.white;
    final clear = Paint()..blendMode = BlendMode.clear;
    // A layer so the gaps between shapes cut through the people but not the tile.
    canvas.saveLayer(rect, Paint());
    _person(canvas, s, head: const Offset(0.37, 0.34), headR: 0.095, body: const Rect.fromLTRB(0.21, 0.485, 0.53, 0.74),
        paint: Paint()..color = Colors.white.withValues(alpha: 0.55));
    _person(canvas, s, head: const Offset(0.56, 0.40), headR: 0.115, body: const Rect.fromLTRB(0.37, 0.565, 0.75, 0.82),
        paint: clear, grow: 0.03);
    _person(canvas, s, head: const Offset(0.56, 0.40), headR: 0.115, body: const Rect.fromLTRB(0.37, 0.565, 0.75, 0.82),
        paint: white);
    const badge = Offset(0.75, 0.74);
    canvas.drawCircle(badge * s, s * 0.165, clear);
    canvas.restore();

    canvas.drawCircle(badge * s, s * 0.13, Paint()..color = amber);
    final bar = Paint()..color = ink;
    for (final r in [
      Rect.fromCenter(center: badge * s, width: s * 0.13, height: s * 0.034),
      Rect.fromCenter(center: badge * s, width: s * 0.034, height: s * 0.13),
    ]) {
      canvas.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(s * 0.017)), bar);
    }
    canvas.restore();
  }

  /// A head and rounded shoulders, in fractions of the icon size. [grow]
  /// enlarges both, for cutting a gap around the person.
  void _person(
    Canvas canvas,
    double s, {
    required Offset head,
    required double headR,
    required Rect body,
    required Paint paint,
    double grow = 0,
  }) {
    canvas.drawCircle(head * s, (headR + grow) * s, paint);
    final b = Rect.fromLTRB(body.left - grow, body.top - grow, body.right + grow, body.bottom + grow);
    final top = Radius.circular(b.width / 2 * s);
    final bottom = Radius.circular(0.045 * s);
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTRB(b.left * s, b.top * s, b.right * s, b.bottom * s),
        topLeft: top,
        topRight: top,
        bottomLeft: bottom,
        bottomRight: bottom,
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(LogoPainter old) => old.tile != tile || old.glyphScale != glyphScale;
}

enum TileStyle {
  /// Rounded corners, for showing inside the app.
  rounded,

  /// Full square; iOS and Android round launcher icons themselves.
  square,

  /// No tile, just the people and badge (Android adaptive foreground).
  none,
}
