import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ble/ble_connection.dart';
import '../dsp/biquad.dart';
import '../storage/eq_presets.dart';

/// Екран еквалайзера: рівно 8 фіксованих смуг (Gain/Q/Frequency кожна) і
/// список іменованих пресетів (зберегти/обрати/видалити).
///
/// НЕ входить у цю зміну (лишається на build-mobile-app): інтерактивний
/// графік АЧХ і повний конвеєр автоматичної рум-корекції (калібрувальний
/// сигнал → запис → FFT → цільова крива). Тут — лише ручне керування.
class EqualizerScreen extends ConsumerStatefulWidget {
  const EqualizerScreen({super.key});

  @override
  ConsumerState<EqualizerScreen> createState() => _EqualizerScreenState();
}

class _EqualizerScreenState extends ConsumerState<EqualizerScreen> {
  static const double _minFreq = 20;
  static const double _maxFreq = 20000;

  late List<EqBandSettings> _bands;
  final EqPresetsStore _presetsStore = EqPresetsStore();
  List<EqPreset> _presets = [];

  @override
  void initState() {
    super.initState();
    _bands = List.generate(
      kDefaultBandFrequenciesHz.length,
      (i) => EqBandSettings(gainDb: 0, q: 1.0, frequencyHz: kDefaultBandFrequenciesHz[i]),
    );
    _loadPresets();
  }

  Future<void> _loadPresets() async {
    final presets = await _presetsStore.loadAll();
    if (!mounted) return;
    setState(() => _presets = presets);
  }

  double _sliderToFreq(double t) => _minFreq * math.pow(_maxFreq / _minFreq, t);

  double _freqToSlider(double freq) =>
      (math.log(freq / _minFreq) / math.log(_maxFreq / _minFreq)).clamp(0.0, 1.0);

  Future<void> _applyBand(int index) async {
    final band = _bands[index];
    final coeffs = peakingEqCoefficients(
      frequencyHz: band.frequencyHz,
      gainDb: band.gainDb,
      q: band.q,
    );
    try {
      await ref.read(bleConnectionProvider.notifier).sendEqBand(index, coeffs.toList());
    } on StateError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _applyAllBands() async {
    for (var i = 0; i < _bands.length; i++) {
      await _applyBand(i);
    }
  }

  Future<void> _savePreset() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Назва пресету'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Скасувати'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Зберегти'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    await _presetsStore.save(EqPreset(name: name, bands: List.of(_bands)));
    await _loadPresets();
  }

  Future<void> _applyPreset(EqPreset preset) async {
    setState(() => _bands = List.of(preset.bands));
    await _applyAllBands();
  }

  Future<void> _deletePreset(String name) async {
    await _presetsStore.delete(name);
    await _loadPresets();
  }

  @override
  Widget build(BuildContext context) {
    final connectionState = ref.watch(bleConnectionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Еквалайзер'),
        actions: [
          IconButton(
            onPressed: _savePreset,
            icon: const Icon(Icons.save_outlined),
            tooltip: 'Зберегти як пресет',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!connectionState.eqReady)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  "BLE-з'єднання не готове до відправки EQ (замалий MTU) — "
                  'зміни застосовуються лише локально й не долітають до колонки.',
                ),
              ),
            ),
          const SizedBox(height: 8),
          for (var i = 0; i < _bands.length; i++) _bandCard(i),
          const Divider(height: 32),
          Text('Пресети', style: Theme.of(context).textTheme.titleMedium),
          if (_presets.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Пресетів ще немає'),
            ),
          for (final preset in _presets)
            ListTile(
              leading: const Icon(Icons.tune),
              title: Text(preset.name),
              onTap: () => _applyPreset(preset),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _deletePreset(preset.name),
              ),
            ),
        ],
      ),
    );
  }

  Widget _bandCard(int index) {
    final band = _bands[index];
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Смуга ${index + 1} · ${band.frequencyHz.round()} Hz'),
            _sliderRow(
              label: 'Freq',
              value: _freqToSlider(band.frequencyHz),
              valueLabel: '${band.frequencyHz.round()} Hz',
              onChanged: (t) => setState(
                () => _bands[index] = band.copyWith(frequencyHz: _sliderToFreq(t)),
              ),
              onChangeEnd: (_) => _applyBand(index),
            ),
            _sliderRow(
              label: 'Gain',
              value: band.gainDb,
              min: -12,
              max: 12,
              valueLabel: '${band.gainDb.toStringAsFixed(1)} dB',
              onChanged: (v) => setState(() => _bands[index] = band.copyWith(gainDb: v)),
              onChangeEnd: (_) => _applyBand(index),
            ),
            _sliderRow(
              label: 'Q',
              value: band.q,
              min: 0.3,
              max: 10,
              valueLabel: band.q.toStringAsFixed(2),
              onChanged: (v) => setState(() => _bands[index] = band.copyWith(q: v)),
              onChangeEnd: (_) => _applyBand(index),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sliderRow({
    required String label,
    required double value,
    required String valueLabel,
    required ValueChanged<double> onChanged,
    required ValueChanged<double> onChangeEnd,
    double min = 0,
    double max = 1,
  }) {
    return Row(
      children: [
        SizedBox(width: 44, child: Text(label)),
        Expanded(
          child: Slider(value: value, min: min, max: max, onChanged: onChanged, onChangeEnd: onChangeEnd),
        ),
        SizedBox(width: 72, child: Text(valueLabel, textAlign: TextAlign.end)),
      ],
    );
  }
}
