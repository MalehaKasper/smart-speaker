import 'package:fftea/fftea.dart';
import 'package:flutter/foundation.dart' show compute;

/// Обчислює амплітудний спектр в окремому isolate — FFT НІКОЛИ не викликається
/// в UI-ізоляті, незалежно від потужності пристрою (design.md, Decisions).
///
/// Це лише обчислювальний примітив. Повний конвеєр авто рум-корекції
/// (генерація калібрувального сигналу, синхронізація запису з мікрофона,
/// побудова цільової кривої з отриманого спектра) — майбутня робота,
/// build-mobile-app tasks.md розділи 3.1-3.4, не входить у цю зміну.
///
/// [samples] SHALL мати довжину — степінь двійки (вимога `fftea.FFT`).
Future<List<double>> magnitudeSpectrumInIsolate(List<double> samples) {
  return compute(_magnitudeSpectrum, samples);
}

List<double> _magnitudeSpectrum(List<double> samples) {
  final fft = FFT(samples.length);
  final spectrum = fft.realFft(samples).discardConjugates().magnitudes();
  return spectrum.toList();
}
