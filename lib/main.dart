import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TipidTrackApp());
}

class _NoStretchScrollBehavior extends ScrollBehavior {
  @override
  Widget buildOverscrollIndicator(
      BuildContext context, Widget child, ScrollableDetails details) {
    return child; // removes stretch + glow overscroll effect
  }
}

class TipidTrackApp extends StatelessWidget {
  const TipidTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    const brandColor = Color(0xFFB38AF7);

    return MaterialApp(
      title: 'TipidTrack',
      debugShowCheckedModeBanner: false,
      scrollBehavior: _NoStretchScrollBehavior(),
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: brandColor,
          brightness: Brightness.light,
        ),
        textTheme: GoogleFonts.poppinsTextTheme(),
      ),
      home: const SplashScreen(),
    );
  }
}
