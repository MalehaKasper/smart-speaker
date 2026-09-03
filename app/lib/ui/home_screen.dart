import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ble/ble_connection.dart';
import '../storage/settings_history.dart';
import 'equalizer_screen.dart';
import 'theme.dart';

/// Головний екран — перенесено з `Smart Speaker EQ.dc.html` (Claude Design):
/// велика перетяжна область гучності, перемикач джерела, статус BLE,
/// список останньої історії загальних налаштувань, snackbar-скасування.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  double? _draggingVolume;
  final SettingsHistoryStore _historyStore = SettingsHistoryStore();
  List<SettingsSnapshot> _history = [];

  @override
  void initState() {
    super.initState();
    _refreshHistory();
  }

  Future<void> _refreshHistory() async {
    final history = await _historyStore.loadAll();
    if (!mounted) return;
    setState(() => _history = history);
  }

  String _statusLabel(ConnectionStatus status) {
    switch (status) {
      case ConnectionStatus.connected:
        return 'ПІДКЛЮЧЕНО';
      case ConnectionStatus.connecting:
        return 'ПІДКЛЮЧЕННЯ';
      case ConnectionStatus.reconnecting:
        return 'ПЕРЕПІДКЛЮЧЕННЯ';
      case ConnectionStatus.scanning:
        return 'ПОШУК';
      case ConnectionStatus.disconnected:
        return 'НЕ ПІДКЛЮЧЕНО';
    }
  }

  Future<void> _commitVolume(double value) async {
    await ref.read(bleConnectionProvider.notifier).setVolume(value.round());
    setState(() => _draggingVolume = null);
    await _refreshHistory();
    if (!mounted) return;
    _showUndoSnackbar('Гучність змінена');
  }

  Future<void> _setSource(int source) async {
    await ref.read(bleConnectionProvider.notifier).setSource(source);
    await _refreshHistory();
    if (!mounted) return;
    _showUndoSnackbar('Джерело: ${source == 0 ? 'Bluetooth' : 'AUX'}');
  }

  Future<void> _undo() async {
    final ok = await ref.read(bleConnectionProvider.notifier).undoLastChange();
    if (ok) await _refreshHistory();
  }

  void _showUndoSnackbar(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.ink,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Text(message, style: const TextStyle(color: Color(0xFFF4F6FA))),
        action: SnackBarAction(
          label: 'СКАСУВАТИ',
          textColor: AppColors.redSnackAction,
          onPressed: _undo,
        ),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  String _relativeTime(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'щойно';
    if (diff.inHours < 1) return '${diff.inMinutes} хв';
    return '${diff.inHours} год';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bleConnectionProvider);
    final connected = state.status == ConnectionStatus.connected;
    final displayedVolume = _draggingVolume ?? state.volume.toDouble();

    return Scaffold(
      backgroundColor: AppColors.screenBg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Колонка', style: AppText.display.copyWith(fontSize: 26)),
                      const SizedBox(height: 5),
                      Text('SMART SPEAKER 2.1', style: AppText.mono(size: 11)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: connected ? AppColors.accent : AppColors.red,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(_statusLabel(state.status), style: AppText.mono(size: 11, color: AppColors.inkSecondary)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _VolumeArea(
              volume: displayedVolume,
              topRight: state.source == 0 ? 'BLUETOOTH' : 'AUX',
              onChanged: connected ? (v) => setState(() => _draggingVolume = v) : null,
              onChangeEnd: connected ? _commitVolume : null,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _textAction('− 5', AppColors.inkSecondary,
                    connected ? () => _commitVolume((state.volume - 5).clamp(0, 100).toDouble()) : null),
                const SizedBox(width: 24),
                _textAction('MUTE', AppColors.red, connected ? () => _commitVolume(0) : null),
                const SizedBox(width: 24),
                _textAction('+ 5', AppColors.inkSecondary,
                    connected ? () => _commitVolume((state.volume + 5).clamp(0, 100).toDouble()) : null),
              ],
            ),
            if (state.volume == 0) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.volume_off, color: AppColors.accent),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Тиша. Гучність 0 — колонка нікого не розбудить.',
                        style: AppText.body.copyWith(fontSize: 13, color: AppColors.inkSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 26),
            Text('ДЖЕРЕЛО', style: AppText.mono(size: 11)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _sourceCard('Bluetooth', 'A2DP', state.source == 0, connected ? () => _setSource(0) : null)),
                const SizedBox(width: 10),
                Expanded(child: _sourceCard('AUX', '3.5 мм', state.source == 1, connected ? () => _setSource(1) : null)),
              ],
            ),
            Container(
              margin: const EdgeInsets.only(top: 18),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.divider))),
              child: InkWell(
                onTap: connected
                    ? () => Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => const EqualizerScreen()))
                    : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Еквалайзер', style: AppText.body.copyWith(fontSize: 16, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 4),
                            Text('8 смуг · Кімнатна корекція', style: AppText.mono(size: 11)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: AppColors.inkLabel),
                    ],
                  ),
                ),
              ),
            ),
            if (_history.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.divider))),
                padding: const EdgeInsets.only(top: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ІСТОРІЯ ЗМІН', style: AppText.mono(size: 11)),
                    const SizedBox(height: 6),
                    for (var i = _history.length - 1; i >= 0 && i >= _history.length - 3; i--)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Гучність ${_history[i].volume} · ${_history[i].source == 0 ? 'Bluetooth' : 'AUX'}',
                                style: AppText.body.copyWith(
                                  fontSize: 13,
                                  color: i == _history.length - 1 ? AppColors.ink : AppColors.inkSecondary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(_relativeTime(_history[i].timestamp), style: AppText.mono(size: 10, color: AppColors.inkFaint)),
                            if (i == _history.length - 1) ...[
                              const SizedBox(width: 10),
                              TextButton(
                                onPressed: _undo,
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(0, 0),
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text('СКАСУВАТИ', style: AppText.mono(size: 10, color: AppColors.red)),
                              ),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _textAction(String label, Color color, VoidCallback? onTap) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(foregroundColor: color),
      child: Text(label, style: AppText.mono(size: 13, color: color)),
    );
  }

  Widget _sourceCard(String title, String subtitle, bool active, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: active ? AppColors.accent : AppColors.screenBg,
          border: Border.all(color: active ? AppColors.accent : AppColors.border),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppText.body.copyWith(
              fontSize: 15, fontWeight: FontWeight.w500,
              color: active ? Colors.white : AppColors.ink,
            )),
            const SizedBox(height: 3),
            Text(subtitle, style: AppText.mono(size: 10, color: active ? Colors.white70 : AppColors.inkTertiary)),
          ],
        ),
      ),
    );
  }
}

class _VolumeArea extends StatelessWidget {
  final double volume;
  final String topRight;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeEnd;

  const _VolumeArea({
    required this.volume,
    required this.topRight,
    required this.onChanged,
    required this.onChangeEnd,
  });

  static const List<double> _ticks = [100, 75, 50, 25, 0];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final height = 268.0;
      void handle(Offset localPos) {
        final v = (1 - (localPos.dy / height)).clamp(0.0, 1.0) * 100;
        onChanged?.call(v);
      }

      return GestureDetector(
        onVerticalDragStart: onChanged == null ? null : (d) => handle(d.localPosition),
        onVerticalDragUpdate: onChanged == null ? null : (d) => handle(d.localPosition),
        onVerticalDragEnd: onChangeEnd == null ? null : (_) => onChangeEnd!.call(volume),
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: AppColors.volumeAreaBg,
            borderRadius: BorderRadius.circular(26),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  height: height * (volume / 100),
                  color: AppColors.accent,
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: height * (volume / 100) - 1,
                child: Container(height: 2, color: AppColors.red),
              ),
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: _ticks.map((t) {
                      final near = volume >= t - 3 && volume <= t + 3;
                      final under = volume > t;
                      final color = near
                          ? AppColors.red
                          : (under ? const Color(0x8CF6F4EF) : AppColors.inkFaint);
                      return Padding(
                        padding: const EdgeInsets.only(right: 14),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(t.round().toString(), style: AppText.mono(size: 9, color: color)),
                            const SizedBox(width: 6),
                            Container(width: 8, height: 1, color: color),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('ГУЧНІСТЬ',
                              style: AppText.mono(size: 11, color: volume > 82 ? Colors.white70 : AppColors.inkLabel)),
                          Text(topRight,
                              style: AppText.mono(size: 11, color: volume > 82 ? Colors.white70 : AppColors.inkLabel)),
                        ],
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            volume.round().toString(),
                            style: AppText.display.copyWith(
                              fontSize: 76,
                              height: 0.8,
                              letterSpacing: -0.04 * 76,
                              color: volume > 22 ? Colors.white : AppColors.ink,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6, left: 6),
                            child: Text('/ 100',
                                style: AppText.mono(size: 13, color: volume > 22 ? Colors.white70 : AppColors.inkLabel)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}
