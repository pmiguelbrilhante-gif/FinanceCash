import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/storage.dart';
import 'screens/onboarding_screen.dart';
import 'screens/home_screen.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR', null);
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Erro ao inicializar Firebase: $e');
  }

  runApp(const FinanceCashApp());
}

class FinanceCashApp extends StatelessWidget {
  const FinanceCashApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, currentMode, __) {
        return MaterialApp(
          title: 'FinanceCash',
          debugShowCheckedModeBanner: false,
          themeMode: currentMode,
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1d4ed8), brightness: Brightness.light),
            scaffoldBackgroundColor: const Color(0xFFf8fafc),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1d4ed8), brightness: Brightness.dark),
            scaffoldBackgroundColor: const Color(0xFF0f172a),
          ),
          home: const _Splash(),
        );
      },
    );
  }
}

class _Splash extends StatefulWidget {
  const _Splash();
  @override
  State<_Splash> createState() => _SplashState();
}

class _SplashState extends State<_Splash> {
  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    try {
      final first = await Storage.isFirstLaunch();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => first ? const OnboardingScreen() : const HomeScreen()),
      );
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(child: Text('💰', style: TextStyle(fontSize: 60))),
  );
}