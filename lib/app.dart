import 'package:flutter/material.dart';

class TechTonicApp extends StatelessWidget {
  const TechTonicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'tech-Tonic',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: Colors.black,
      ),
      home: const Scaffold(
        body: Center(
          child: Text(
            'tech-Tonic',
            style: TextStyle(color: Colors.white54, fontSize: 24),
          ),
        ),
      ),
    );
  }
}
