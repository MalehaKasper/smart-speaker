import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ble/ble_connection.dart';
import 'ui/home_screen.dart';
import 'ui/pairing_screen.dart';
import 'ui/theme.dart';

void main() {
  runApp(const ProviderScope(child: SmartSpeakerApp()));
}

class SmartSpeakerApp extends StatelessWidget {
  const SmartSpeakerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Speaker EQ',
      theme: buildAppTheme(),
      home: const StartupScreen(),
    );
  }
}

/// Визначає, з якого екрана почати: якщо MAC колонки вже збережено —
/// одразу пробує підключитись і показує головний екран; інакше — пошук.
class StartupScreen extends ConsumerStatefulWidget {
  const StartupScreen({super.key});

  @override
  ConsumerState<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends ConsumerState<StartupScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startup());
  }

  Future<void> _startup() async {
    final hadSavedDevice = await ref.read(bleConnectionProvider.notifier).connectToSaved();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => hadSavedDevice ? const HomeScreen() : const PairingScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.screenBg,
      body: const Center(child: CircularProgressIndicator(color: AppColors.accent)),
    );
  }
}
