import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/splash_screen.dart';

void main() {
  runApp(const TipidTrackApp());
}

class TipidTrackApp extends StatelessWidget {
  const TipidTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    const brandColor = Color(0xFFB38AF7);

    return MaterialApp(
      title: 'TipidTrack',
      debugShowCheckedModeBanner: false,
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
