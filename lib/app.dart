import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'features/canvas/canvas_screen.dart';

class TechTonicApp extends StatelessWidget {
  const TechTonicApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Full-screen immersive mode
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    return MaterialApp(
      title: 'tech-Tonic',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: Colors.black,
      ),
      home: const Scaffold(
        body: CanvasScreen(),
      ),
    );
  }
}
