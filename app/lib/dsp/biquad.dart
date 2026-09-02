import 'dart:math' as math;

/// Коефіцієнти біквадратного фільтра однієї смуги DSP (b0, b1, b2, a1, a2) —
/// вже нормалізовані (поділені на a0), саме в такому вигляді очікує їх
/// payload `0x03` (`ble/protocol.dart`). Прошивка сама конвертує ці float у
/// фіксовану кому ADAU1401 — додаток про це не знає (build-mobile-app design.md).
class BiquadCoefficients {
  final double b0, b1, b2, a1, a2;

  const BiquadCoefficients(this.b0, this.b1, this.b2, this.a1, this.a2);

  List<double> toList() => [b0, b1, b2, a1, a2];
}

/// Стандартна частота дискретизації ADAU1401 у типових конфігураціях —
/// припущення, потребує підтвердження реальною SigmaStudio-схемою прошивки.
const double kDefaultSampleRateHz = 48000;

/// Центральні частоти 8 смуг — фіксований, розумно log-розподілений ряд для
/// room-correction (типовий діапазон 8-10 смуг). Це рішення додатка, не DSP:
/// смуги в SigmaStudio-схемі генеричні, без прив'язки до конкретної частоти.
const List<double> kDefaultBandFrequenciesHz = [
  60, 150, 400, 1000, 2500, 6000, 12000, 16000,
];

/// Розрахунок коефіцієнтів пікового (peaking) параметричного EQ-фільтра
/// за формулами Robert Bristow-Johnson (Audio EQ Cookbook).
BiquadCoefficients peakingEqCoefficients({
  required double frequencyHz,
  required double gainDb,
  required double q,
  double sampleRateHz = kDefaultSampleRateHz,
}) {
  final a = math.pow(10, gainDb / 40).toDouble();
  final w0 = 2 * math.pi * frequencyHz / sampleRateHz;
  final cosW0 = math.cos(w0);
  final sinW0 = math.sin(w0);
  final alpha = sinW0 / (2 * q);

  final b0 = 1 + alpha * a;
  final b1 = -2 * cosW0;
  final b2 = 1 - alpha * a;
  final a0 = 1 + alpha / a;
  final a1 = -2 * cosW0;
  final a2 = 1 - alpha / a;

  return BiquadCoefficients(b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0);
}
