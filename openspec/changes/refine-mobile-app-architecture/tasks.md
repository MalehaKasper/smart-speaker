## 1. Платформа й залежності

- [x] 1.1 Звузити збірку до Android — `minSdk 31` (Android 12+, без legacy ACCESS_FINE_LOCATION для BLE-сканування) в `android/app/build.gradle.kts`; iOS-каркас лишається невикористаним, не видалений
- [x] 1.2 Додати залежність `flutter_riverpod`

## 2. Архітектура стану (Riverpod)

- [x] 2.1 `ble_connection.dart`: `BleConnectionNotifier`/`bleConnectionProvider` — статус з'єднання, гучність/джерело, MTU-готовність — спільне джерело правди для всіх екранів
- [x] 2.2 `ProviderScope` навколо додатка (`main.dart`)

## 3. BLE-клієнт

- [x] 3.1 Сканування за ім'ям колонки (`deviceScanProvider`), підключення, збереження MAC у `shared_preferences`
- [x] 3.2 Відправка `0x01`/`0x02`/`0x03` (`ble/protocol.dart` — 21-байтний EQ-payload, band_index + 5×float32 little-endian), підписка на notify гучності
- [x] 3.3 MTU-негоціація (`requestMtu(247)`) одразу після підключення; `eqReady` блокує відправку EQ при MTU < 24 (кидає `StateError`, UI показує повідомлення)

## 4. Сховище: історія (settings-history)

- [x] 4.1 Кільцевий буфер (глибина 20, `kMaxHistoryDepth`) в `shared_preferences` — `storage/settings_history.dart`
- [x] 4.2 Запис знімка ПЕРЕД кожною завершеною зміною гучності/джерела (`BleConnectionNotifier.setVolume`/`setSource`)
- [x] 4.3 `undoLastChange()` — відновлення попереднього знімка й відправка на колонку

## 5. Сховище: пресети EQ (звужений local-presets-storage)

- [x] 5.1 Іменований список `{name, bands: [8 × {gain, q, freq}]}` в `shared_preferences` — `storage/eq_presets.dart`
- [x] 5.2 Зберегти/обрати/видалити пресет — жодного автоматичного запису при звичайних правках смуг (окремо від settings-history)

## 6. FFT в isolate

- [x] 6.1 `dsp/fft_isolate.dart`: `magnitudeSpectrumInIsolate()` через `compute()`, чиста функція без замикань на UI-стан. Сам конвеєр авто рум-корекції (сигнал/запис/цільова крива) — поза межами цієї зміни, лишається в `build-mobile-app`

## 7. UI: екран пошуку/підключення

- [x] 7.1 `ui/pairing_screen.dart`: список знайдених BLE-пристроїв, підключення дотиком
- [x] 7.2 `main.dart` (`StartupScreen`) показує його лише коли `connectToSaved()` не знайшов збереженого MAC

## 8. UI: snackbar скасування

- [x] 8.1 `ui/home_screen.dart`: snackbar з дією "Скасувати" одразу після зміни гучності/джерела

## 9. UI: список пресетів на екрані еквалайзера

- [x] 9.1 `ui/equalizer_screen.dart`: діалог "Зберегти як..." з полем назви
- [x] 9.2 Список пресетів з діями обрати (застосувати на колонку)/видалити

## 10. Перевірка

- [x] 10.1 `flutter analyze` — 0 зауважень; `flutter test` — пройдено; `flutter build apk --debug` — **успішна реальна збірка** (`build/app/outputs/flutter-apk/app-debug.apk`). Побіжно виявлено й виправлено реальний блокер: `record ^5.2.1` не збирався для Android через розсинхрон `record_linux`/`record_platform_interface` — оновлено до `^7.1.1`
- [ ] 10.2 Наскрізний тест на реальному Android-пристрої: зміна гучності → скасувати → колонка повертається до попереднього значення — **потребує реального пристрою й колонки, не виконано в цій сесії**
