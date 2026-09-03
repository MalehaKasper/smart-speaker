import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ble/ble_connection.dart';
import '../dsp/biquad.dart';
import '../dsp/eq_response_curve.dart';
import '../storage/eq_presets.dart';
import 'eq_graph.dart';
import 'theme.dart';

const List<_CalStep> _kCalSteps = [
  _CalStep('Відтворення сигналу', "Свіп 20 Гц — 20 кГц грає на колонці. Не рухайте телефон і не говоріть."),
  _CalStep('Запис мікрофоном', 'Тримайте телефон у місці прослуховування, мікрофоном до колонки.'),
  _CalStep('Аналіз кімнати', 'Шукаємо резонанси й провали в АЧХ приміщення.'),
  _CalStep('Застосування до 8 смуг', 'Надсилаємо параметри по BLE в ESP32.'),
];

class _CalStep {
  final String title;
  final String hint;
  const _CalStep(this.title, this.hint);
}

/// Екран еквалайзера — інтерактивний графік АЧХ, 8 фіксованих смуг,
/// A/B-порівняння з активним пресетом, FLAT, пресети, і UI-каркас
/// автоматичної рум-корекції (без реального FFT-конвеєра — див. коментар нижче).
class EqualizerScreen extends ConsumerStatefulWidget {
  const EqualizerScreen({super.key});

  @override
  ConsumerState<EqualizerScreen> createState() => _EqualizerScreenState();
}

class _EqualizerScreenState extends ConsumerState<EqualizerScreen> {
  late List<EqBandSettings> _bands;
  int _selected = 3;
  bool _dirty = false;
  String _activePresetName = '';
  bool _abOn = false;

  final EqPresetsStore _presetsStore = EqPresetsStore();
  List<EqPreset> _presets = [];

  bool _calOpen = false;
  int _calStep = 0;
  double _calPct = 0;
  bool _calDone = false;
  Timer? _calTimer;

  @override
  void initState() {
    super.initState();
    _bands = List.generate(
      kDefaultBandFrequenciesHz.length,
      (i) => EqBandSettings(gainDb: 0, q: 1.0, frequencyHz: kDefaultBandFrequenciesHz[i]),
    );
    _loadPresets();
  }

  @override
  void dispose() {
    _calTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadPresets() async {
    final presets = await _presetsStore.loadAll();
    if (!mounted) return;
    setState(() => _presets = presets);
  }

  EqPreset? get _activePreset {
    if (_activePresetName.isEmpty) return null;
    for (final p in _presets) {
      if (p.name == _activePresetName) return p;
    }
    return null;
  }

  List<EqBandSettings> get _displayedBands {
    final preset = _activePreset;
    return (_abOn && preset != null) ? preset.bands : _bands;
  }

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

  void _onGraphDrag(int index, double frequencyHz, double gainDb) {
    setState(() {
      _selected = index;
      _bands[index] = _bands[index].copyWith(frequencyHz: frequencyHz, gainDb: gainDb);
      _dirty = true;
      _abOn = false;
    });
  }

  void _onSliderChange(EqBandSettings Function(EqBandSettings) patch) {
    setState(() {
      _bands[_selected] = patch(_bands[_selected]);
      _dirty = true;
      _abOn = false;
    });
  }

  void _onFlat() {
    setState(() {
      _bands = _bands.map((b) => b.copyWith(gainDb: 0)).toList();
      _dirty = true;
      _abOn = false;
    });
    for (var i = 0; i < _bands.length; i++) {
      _applyBand(i);
    }
  }

  Future<void> _savePreset() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => _SavePresetSheet(controller: controller),
    );
    if (name == null || name.isEmpty) return;
    await _presetsStore.save(EqPreset(name: name, bands: List.of(_bands)));
    setState(() {
      _activePresetName = name;
      _dirty = false;
    });
    await _loadPresets();
  }

  Future<void> _applyPreset(EqPreset preset) async {
    setState(() {
      _bands = preset.bands.map((b) => b.copyWith()).toList();
      _activePresetName = preset.name;
      _dirty = false;
      _abOn = false;
    });
    for (var i = 0; i < _bands.length; i++) {
      await _applyBand(i);
    }
  }

  Future<void> _deletePreset(String name) async {
    await _presetsStore.delete(name);
    if (_activePresetName == name) {
      setState(() => _activePresetName = '');
    }
    await _loadPresets();
  }

  void _startCalibrationDemo() {
    _calTimer?.cancel();
    setState(() {
      _calOpen = true;
      _calStep = 0;
      _calPct = 0;
      _calDone = false;
    });
    _calTimer = Timer.periodic(const Duration(milliseconds: 90), (timer) {
      final pct = math.min(100.0, _calPct + 2);
      final stepIdx = math.min(3, (pct / 25).floor());
      if (pct >= 100) {
        timer.cancel();
        setState(() {
          _calPct = 100;
          _calStep = 3;
          _calDone = true;
        });
      } else {
        setState(() {
          _calPct = pct;
          _calStep = stepIdx;
        });
      }
    });
  }

  void _closeCalibration() {
    _calTimer?.cancel();
    setState(() => _calOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    final connectionState = ref.watch(bleConnectionProvider);
    final bands = _displayedBands;
    final sel = bands[_selected];
    final boosted = bands.where((b) => b.gainDb > 0.2).length;
    final cut = bands.where((b) => b.gainDb < -0.2).length;
    final peak = bands.fold<double>(0, (m, b) => b.gainDb.abs() > m.abs() ? b.gainDb : m);

    return Scaffold(
      backgroundColor: AppColors.screenBg,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.chevron_left, color: AppColors.inkTertiary),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Еквалайзер', style: AppText.display.copyWith(fontSize: 20)),
                            Text(
                              _dirty
                                  ? 'НЕ ЗБЕРЕЖЕНО В ПРЕСЕТ'
                                  : (_activePresetName.isNotEmpty
                                      ? 'ПРЕСЕТ ${_activePresetName.toUpperCase()}'
                                      : "8 СМУГ · ПАРАМЕТРИЧНИЙ"),
                              style: AppText.mono(size: 10, color: _dirty ? AppColors.red : AppColors.inkLabel),
                            ),
                          ],
                        ),
                      ),
                      if (_activePreset != null)
                        TextButton(
                          onPressed: () => setState(() => _abOn = !_abOn),
                          style: TextButton.styleFrom(
                            backgroundColor: _abOn ? AppColors.red : AppColors.screenBg,
                            foregroundColor: _abOn ? Colors.white : AppColors.inkSecondary,
                            side: BorderSide(color: _abOn ? AppColors.red : AppColors.border),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text(_abOn ? 'A/B: B' : 'A/B: A', style: AppText.mono(size: 10)),
                        ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: _onFlat,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.inkSecondary,
                          side: const BorderSide(color: AppColors.border),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text('FLAT', style: AppText.mono(size: 11)),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SizedBox(
                    height: 200,
                    child: EqGraph(
                      bands: bands,
                      selectedIndex: _selected,
                      onSelect: (i) => setState(() => _selected = i),
                      onDrag: _onGraphDrag,
                      onDragEnd: () => _applyBand(_selected),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Row(
                    children: List.generate(bands.length, (i) {
                      final b = bands[i];
                      final on = i == _selected;
                      final color = b.gainDb < 0 ? AppColors.red : AppColors.accent;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: TextButton(
                            onPressed: () => setState(() => _selected = i),
                            style: TextButton.styleFrom(
                              backgroundColor: on ? color : AppColors.volumeAreaBg,
                              foregroundColor: on ? Colors.white : (b.gainDb < 0 ? color : AppColors.inkSecondary),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: Text(_fmtFreqShort(b.frequencyHz), style: AppText.mono(size: 10)),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '+$boosted ПІДЙОМ · −$cut ПІДДАВЛЕННЯ · ПІК ${_fmtGain(peak)} dB',
                          style: AppText.mono(size: 10, color: AppColors.inkFaint),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!connectionState.eqReady) ...[
                        const SizedBox(width: 8),
                        Text('MTU ЗАМАЛИЙ', style: AppText.mono(size: 10, color: AppColors.red)),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Смуга ${_selected + 1} · ${_fmtFreqShort(sel.frequencyHz)} Гц', style: AppText.body),
                          Text('РІВНО 8 ТОЧОК', style: AppText.mono(size: 10)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _paramRow(
                        label: 'GAIN',
                        display: '${_fmtGain(sel.gainDb)} dB',
                        color: sel.gainDb < 0 ? AppColors.red : AppColors.accent,
                        value: sel.gainDb,
                        min: -EqGraphScale.gMax,
                        max: EqGraphScale.gMax,
                        onChanged: (v) => _onSliderChange((b) => b.copyWith(gainDb: v)),
                        onChangeEnd: (_) => _applyBand(_selected),
                      ),
                      _paramRow(
                        label: 'FREQUENCY',
                        display: '${_fmtFreqShort(sel.frequencyHz)} Гц',
                        color: AppColors.ink,
                        value: math.log(sel.frequencyHz),
                        min: math.log(EqGraphScale.fMin),
                        max: math.log(EqGraphScale.fMax),
                        onChanged: (v) =>
                            _onSliderChange((b) => b.copyWith(frequencyHz: math.exp(v))),
                        onChangeEnd: (_) => _applyBand(_selected),
                      ),
                      _paramRow(
                        label: 'Q-FACTOR',
                        display: sel.q.toStringAsFixed(2),
                        color: AppColors.ink,
                        value: sel.q,
                        min: 0.3,
                        max: 6,
                        onChanged: (v) => _onSliderChange((b) => b.copyWith(q: v)),
                        onChangeEnd: (_) => _applyBand(_selected),
                      ),
                      const SizedBox(height: 18),
                      InkWell(
                        onTap: _startCalibrationDemo,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.red.withValues(alpha: 0.06),
                            border: Border.all(color: AppColors.red.withValues(alpha: 0.35)),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Автоматична рум-корекція',
                                style: AppText.body.copyWith(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.redTitle),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'СИГНАЛ → ЗАПИС → АНАЛІЗ → ЗАСТОСУВАННЯ · ДО 2 ХВ',
                                style: AppText.mono(size: 10, color: AppColors.inkSecondary),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          Text('ПРЕСЕТИ', style: AppText.mono(size: 11)),
                          const Spacer(),
                          TextButton(
                            onPressed: _savePreset,
                            child: Text('Зберегти як…',
                                style: AppText.body.copyWith(color: AppColors.accent, fontWeight: FontWeight.w500)),
                          ),
                        ],
                      ),
                      for (final preset in _presets)
                        Container(
                          decoration: const BoxDecoration(
                            border: Border(top: BorderSide(color: AppColors.divider)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () => _applyPreset(preset),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 6,
                                          height: 6,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: preset.name == _activePresetName
                                                ? AppColors.accent
                                                : AppColors.border,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Text(preset.name, style: AppText.body.copyWith(fontSize: 15)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () => _deletePreset(preset.name),
                                icon: const Icon(Icons.close, size: 18, color: AppColors.inkFaint),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (_calOpen) _CalibrationOverlay(
              step: _calStep,
              pct: _calPct,
              done: _calDone,
              onClose: _closeCalibration,
            ),
          ],
        ),
      ),
    );
  }

  Widget _paramRow({
    required String label,
    required String display,
    required Color color,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
    required ValueChanged<double> onChangeEnd,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: AppText.mono(size: 11)),
            Text(display, style: AppText.mono(size: 13, color: color, weight: FontWeight.w500)),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: AppColors.accent,
            inactiveTrackColor: AppColors.track,
            thumbColor: AppColors.accent,
            overlayColor: AppColors.accent.withValues(alpha: 0.12),
          ),
          child: Slider(value: value.clamp(min, max), min: min, max: max, onChanged: onChanged, onChangeEnd: onChangeEnd),
        ),
      ],
    );
  }

  static String _fmtFreqShort(double f) {
    if (f >= 1000) {
      final k = f / 1000;
      return '${k >= 10 ? k.round() : k.toStringAsFixed(1)}k';
    }
    return f.round().toString();
  }

  static String _fmtGain(double g) => '${g > 0 ? '+' : ''}${g.toStringAsFixed(1)}';
}

class _SavePresetSheet extends StatelessWidget {
  final TextEditingController controller;
  const _SavePresetSheet({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.screenBg,
      title: Text('Новий пресет', style: AppText.display.copyWith(fontSize: 18)),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(hintText: "Назва, напр. «Вітальня — вечір»"),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Скасувати', style: AppText.body.copyWith(color: AppColors.inkSecondary)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          child: const Text('Зберегти'),
        ),
      ],
    );
  }
}

/// Повноекранна калібрація. УВАГА: це UI-каркас/демонстрація флоу
/// (анімований таймер), НЕ реальний конвеєр рум-корекції — генерація
/// сигналу, синхронізований запис мікрофоном, FFT-аналіз і побудова
/// цільової кривої ще не реалізовані (build-mobile-app, майбутня робота).
/// Тому по завершенню НЕ підмінює реальні коефіцієнти смуг фейковими даними.
class _CalibrationOverlay extends StatelessWidget {
  final int step;
  final double pct;
  final bool done;
  final VoidCallback onClose;

  const _CalibrationOverlay({
    required this.step,
    required this.pct,
    required this.done,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final cur = _kCalSteps[step];
    return Positioned.fill(
      child: Container(
        color: AppColors.screenBg,
        padding: const EdgeInsets.fromLTRB(24, 60, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('РУМ-КОРЕКЦІЯ', style: AppText.mono(size: 11, color: AppColors.accent)),
                if (!done && step == 1) ...[
                  const SizedBox(width: 10),
                  Text('● REC', style: AppText.mono(size: 10, color: AppColors.red)),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Text(
              done ? 'Демо завершено' : cur.title,
              style: AppText.display.copyWith(fontSize: 24),
            ),
            const SizedBox(height: 10),
            Text(
              done
                  ? 'Це демонстрація інтерфейсу — реальний аналіз кімнати (сигнал/запис/FFT) ще не підключений. Прогрес і кроки вище показують заплановий флоу.'
                  : cur.hint,
              style: AppText.body.copyWith(fontSize: 15, color: AppColors.inkSecondary, height: 1.4),
            ),
            const SizedBox(height: 28),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: pct / 100,
                minHeight: 2,
                backgroundColor: AppColors.divider,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              done ? 'завершено' : '${pct.round()}% · залишилось ~${math.max(1, ((100 - pct) / 12).round())} с',
              style: AppText.mono(size: 11, color: AppColors.inkTertiary),
            ),
            const SizedBox(height: 24),
            Column(
              children: List.generate(_kCalSteps.length, (i) {
                final markDone = done || i < step;
                final isCurrent = i == step && !done;
                return Container(
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: AppColors.divider)),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 16,
                        child: Text(
                          markDone ? '✓' : (isCurrent ? '▶' : '${i + 1}'),
                          style: AppText.mono(
                            size: 11,
                            color: (i <= step || done) ? AppColors.accent : AppColors.inkFaint,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _kCalSteps[i].title,
                        style: AppText.body.copyWith(
                          fontSize: 15,
                          color: isCurrent ? AppColors.ink : AppColors.inkSecondary,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
            const Spacer(),
            OutlinedButton(
              onPressed: onClose,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.inkSecondary,
                side: const BorderSide(color: AppColors.border),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(done ? 'Закрити' : 'Перервати'),
            ),
          ],
        ),
      ),
    );
  }
}
