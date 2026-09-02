import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Знімок загальних налаштувань (гучність, джерело) — одна одиниця автоматичної
/// історії. НЕ стосується еквалайзера (див. `eq_presets.dart`).
class SettingsSnapshot {
  final int volume;
  final int source;
  final DateTime timestamp;

  const SettingsSnapshot({
    required this.volume,
    required this.source,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'volume': volume,
        'source': source,
        'ts': timestamp.toIso8601String(),
      };

  factory SettingsSnapshot.fromJson(Map<String, dynamic> json) => SettingsSnapshot(
        volume: json['volume'] as int,
        source: json['source'] as int,
        timestamp: DateTime.parse(json['ts'] as String),
      );
}

const String _kPrefsKey = 'settings_history';

/// Глибина кільцевого буфера — довільне, легко змінюване число
/// (openspec/changes/refine-mobile-app-architecture/design.md, Risks).
const int kMaxHistoryDepth = 20;

/// Автоматична, ненайменована історія загальних налаштувань. Кожна ЗАВЕРШЕНА
/// зміна гучності/джерела (не проміжні значення під час руху повзунка)
/// записує знімок СТАНУ ДО зміни, щоб "Скасувати" мало куди повертатись.
class SettingsHistoryStore {
  Future<List<SettingsSnapshot>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPrefsKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list
        .map((e) => SettingsSnapshot.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> pushSnapshot(SettingsSnapshot snapshot) async {
    final history = await loadAll();
    history.add(snapshot);
    while (history.length > kMaxHistoryDepth) {
      history.removeAt(0);
    }
    await _persist(history);
  }

  /// Забрати й видалити останній знімок (для дії "Скасувати"). `null`, якщо порожньо.
  Future<SettingsSnapshot?> popLast() async {
    final history = await loadAll();
    if (history.isEmpty) return null;
    final last = history.removeLast();
    await _persist(history);
    return last;
  }

  Future<void> _persist(List<SettingsSnapshot> history) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kPrefsKey,
      jsonEncode(history.map((s) => s.toJson()).toList()),
    );
  }
}
