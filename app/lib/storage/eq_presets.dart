import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Параметри однієї смуги еквалайзера (не сирі biquad-коефіцієнти —
/// зручні для UI параметри, з яких `dsp/biquad.dart` рахує b0..a2 на льоту).
class EqBandSettings {
  final double gainDb;
  final double q;
  final double frequencyHz;

  const EqBandSettings({
    required this.gainDb,
    required this.q,
    required this.frequencyHz,
  });

  EqBandSettings copyWith({double? gainDb, double? q, double? frequencyHz}) {
    return EqBandSettings(
      gainDb: gainDb ?? this.gainDb,
      q: q ?? this.q,
      frequencyHz: frequencyHz ?? this.frequencyHz,
    );
  }

  Map<String, dynamic> toJson() => {'gain': gainDb, 'q': q, 'freq': frequencyHz};

  factory EqBandSettings.fromJson(Map<String, dynamic> json) => EqBandSettings(
        gainDb: (json['gain'] as num).toDouble(),
        q: (json['q'] as num).toDouble(),
        frequencyHz: (json['freq'] as num).toDouble(),
      );
}

/// Іменований пресет — рівно 8 смуг (build-mobile-app: "Еквалайзер має рівно 8 незалежних смуг").
class EqPreset {
  final String name;
  final List<EqBandSettings> bands;

  const EqPreset({required this.name, required this.bands});

  Map<String, dynamic> toJson() => {
        'name': name,
        'bands': bands.map((b) => b.toJson()).toList(),
      };

  factory EqPreset.fromJson(Map<String, dynamic> json) => EqPreset(
        name: json['name'] as String,
        bands: (json['bands'] as List)
            .map((b) => EqBandSettings.fromJson(b as Map<String, dynamic>))
            .toList(),
      );
}

const String _kPrefsKey = 'eq_presets';

/// Іменовані пресети еквалайзера — виключно свідоме збереження користувачем
/// (зберегти/обрати/видалити). БЕЗ автоматичної історії окремих правок смуг —
/// це навмисно відокремлено від `settings_history.dart`
/// (refine-mobile-app-architecture/design.md).
class EqPresetsStore {
  Future<List<EqPreset>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPrefsKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => EqPreset.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Зберігає під назвою; якщо пресет з такою назвою вже існує — перезаписує його.
  Future<void> save(EqPreset preset) async {
    final presets = await loadAll();
    presets.removeWhere((p) => p.name == preset.name);
    presets.add(preset);
    await _persist(presets);
  }

  Future<void> delete(String name) async {
    final presets = await loadAll();
    presets.removeWhere((p) => p.name == name);
    await _persist(presets);
  }

  Future<void> _persist(List<EqPreset> presets) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kPrefsKey,
      jsonEncode(presets.map((p) => p.toJson()).toList()),
    );
  }
}
