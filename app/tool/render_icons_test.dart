// Renders the launcher icon sources from LogoPainter into assets/icon/.
// Regenerate after changing the logo:
//   flutter test tool/render_icons_test.dart && dart run flutter_launcher_icons
import 'dart:io';
import 'dart:ui' as ui;

import 'package:autocontact/logo.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _render(String path, CustomPainter painter, {Color? fill}) async {
  const size = 1024.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  if (fill != null) canvas.drawRect(const Rect.fromLTWH(0, 0, size, size), Paint()..color = fill);
  painter.paint(canvas, const Size.square(size));
  final image = await recorder.endRecording().toImage(size.toInt(), size.toInt());
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(png!.buffer.asUint8List());
}

void main() {
  testWidgets('render launcher icon sources', (tester) async {
    await tester.runAsync(() async {
      // iOS and legacy Android: the whole icon on a square tile.
      await _render('assets/icon/icon.png', const LogoPainter(tile: TileStyle.square));
      // Android adaptive: gradient tile behind, glyph in front. The generator
      // insets the foreground 16% per side, which keeps it in the safe zone.
      await _render(
        'assets/icon/background.png',
        const LogoPainter(tile: TileStyle.square, glyphScale: 0),
      );
      await _render('assets/icon/foreground.png', const LogoPainter(tile: TileStyle.none));
    });
  });
}
