import 'dart:math' as math;

import '../storage/eq_presets.dart';

/// Спрощена формула для ПОПЕРЕДНЬОГО ПЕРЕГЛЯДУ кривої АЧХ на графіку —
/// перенесена буквально з `Smart Speaker EQ.dc.html` (Claude Design).
///
/// Це НЕ реальна передавальна функція biquad-фільтра (та рахується окремо
/// в `dsp/biquad.dart` і саме вона йде на колонку по BLE) — лише візуальне
/// наближення "дзвону" навколо кожної смуги для живого відображення під час
/// перетягування точки. Достатньо точне для UI, не для акустичних вимірювань.
double eqPreviewResponseAt(double frequencyHz, List<EqBandSettings> bands) {
  double sum = 0;
  for (final b in bands) {
    final r = frequencyHz / b.frequencyHz;
    sum += b.gainDb / (1 + math.pow(b.q * (r - 1 / r), 2));
  }
  return sum;
}

/// Log-масштаб частоти — 20 Гц..20 кГц по всій ширині графіка (як у дизайні).
class EqGraphScale {
  static const double fMin = 20;
  static const double fMax = 20000;
  static const double gMax = 12; // ±12 dB по вертикалі

  /// Частота → частка ширини (0..1)
  static double freqToT(double f) => (math.log(f / fMin) / math.log(fMax / fMin)).clamp(0.0, 1.0);

  /// Частка ширини (0..1) → частота
  static double tToFreq(double t) => fMin * math.pow(fMax / fMin, t.clamp(0.0, 1.0));

  /// dB → частка висоти від центру (-1..1, додатне — вгору)
  static double gainToT(double g) => (g / gMax).clamp(-1.0, 1.0);

  static double tToGain(double t) => (t * gMax).clamp(-gMax, gMax);
}
