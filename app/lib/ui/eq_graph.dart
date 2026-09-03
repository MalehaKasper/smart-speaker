import 'package:flutter/material.dart';

import '../dsp/eq_response_curve.dart';
import '../storage/eq_presets.dart';
import 'theme.dart';

const double _padX = 10;
const double _padY = 18;
const List<double> _gridFrequenciesHz = [50, 100, 500, 1000, 5000, 10000];

double _freqToX(double f, double width) =>
    _padX + EqGraphScale.freqToT(f) * (width - 2 * _padX);

double _xToFreq(double x, double width) =>
    EqGraphScale.tToFreq(((x - _padX) / (width - 2 * _padX)).clamp(0.0, 1.0));

double _gainToY(double g, double height) =>
    height / 2 - EqGraphScale.gainToT(g) * (height / 2 - _padY);

double _yToGain(double y, double height) =>
    EqGraphScale.tToGain(-(y - height / 2) / (height / 2 - _padY));

/// Інтерактивний графік АЧХ: перетягування точки змінює Frequency (X, log)
/// і Gain (Y) обраної смуги. Перенесено з `Smart Speaker EQ.dc.html`.
class EqGraph extends StatelessWidget {
  final List<EqBandSettings> bands;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final void Function(int index, double frequencyHz, double gainDb) onDrag;
  final VoidCallback? onDragEnd;

  const EqGraph({
    super.key,
    required this.bands,
    required this.selectedIndex,
    required this.onSelect,
    required this.onDrag,
    this.onDragEnd,
  });

  int _nearestBand(Offset pos, Size size) {
    var best = 0;
    var bestDist = double.infinity;
    for (var i = 0; i < bands.length; i++) {
      final dx = _freqToX(bands[i].frequencyHz, size.width) - pos.dx;
      final dy = _gainToY(bands[i].gainDb, size.height) - pos.dy;
      final d = dx * dx + dy * dy;
      if (d < bestDist) {
        bestDist = d;
        best = i;
      }
    }
    return best;
  }

  void _dragTo(Offset pos, Size size, int index) {
    final f = _xToFreq(pos.dx.clamp(_padX, size.width - _padX), size.width);
    final g = _yToGain(pos.dy, size.height).clamp(-EqGraphScale.gMax, EqGraphScale.gMax);
    onDrag(index, f, (g * 10).roundToDouble() / 10);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          onPanStart: (details) {
            final nearest = _nearestBand(details.localPosition, size);
            onSelect(nearest);
            _dragTo(details.localPosition, size, nearest);
          },
          onPanUpdate: (details) => _dragTo(details.localPosition, size, selectedIndex),
          onPanEnd: (_) => onDragEnd?.call(),
          child: CustomPaint(
            size: size,
            painter: _EqGraphPainter(bands: bands, selectedIndex: selectedIndex),
          ),
        );
      },
    );
  }
}

class _EqGraphPainter extends CustomPainter {
  final List<EqBandSettings> bands;
  final int selectedIndex;

  _EqGraphPainter({required this.bands, required this.selectedIndex});

  String _fmtFreq(double f) {
    if (f >= 1000) {
      final k = f / 1000;
      return '${k >= 10 ? k.round() : k.toStringAsFixed(1)}k';
    }
    return f.round().toString();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = AppColors.graphBg;
    final bgRect = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(18));
    canvas.drawRRect(bgRect, bg);

    final gridPaint = Paint()
      ..color = AppColors.divider
      ..strokeWidth = 1;
    for (final g in [-6.0, 6.0]) {
      final y = _gainToY(g, size.height);
      canvas.drawLine(Offset(_padX, y), Offset(size.width - _padX, y), gridPaint);
    }
    for (final f in _gridFrequenciesHz) {
      final x = _freqToX(f, size.width);
      canvas.drawLine(Offset(x, 10), Offset(x, size.height - 10), gridPaint);
    }

    // Пунктирна нульова лінія
    final zeroY = _gainToY(0, size.height);
    final dashPaint = Paint()
      ..color = AppColors.handleBar
      ..strokeWidth = 1;
    var dashX = _padX;
    while (dashX < size.width - _padX) {
      canvas.drawLine(Offset(dashX, zeroY), Offset(dashX + 3, zeroY), dashPaint);
      dashX += 7;
    }

    // Крива відповіді (сумарна, з eqPreviewResponseAt), залита кольором вище/нижче нуля
    final curvePoints = <Offset>[];
    for (var i = 0; i <= 120; i++) {
      final x = _padX + (size.width - 2 * _padX) * i / 120;
      final f = _xToFreq(x, size.width);
      final g = eqPreviewResponseAt(f, bands).clamp(-EqGraphScale.gMax, EqGraphScale.gMax);
      curvePoints.add(Offset(x, _gainToY(g, size.height)));
    }

    void drawHalf({required bool above}) {
      canvas.save();
      canvas.clipRect(Rect.fromLTRB(
        0,
        above ? 0 : zeroY,
        size.width,
        above ? zeroY : size.height,
      ));
      final fillPath = Path()..moveTo(curvePoints.first.dx, curvePoints.first.dy);
      for (final p in curvePoints.skip(1)) {
        fillPath.lineTo(p.dx, p.dy);
      }
      fillPath.lineTo(size.width - _padX, zeroY);
      fillPath.lineTo(_padX, zeroY);
      fillPath.close();
      canvas.drawPath(
        fillPath,
        Paint()..color = (above ? AppColors.accent : AppColors.red).withValues(alpha: 0.12),
      );

      final strokePath = Path()..moveTo(curvePoints.first.dx, curvePoints.first.dy);
      for (final p in curvePoints.skip(1)) {
        strokePath.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(
        strokePath,
        Paint()
          ..color = above ? AppColors.accent : AppColors.red
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round,
      );
      canvas.restore();
    }

    drawHalf(above: true);
    drawHalf(above: false);

    // Підписи частот знизу
    for (final f in _gridFrequenciesHz) {
      final x = _freqToX(f, size.width);
      final tp = TextPainter(
        text: TextSpan(text: _fmtFreq(f), style: AppText.mono(size: 8, color: AppColors.inkFaint)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, size.height - tp.height - 2));
    }

    // Точки смуг
    for (var i = 0; i < bands.length; i++) {
      final b = bands[i];
      final on = i == selectedIndex;
      final color = b.gainDb < 0 ? AppColors.red : AppColors.accent;
      final cx = _freqToX(b.frequencyHz, size.width);
      final cy = _gainToY(b.gainDb, size.height);

      if (on) {
        final linePaint = Paint()
          ..color = color.withValues(alpha: 0.35)
          ..strokeWidth = 1;
        canvas.drawLine(Offset(cx, 10), Offset(cx, size.height - 12), linePaint);
      }

      canvas.drawCircle(
        Offset(cx, cy),
        on ? 15 : 11,
        Paint()..color = color.withValues(alpha: on ? 0.14 : 0),
      );
      canvas.drawCircle(
        Offset(cx, cy),
        on ? 7 : 5,
        Paint()..color = on ? color : AppColors.screenBg,
      );
      canvas.drawCircle(
        Offset(cx, cy),
        on ? 7 : 5,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );

      final label = TextPainter(
        text: TextSpan(
          text: '${i + 1}',
          style: AppText.mono(size: 9, color: on ? color : AppColors.inkTertiary),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(canvas, Offset(cx - label.width / 2, cy - (on ? 16 : 13) - label.height));
    }
  }

  @override
  bool shouldRepaint(covariant _EqGraphPainter oldDelegate) {
    return oldDelegate.bands != bands || oldDelegate.selectedIndex != selectedIndex;
  }
}
