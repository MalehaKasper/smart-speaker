// Базовий smoke-тест: додаток стартує з екрана завантаження, поки триває
// спроба підключення до збереженої колонки (BLE/shared_preferences platform
// channels у тестовому середовищі не мокнуті — це перевіряє лише те, що
// віджет-дерево будується без винятків до першого асинхронного кроку).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smart_speaker_app/main.dart';

void main() {
  testWidgets('Додаток стартує з екрана завантаження', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: SmartSpeakerApp()));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
