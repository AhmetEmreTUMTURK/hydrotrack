import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'presentation/home_screen.dart';
import 'presentation/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: HydroTrackApp()));
}

class HydroTrackApp extends StatelessWidget {
  const HydroTrackApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'HydroTrack',
    debugShowCheckedModeBanner: false,
    theme: hydroTheme,
    locale: const Locale('tr'),
    supportedLocales: const [Locale('tr')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: const HomeScreen(),
  );
}
